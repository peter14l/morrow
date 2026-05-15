import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/services/post_service.dart';
import 'package:oasis/features/feed/presentation/providers/feed_provider.dart';
import 'package:oasis/features/circles/presentation/providers/circle_provider.dart';
import 'package:oasis/core/utils/haptic_utils.dart';
import 'package:oasis/features/feed/domain/models/post_mood.dart';
import 'package:oasis/features/feed/domain/models/enhanced_poll.dart';
import 'package:oasis/features/feed/presentation/widgets/mood_selector.dart';
import 'package:oasis/features/feed/presentation/widgets/polls/poll_widgets.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:oasis/widgets/adaptive/adaptive_scaffold.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:oasis/features/feed/presentation/widgets/post_card.dart';
import 'package:oasis/themes/theme_provider.dart';

import 'package:oasis/features/feed/presentation/widgets/collaborator_picker_sheet.dart';

class CreatePostScreen extends StatefulWidget {
  final String? communityId;
  final String? circleId;

  const CreatePostScreen({super.key, this.communityId, this.circleId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final PostService _postService = PostService();
  final AuthService _authService = AuthService();

  final List<XFile> _selectedImages = [];
  bool _isLoading = false;
  bool _isSpoiler = false;

  // Mood and Poll state
  PostMood? _selectedMood;
  EnhancedPoll? _attachedPoll;
  bool _showPollCreator = false;

  final List<Map<String, dynamic>> _selectedCollaborators = [];

  final TextEditingController _locationController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    _hashtagController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      List<XFile> images = [];
      if (Platform.isWindows) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
          initialDirectory:
              'C:\\Users\\${Platform.environment['USERNAME']}\\Downloads',
        );
        if (result != null && result.paths.isNotEmpty) {
          images = result.paths
              .where((path) => path != null)
              .map((path) => XFile(path!))
              .toList();
        }
      } else {
        images = await _picker.pickMultiImage(imageQuality: 85);
      }

      if (images.isNotEmpty && mounted) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick images: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _createPost() async {
    if (_captionController.text.trim().isEmpty && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a caption or image')),
      );
      return;
    }

    final userId = _authService.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to create a post')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Parse hashtags
      final hashtags = _hashtagController.text
          .split(RegExp(r'[,\s]+'))
          .where((tag) => tag.isNotEmpty)
          .map((tag) => tag.replaceAll('#', '').toLowerCase())
          .toList();

      if (widget.circleId != null) {
        final List<String> mediaUrls = [];
        if (_selectedImages.isNotEmpty) {
          for (var file in _selectedImages) {
            final url = await _postService.uploadPostMedia(
              userId,
              File(file.path),
            );
            mediaUrls.add(url);
          }
        }

        await context.read<CircleProvider>().createCirclePost(
          circleId: widget.circleId!,
          userId: userId,
          content: _captionController.text.trim(),
          mediaUrls: mediaUrls,
          mediaTypes: List.filled(mediaUrls.length, 'image'),
          mood: _selectedMood?.name,
          hashtags: hashtags,
          isSpoiler: _isSpoiler,
          poll: _attachedPoll?.toJson(),
        );
      } else {
        // Create post
        final post = await _postService.createPost(
          userId: userId,
          communityId: widget.communityId,
          content: _captionController.text.trim().isEmpty
              ? null
              : _captionController.text.trim(),
          mediaFiles: _selectedImages.map((file) => File(file.path)).toList(),
          mediaTypes: List.filled(_selectedImages.length, 'image'),
          mood: _selectedMood?.name,
          hashtags: hashtags,
          isSpoiler: _isSpoiler,
          poll: _attachedPoll,
          collaboratorIds: _selectedCollaborators.map((u) => u['id'] as String).toList(),
        );

        if (!mounted) return;

        // Add post to feed provider with local paths for immediate preview
        final localPost = post.copyWith(
          mediaUrls: _selectedImages.map((e) => e.path).toList(),
        );
        context.read<FeedProvider>().addPost(localPost);
      }

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/feed');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create post: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickLocation() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        String tempLocation = '';
        return AlertDialog(
          title: const Text('Add Location'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Where are you?',
              prefixIcon: Icon(Icons.location_on),
            ),
            onChanged: (value) => tempLocation = value,
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, tempLocation),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _locationController.text = result;
      });
      HapticUtils.success();
    }
  }

  void _showCollaboratorPicker() async {
    final List<Map<String, dynamic>>? result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CollaboratorPickerSheet(
        initialCollaborators: _selectedCollaborators,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedCollaborators.clear();
        _selectedCollaborators.addAll(result);
      });
    }
  }

  void _togglePollCreator() {
    HapticUtils.selectionClick();
    setState(() {
      _showPollCreator = !_showPollCreator;
      if (!_showPollCreator) {
        _attachedPoll = null;
      }
    });
  }

  void _onPollCreated(EnhancedPoll poll) {
    HapticUtils.success();
    setState(() {
      _attachedPoll = poll;
      _showPollCreator = false;
    });
  }

  Post _generatePreviewPost() {
    final user = _authService.currentUser;
    return Post(
      id: 'preview',
      userId: user?.id ?? 'user',
      username: user?.displayName ?? user?.username ?? 'You',
      userAvatar: user?.photoUrl ?? '',
      content: _captionController.text,
      hashtags: _hashtagController.text
          .split(RegExp(r'[,\s]+'))
          .where((t) => t.isNotEmpty)
          .toList(),
      mediaUrls: _selectedImages.map((e) => e.path).toList(),
      mediaTypes: List.filled(_selectedImages.length, 'image'),
      timestamp: DateTime.now(),
      mood: _selectedMood?.name,
      poll: _attachedPoll,
      isSpoiler: _isSpoiler,
      circleId: widget.circleId,
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isM3E = false,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: isM3E ? 20 : 18),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: (isM3E || isActive) ? FontWeight.bold : null,
        ),
      ),
      style: FilledButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: isM3E ? 20 : 16,
          vertical: isM3E ? 12 : 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isM3E ? 16 : 12),
        ),
        backgroundColor: isActive
            ? colorScheme.primaryContainer
            : (isM3E
                  ? colorScheme.secondaryContainer.withValues(alpha: 0.7)
                  : null),
        foregroundColor: isActive ? colorScheme.onPrimaryContainer : null,
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final useFluent = themeProvider.useFluentUI;

    if (useFluent) {
      return _buildFluentDesktopLayout();
    }

    return AdaptiveScaffold(
      title: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/feed'),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          Text(widget.circleId != null ? 'Circle Post' : 'Create Post'),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            child: FilledButton(
              onPressed: _isLoading ? null : _createPost,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Post'),
            ),
          ),
        ),
      ],
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_buildDesktopEditorForm()],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 2,
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Text(
                    'PREVIEW',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 450,
                        constraints: const BoxConstraints(maxHeight: 600),
                        child: SingleChildScrollView(
                          child: PostCard(post: _generatePreviewPost()),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFluentDesktopLayout() {
    final fluentTheme = fluent.FluentTheme.of(context);

    return AdaptiveScaffold(
      title: Row(
        children: [
          fluent.IconButton(
            icon: const Icon(fluent.FluentIcons.back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/feed'),
          ),
          const SizedBox(width: 8),
          Text(widget.circleId != null ? 'Circle Post' : 'Create Post'),
        ],
      ),
      actions: [
        fluent.FilledButton(
          onPressed: _isLoading ? null : _createPost,
          child: _isLoading
              ? const fluent.SizedBox(
                  width: 16,
                  height: 16,
                  child: fluent.ProgressRing(strokeWidth: 2),
                )
              : const Text('Post'),
        ),
      ],
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: fluent.ScaffoldPage.withPadding(
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFluentUserInfo(),
                    const SizedBox(height: 24),
                    _buildFluentEditor(),
                    const SizedBox(height: 32),
                    _buildFluentActionButtons(),
                    const SizedBox(height: 24),
                    if (_selectedImages.isNotEmpty) _buildFluentImageGallery(),
                    if (_showPollCreator)
                      PollCreator(
                        onPollCreated: _onPollCreated,
                        onCancel: () =>
                            setState(() => _showPollCreator = false),
                      ),
                    if (_attachedPoll != null) _buildFluentAttachedPoll(),
                    if (_locationController.text.isNotEmpty)
                      _buildFluentLocationTag(),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            color: fluentTheme.resources.dividerStrokeColorDefault,
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: fluentTheme.scaffoldBackgroundColor,
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  const Text(
                    'PREVIEW',
                    style: TextStyle(
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 450,
                        constraints: const BoxConstraints(maxHeight: 600),
                        child: SingleChildScrollView(
                          child: PostCard(post: _generatePreviewPost()),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFluentUserInfo() {
    final user = _authService.currentUser;
    final displayName = user?.displayName ?? user?.username ?? 'User';
    final avatarUrl = user?.photoUrl;

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null ? Text(displayName[0].toUpperCase()) : null,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (user?.username != null)
              Text(
                '@${user!.username}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFluentEditor() {
    return Column(
      children: [
        fluent.TextBox(
          controller: _captionController,
          placeholder: "What's on your mind?",
          maxLines: 8,
          minLines: 4,
          padding: const EdgeInsets.all(12),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        fluent.TextBox(
          controller: _hashtagController,
          placeholder: 'Add hashtags (e.g. #nature, #travel)',
          prefix: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Icon(fluent.FluentIcons.tag, size: 16),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildFluentActionButtons() {
    return fluent.Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        fluent.Button(
          onPressed: _pickImages,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(fluent.FluentIcons.photo_collection, size: 16),
              SizedBox(width: 8),
              Text('Photo'),
            ],
          ),
        ),
        fluent.ToggleButton(
          checked: _isSpoiler,
          onChanged: (v) => setState(() => _isSpoiler = v),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(fluent.FluentIcons.hide, size: 16),
              SizedBox(width: 8),
              Text('Spoiler'),
            ],
          ),
        ),
        fluent.Button(
          onPressed: _togglePollCreator,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(fluent.FluentIcons.poll_results, size: 16),
              SizedBox(width: 8),
              Text('Poll'),
            ],
          ),
        ),
        fluent.Button(
          onPressed: _pickLocation,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(fluent.FluentIcons.location, size: 16),
              SizedBox(width: 8),
              Text('Location'),
            ],
          ),
        ),
        fluent.Button(
          onPressed: _showCollaboratorPicker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(fluent.FluentIcons.people_add, size: 16),
              const SizedBox(width: 8),
              Text(_selectedCollaborators.isEmpty
                  ? 'Collaborators'
                  : '${_selectedCollaborators.length} collaborators'),
            ],
          ),
        ),
        MoodSelector(
          selectedMood: _selectedMood,
          showLabel: false,
          onMoodSelected: (mood) {
            setState(() => _selectedMood = mood);
          },
        ),
      ],
    );
  }

  Widget _buildFluentCollaboratorsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('Collaborators', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: _selectedCollaborators.map((u) {
            return Chip(
              label: Text(u['username'] ?? 'User'),
              onDeleted: () => setState(() => _selectedCollaborators.remove(u)),
              deleteIcon: const Icon(Icons.close, size: 14),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFluentImageGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('Images', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedImages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_selectedImages[index].path),
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: fluent.IconButton(
                      icon: const Icon(fluent.FluentIcons.clear, size: 12),
                      onPressed: () =>
                          setState(() => _selectedImages.removeAt(index)),
                      style: fluent.ButtonStyle(
                        backgroundColor: fluent.WidgetStateProperty.all(
                          Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFluentAttachedPoll() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: fluent.Expander(
        header: const Text('Attached Poll'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _attachedPoll!.question,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._attachedPoll!.options.map((o) => Text('• ${o.text}')),
            const SizedBox(height: 12),
            fluent.Button(
              onPressed: () => setState(() => _attachedPoll = null),
              child: const Text('Remove Poll'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFluentLocationTag() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: fluent.InfoBar(
        title: const Text('Location'),
        content: Text(_locationController.text),
        severity: fluent.InfoBarSeverity.info,
        onClose: () => setState(() => _locationController.clear()),
      ),
    );
  }

  Widget _buildDesktopEditorForm() {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Consumer<AuthService>(
          builder: (context, authService, child) {
            final user = authService.currentUser;
            final displayName = user?.displayName ?? user?.username ?? 'User';
            final avatarUrl = user?.photoUrl;

            return Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? Text(displayName[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 12),
                Text(displayName, style: theme.textTheme.titleMedium),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _captionController,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: "What's on your mind?",
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
        ),
        TextField(
          controller: _hashtagController,
          decoration: const InputDecoration(
            hintText: 'Add hashtags...',
            prefixIcon: Icon(Icons.tag),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildActionButton(
              icon: Icons.photo_library,
              label: 'Photo',
              onPressed: _pickImages,
              isM3E: isM3E,
            ),
            _buildActionButton(
              icon: Icons.poll,
              label: 'Poll',
              onPressed: _togglePollCreator,
              isM3E: isM3E,
            ),
            _buildActionButton(
              icon: Icons.location_on,
              label: 'Location',
              onPressed: _pickLocation,
              isM3E: isM3E,
            ),
            _buildActionButton(
              icon: Icons.group_add_outlined,
              label: 'Collaborators',
              onPressed: _showCollaboratorPicker,
              isM3E: isM3E,
              isActive: _selectedCollaborators.isNotEmpty,
            ),
            MoodSelector(
              selectedMood: _selectedMood,
              showLabel: false,
              onMoodSelected: (mood) => setState(() => _selectedMood = mood),
            ),
          ],
        ),
        if (_selectedCollaborators.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: _selectedCollaborators.map((u) {
              return Chip(
                label: Text(u['username'] ?? 'User'),
                onDeleted: () => setState(() => _selectedCollaborators.remove(u)),
                deleteIcon: const Icon(Icons.close, size: 14),
              );
            }).toList(),
          ),
        ],
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => Stack(
                children: [
                  Image.file(
                    File(_selectedImages[index].path),
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          setState(() => _selectedImages.removeAt(index)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_showPollCreator)
          PollCreator(
            onPollCreated: _onPollCreated,
            onCancel: () => setState(() => _showPollCreator = false),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final useFluent = themeProvider.useFluentUI;

    if (isDesktop) {
      return _buildDesktopLayout();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isM3E = themeProvider.isM3EEnabled;

    final formContent = SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Consumer<AuthService>(
            builder: (context, authService, child) {
              final user = authService.currentUser;
              final displayName = user?.displayName ?? user?.username ?? 'User';
              final username = user?.username != null
                  ? '@${user!.username}'
                  : '';
              final avatarUrl = user?.photoUrl;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isM3E
                      ? colorScheme.surfaceContainer.withValues(alpha: 0.5)
                      : colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.3,
                        ),
                  borderRadius: BorderRadius.circular(isM3E ? 24 : 16),
                  border: isM3E
                      ? Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.2,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: isM3E
                            ? Border.all(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.2,
                                ),
                                width: 2,
                              )
                            : null,
                      ),
                      padding: EdgeInsets.all(isM3E ? 2 : 0),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: isM3E
                                      ? FontWeight.w800
                                      : FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: isM3E
                                ? FontWeight.bold
                                : FontWeight.w600,
                            letterSpacing: isM3E ? -0.5 : null,
                          ),
                        ),
                        if (username.isNotEmpty)
                          Text(
                            username,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: isM3E ? FontWeight.w500 : null,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _captionController,
            maxLines: 6,
            minLines: 1,
            decoration: InputDecoration(
              hintText: 'What\'s on your mind?',
              hintStyle:
                  (isM3E
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.bodyLarge)
                      ?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                        fontWeight: isM3E ? FontWeight.w500 : null,
                      ),
              border: InputBorder.none,
            ),
            style:
                (isM3E
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.bodyLarge)
                    ?.copyWith(height: 1.5),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hashtagController,
            decoration: InputDecoration(
              hintText: 'Add hashtags (e.g. #nature, #travel)',
              prefixIcon: Icon(Icons.tag, color: colorScheme.primary, size: 20),
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.2,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isM3E ? 16 : 12),
                borderSide: BorderSide.none,
              ),
            ),
            style: theme.textTheme.bodyMedium,
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final image = _selectedImages[index];
                  return Container(
                    width: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(isM3E ? 24 : 16),
                      boxShadow: isM3E
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isM3E ? 24 : 16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(image.path), fit: BoxFit.cover),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                              onPressed: () => setState(
                                () => _selectedImages.removeAt(index),
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
          MoodSelector(
            selectedMood: _selectedMood,
            onMoodSelected: (mood) {
              HapticUtils.selectionClick();
              setState(() => _selectedMood = mood);
            },
          ),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildActionButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Photo',
                  onPressed: _pickImages,
                  isM3E: isM3E,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: _isSpoiler
                      ? Icons.visibility_off
                      : Icons.visibility_off_outlined,
                  label: 'Spoiler',
                  onPressed: () => setState(() => _isSpoiler = !_isSpoiler),
                  isM3E: isM3E,
                  isActive: _isSpoiler,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.poll_outlined,
                  label: 'Poll',
                  onPressed: _togglePollCreator,
                  isM3E: isM3E,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  onPressed: _pickLocation,
                  isM3E: isM3E,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.group_add_outlined,
                  label: 'Collaborators',
                  onPressed: _showCollaboratorPicker,
                  isM3E: isM3E,
                  isActive: _selectedCollaborators.isNotEmpty,
                ),
              ],
            ),
          ),
          if (_selectedCollaborators.isNotEmpty) ...[
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _selectedCollaborators.map((u) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Chip(
                      label: Text(u['username'] ?? 'User'),
                      onDeleted: () =>
                          setState(() => _selectedCollaborators.remove(u)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          if (_locationController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(isM3E ? 20 : 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 18,
                    color: colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Text(_locationController.text),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => _locationController.clear()),
                    child: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),
          ],
          if (_showPollCreator)
            PollCreator(
              onPollCreated: _onPollCreated,
              onCancel: () => setState(() => _showPollCreator = false),
            ),
          if (_attachedPoll != null) ...[
            const SizedBox(height: 16),
            ListTile(
              tileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const Icon(Icons.poll),
              title: Text(_attachedPoll!.question),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _attachedPoll = null),
              ),
            ),
          ],
        ],
      ),
    );

    return AdaptiveScaffold(
      title: Text(widget.circleId != null ? 'Circle Post' : 'Create Post'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            child: FilledButton(
              onPressed: _isLoading ? null : _createPost,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Post'),
            ),
          ),
        ),
      ],
      body: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 700 : double.infinity,
          ),
          child: formContent,
        ),
      ),
    );
  }
}
