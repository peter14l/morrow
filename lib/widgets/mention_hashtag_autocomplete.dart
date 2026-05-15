import 'package:flutter/material.dart';
import 'package:oasis/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:oasis/services/hashtag_service.dart';
import 'package:oasis/features/feed/domain/models/hashtag.dart';
import 'package:oasis/features/profile/domain/models/user_profile_entity.dart';

class MentionHashtagAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const MentionHashtagAutocomplete({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  @override
  State<MentionHashtagAutocomplete> createState() =>
      _MentionHashtagAutocompleteState();
}

class _MentionHashtagAutocompleteState
    extends State<MentionHashtagAutocomplete> {
  final _hashtagService = HashtagService();
  final _profileRepository = ProfileRepositoryImpl();

  List<dynamic> _suggestions = [];
  bool _showSuggestions = false;
  String _currentQuery = '';
  bool _isHashtag = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    final lastWord = _getLastWord(text, cursorPosition);

    if (lastWord != null && lastWord.isNotEmpty) {
      if (lastWord.startsWith('#')) {
        _isHashtag = true;
        _currentQuery = lastWord.substring(1);
        _searchHashtags(_currentQuery);
      } else if (lastWord.startsWith('@')) {
        _isHashtag = false;
        _currentQuery = lastWord.substring(1);
        _searchUsers(_currentQuery);
      } else {
        setState(() {
          _showSuggestions = false;
          _suggestions = [];
        });
      }
    } else {
      setState(() {
        _showSuggestions = false;
        _suggestions = [];
      });
    }
  }

  String? _getLastWord(String text, int cursorPosition) {
    if (cursorPosition <= 0 || cursorPosition > text.length) {
      return null;
    }

    final textBeforeCursor = text.substring(0, cursorPosition);

    // Check for hashtag
    final hashtagMatch = RegExp(
      r'#([a-zA-Z0-9_]*)$',
    ).firstMatch(textBeforeCursor);
    if (hashtagMatch != null) {
      return hashtagMatch.group(0);
    }

    // Check for mention
    final mentionMatch = RegExp(r'@([a-z0-9_]*)$').firstMatch(textBeforeCursor);
    if (mentionMatch != null) {
      return mentionMatch.group(0);
    }

    return null;
  }

  Future<void> _searchHashtags(String query) async {
    if (query.isEmpty) {
      setState(() {
        _showSuggestions = false;
        _suggestions = [];
      });
      return;
    }

    try {
      final hashtags = await _hashtagService.searchHashtags(query, limit: 5);
      if (mounted) {
        setState(() {
          _suggestions = hashtags;
          _showSuggestions = hashtags.isNotEmpty;
        });
      }
    } catch (e) {
      setState(() {
        _showSuggestions = false;
        _suggestions = [];
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _showSuggestions = false;
        _suggestions = [];
      });
      return;
    }

    try {
      final users = await _profileRepository.searchUsers(
        query: query,
        limit: 5,
      );
      if (mounted) {
        setState(() {
          _suggestions = users;
          _showSuggestions = users.isNotEmpty;
        });
      }
    } catch (e) {
      setState(() {
        _showSuggestions = false;
        _suggestions = [];
      });
    }
  }

  void _selectSuggestion(dynamic suggestion) {
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    String replacement;
    if (_isHashtag) {
      final hashtag = suggestion as Hashtag;
      replacement = '#${hashtag.tag}';
    } else {
      final user = suggestion as UserProfileEntity;
      replacement = '@${user.username}';
    }

    // Find the start of the current word
    final textBeforeCursor = text.substring(0, cursorPosition);
    final match = _isHashtag
        ? RegExp(r'#([a-zA-Z0-9_]*)$').firstMatch(textBeforeCursor)
        : RegExp(r'@([a-z0-9_]*)$').firstMatch(textBeforeCursor);

    if (match != null) {
      final beforeWord = textBeforeCursor.substring(0, match.start);
      final afterCursor = text.substring(cursorPosition);
      final newText = '$beforeWord$replacement $afterCursor';

      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: beforeWord.length + replacement.length + 1,
        ),
      );
    }

    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showSuggestions || _suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];

          if (_isHashtag) {
            final hashtag = suggestion as Hashtag;
            return ListTile(
              dense: true,
              leading: const Icon(Icons.tag, size: 20),
              title: Text('#${hashtag.tag}'),
              subtitle: Text('${hashtag.usageCount} posts'),
              onTap: () => _selectSuggestion(suggestion),
            );
          } else {
            final user = suggestion as UserProfileEntity;
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
              title: Text('@${user.username}'),
              subtitle: user.fullName != null ? Text(user.fullName!) : null,
              onTap: () => _selectSuggestion(suggestion),
            );
          }
        },
      ),
    );
  }
}
