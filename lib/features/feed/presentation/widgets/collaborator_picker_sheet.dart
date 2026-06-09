import 'package:flutter/material.dart';
import 'package:oasis/services/search_service.dart';
import 'package:oasis/core/utils/haptic_utils.dart';

class CollaboratorPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> initialCollaborators;

  const CollaboratorPickerSheet({
    super.key,
    this.initialCollaborators = const [],
  });

  @override
  State<CollaboratorPickerSheet> createState() =>
      _CollaboratorPickerSheetState();
}

class _CollaboratorPickerSheetState extends State<CollaboratorPickerSheet> {
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _selectedCollaborators = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCollaborators.addAll(widget.initialCollaborators);
  }

  void _onSearch(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);
    final results = await _searchService.searchUsers(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    }
  }

  void _toggleCollaborator(Map<String, dynamic> user) {
    HapticUtils.selectionClick();
    setState(() {
      final index = _selectedCollaborators.indexWhere((u) => u['id'] == user['id']);
      if (index >= 0) {
        _selectedCollaborators.removeAt(index);
      } else {
        _selectedCollaborators.add(user);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.bottomSheetTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    Text(
                      'Collaborators',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, _selectedCollaborators),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: _onSearch,
                ),
              ),

              // Selected Tags
              if (_selectedCollaborators.isNotEmpty)
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _selectedCollaborators.length,
                    itemBuilder: (context, index) {
                      final user = _selectedCollaborators[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Chip(
                          label: Text(user['username'] ?? 'User'),
                          avatar: CircleAvatar(
                            backgroundImage: user['avatar_url'] != null
                                ? NetworkImage(user['avatar_url'])
                                : null,
                          ),
                          onDeleted: () => _toggleCollaborator(user),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const Divider(),

              // Results
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          final isSelected = _selectedCollaborators
                              .any((u) => u['id'] == user['id']);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user['avatar_url'] != null
                                  ? NetworkImage(user['avatar_url'])
                                  : null,
                            ),
                            title: Text(user['username'] ?? 'User'),
                            subtitle: Text(user['full_name'] ?? ''),
                            trailing: Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleCollaborator(user),
                              shape: const CircleBorder(),
                            ),
                            onTap: () => _toggleCollaborator(user),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
