import 'package:flutter/material.dart';
import 'package:oasis/features/stories/domain/models/story_entity.dart';
import 'package:oasis/services/spotify_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/core/utils/haptic_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MusicPickerSheet extends StatefulWidget {
  const MusicPickerSheet({super.key});

  @override
  State<MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<MusicPickerSheet>
    with TickerProviderStateMixin {
  final SpotifyService _spotifyService = SpotifyService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<StoryMusicEntity> _tracks = [];
  List<StoryMusicEntity> _featuredTracks = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _playingTrackId;
  String _currentSearchQuery = '';
  int _displayedCount = 5;
  static const int _pageSize = 10;

  // Animated bars for currently playing track
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _loadFeatured();
    _scrollController.addListener(_onScroll);

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingTrackId = null);
    });
  }

  Future<void> _loadFeatured() async {
    final tracks = await _spotifyService.getFeaturedTracks();
    if (mounted) {
      setState(() {
        _featuredTracks = tracks;
        _tracks = tracks.take(_displayedCount).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      _currentSearchQuery = '';
      setState(() {
        _tracks = _featuredTracks.take(_displayedCount).toList();
        _isSearching = false;
      });
      return;
    }
    _currentSearchQuery = query;
    setState(() => _isSearching = true);
    final results = await _spotifyService.searchTracks(query);
    if (mounted) {
      setState(() {
        _tracks = results.take(_displayedCount).toList();
        _isSearching = false;
      });
    }
  }

  void _loadMore() {
    if (_displayedCount >= _tracks.length) return;
    setState(() {
      _displayedCount = (_displayedCount + _pageSize).clamp(0, _tracks.length);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _togglePreview(StoryMusicEntity track) async {
    try {
      if (_playingTrackId == track.trackId) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _playingTrackId = null);
        _waveController.stop();
        return;
      }

      await _audioPlayer.stop();
      if (mounted) setState(() => _playingTrackId = null);

      if (track.previewUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No preview available for this track'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      await _audioPlayer.play(UrlSource(track.previewUrl));
      if (mounted) {
        setState(() => _playingTrackId = track.trackId);
        _waveController.repeat(reverse: true);
      }
    } catch (e) {
      debugPrint('Audio playback error: $e');
      if (mounted) {
        setState(() => _playingTrackId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not play preview'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
    HapticUtils.selectionClick();
  }

  void _showArtworkPicker(StoryMusicEntity track) async {
    await _audioPlayer.stop();
    if (mounted) setState(() => _playingTrackId = null);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ArtworkPickerSheet(
        track: track,
        onSelect: (updatedTrack) {
          Navigator.pop(context);
          Navigator.pop(context, updatedTrack);
        },
      ),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _audioPlayer.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isM3E ? colorScheme.surface : Colors.black,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isM3E ? 28 : 24),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isM3E
                          ? colorScheme.surfaceContainerHighest
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(isM3E ? 16 : 12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: _search,
                      onChanged: (val) {
                        // Trigger live search as user types (debounced via submit)
                        setState(() {});
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        icon: const Icon(
                          Icons.search,
                          color: Colors.white54,
                          size: 20,
                        ),
                        hintText: 'Search for music...',
                        hintStyle: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _search('');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isM3E ? FontWeight.w800 : FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildSectionHeader(isM3E),
          Expanded(
            child: _isLoading || _isSearching
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _tracks.isEmpty
                ? const Center(
                    child: Text(
                      'No music found',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _tracks.length + 1,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemBuilder: (context, index) {
                      if (index >= _tracks.length) {
                        return _tracks.length >= _displayedCount
                            ? _buildLoadMoreButton(isM3E, colorScheme)
                            : const SizedBox.shrink();
                      }
                      final track = _tracks[index];
                      final isPlaying = _playingTrackId == track.trackId;
                      return _buildTrackTile(
                            track,
                            isPlaying,
                            isM3E,
                            colorScheme,
                          )
                          .animate()
                          .fadeIn(
                            duration: Duration(
                              milliseconds: 100 + (index * 20),
                            ),
                          )
                          .moveY(begin: 10, end: 0);
                    },
                  ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(bool isM3E) {
    final String headerText = _currentSearchQuery.isNotEmpty
        ? 'Results for "$_currentSearchQuery"'
        : 'Featured';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(
            _currentSearchQuery.isNotEmpty ? Icons.search : Icons.music_note,
            color: Colors.white54,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            headerText,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: isM3E ? FontWeight.w600 : FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '${_tracks.length} songs',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(String url, double size, double radius) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          color: Colors.white12,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white38,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: size,
          height: size,
          color: Colors.white10,
          child: Icon(
            Icons.music_note_rounded,
            color: Colors.white38,
            size: size * 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildWaveAnimation() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (i) {
            final heights = [0.4, 1.0, 0.6, 0.85];
            final phase = (i * 0.25 + _waveController.value).clamp(0.0, 1.0);
            final height = 8 + (12 * (heights[i] * phase));
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildTrackTile(
    StoryMusicEntity track,
    bool isPlaying,
    bool isM3E,
    ColorScheme colorScheme,
  ) {
    return ListTile(
      onTap: () => _showArtworkPicker(track),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Stack(
        alignment: Alignment.center,
        children: [
          _buildAlbumArt(track.albumArtUrl, 56, isM3E ? 12 : 8),
          if (isPlaying)
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(isM3E ? 12 : 8),
              ),
              child: Center(child: _buildWaveAnimation()),
            ),
        ],
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: isM3E ? FontWeight.w600 : FontWeight.bold,
          letterSpacing: isM3E ? -0.5 : 0,
        ),
      ),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      trailing: IconButton(
        icon: Icon(
          isPlaying
              ? Icons.pause_circle_filled_rounded
              : Icons.play_circle_filled_rounded,
          color: isPlaying ? colorScheme.primary : Colors.white70,
          size: 36,
        ),
        onPressed: () => _togglePreview(track),
      ),
    );
  }

  Widget _buildLoadMoreButton(bool isM3E, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: TextButton(
          onPressed: _loadMore,
          child: Text(
            'Load more',
            style: TextStyle(
              color: isM3E ? colorScheme.primary : Colors.white70,
              fontWeight: isM3E ? FontWeight.w600 : FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Artwork Picker + Trim Slider ────────────────────────────────────────────

class _ArtworkPickerSheet extends StatefulWidget {
  final StoryMusicEntity track;
  final Function(StoryMusicEntity) onSelect;

  const _ArtworkPickerSheet({required this.track, required this.onSelect});

  @override
  State<_ArtworkPickerSheet> createState() => _ArtworkPickerSheetState();
}

class _ArtworkPickerSheetState extends State<_ArtworkPickerSheet> {
  String _selectedStyle = 'original';
  double _startPositionSec =
      0; // 0–15 seconds start position within 30s preview
  static const double _previewDurationSec = 30;
  static const double _clipDurationSec = 15;

  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _isPreviewPlaying = false;

  @override
  void initState() {
    super.initState();
    _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPreviewPlaying = false);
    });
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  String _formatSeconds(double sec) {
    final m = sec ~/ 60;
    final s = (sec % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _previewFromPosition() async {
    try {
      await _previewPlayer.stop();
      if (_isPreviewPlaying) {
        setState(() => _isPreviewPlaying = false);
        return;
      }
      if (widget.track.previewUrl.isEmpty) return;
      await _previewPlayer.play(UrlSource(widget.track.previewUrl));
      await _previewPlayer.seek(
        Duration(milliseconds: (_startPositionSec * 1000).toInt()),
      );
      setState(() => _isPreviewPlaying = true);
    } catch (e) {
      debugPrint('Trim preview error: $e');
    }
  }

  Widget _buildAlbumArtOption(
    String id,
    String label,
    IconData icon,
    bool isM3E,
    ColorScheme colorScheme,
  ) {
    final isSelected = _selectedStyle == id;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedStyle = id);
        HapticUtils.selectionClick();
      },
      child: Container(
        width: 90,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isM3E
                    ? colorScheme.primaryContainer
                    : Colors.white.withValues(alpha: 0.1))
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(isM3E ? 16 : 12),
          border: isSelected
              ? Border.all(
                  color: isM3E ? colorScheme.primary : Colors.white54,
                  width: 2,
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: _styleClipRadius(id, isM3E),
              child: CachedNetworkImage(
                imageUrl: widget.track.albumArtUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 56,
                  height: 56,
                  color: Colors.white12,
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 56,
                  height: 56,
                  color: Colors.white10,
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Colors.white38,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BorderRadius _styleClipRadius(String style, bool isM3E) {
    switch (style) {
      case 'circle':
        return BorderRadius.circular(40);
      case 'full':
        return BorderRadius.circular(4);
      default:
        return BorderRadius.circular(isM3E ? 12 : 8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final colorScheme = Theme.of(context).colorScheme;

    final maxStart = (_previewDurationSec - _clipDurationSec).clamp(0.0, 30.0);

    final artworkOptions = [
      {'id': 'original', 'label': 'Original', 'icon': Icons.crop_square},
      {'id': 'blurred', 'label': 'Blurred', 'icon': Icons.blur_on},
      {'id': 'circle', 'label': 'Circle', 'icon': Icons.circle},
      {'id': 'full', 'label': 'Full Screen', 'icon': Icons.fullscreen},
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: isM3E ? colorScheme.surface : Colors.black,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isM3E ? 28 : 24),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Track info header
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: widget.track.albumArtUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) =>
                        Container(width: 48, height: 48, color: Colors.white12),
                    errorWidget: (ctx, url, err) => Container(
                      width: 48,
                      height: 48,
                      color: Colors.white10,
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white38,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.track.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: isM3E ? FontWeight.w700 : FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.track.artist,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Artwork Style Section ──
            Text(
              'Artwork Style',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: isM3E ? FontWeight.w600 : FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: artworkOptions
                    .map(
                      (o) => _buildAlbumArtOption(
                        o['id'] as String,
                        o['label'] as String,
                        o['icon'] as IconData,
                        isM3E,
                        colorScheme,
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 24),

            // ── Trim Section ──
            Row(
              children: [
                Text(
                  'Song Segment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: isM3E ? FontWeight.w600 : FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_formatSeconds(_startPositionSec)} – ${_formatSeconds(_startPositionSec + _clipDurationSec)}',
                  style: TextStyle(
                    color: isM3E ? colorScheme.primary : Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                // Preview button
                GestureDetector(
                  onTap: _previewFromPosition,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _isPreviewPlaying
                          ? (isM3E ? colorScheme.primary : Colors.white)
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isPreviewPlaying
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      color: _isPreviewPlaying
                          ? (isM3E ? colorScheme.onPrimary : Colors.black)
                          : Colors.white70,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Drag to choose which 15 seconds plays in your story',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 8),
            // Trim slider
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: isM3E ? colorScheme.primary : Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Colors.white24,
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              ),
              child: Slider(
                value: _startPositionSec,
                min: 0,
                max: maxStart > 0 ? maxStart : 1,
                divisions: maxStart > 0 ? maxStart.toInt() : 1,
                onChanged: maxStart > 0
                    ? (val) async {
                        setState(() => _startPositionSec = val);
                        // Seek if playing
                        if (_isPreviewPlaying) {
                          await _previewPlayer.seek(
                            Duration(milliseconds: (val * 1000).toInt()),
                          );
                        }
                      }
                    : null,
              ),
            ),
            // Timeline ticks
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '0:00',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  Text(
                    _formatSeconds(_previewDurationSec / 2),
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  Text(
                    _formatSeconds(_previewDurationSec),
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Select Button ──
            SizedBox(
              width: double.infinity,
              child: isM3E
                  ? FilledButton(
                      onPressed: () => widget.onSelect(
                        widget.track.copyWith(
                          artworkStyle: _selectedStyle,
                          startPositionMs: (_startPositionSec * 1000).toInt(),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Add to Story',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: () => widget.onSelect(
                        widget.track.copyWith(
                          artworkStyle: _selectedStyle,
                          startPositionMs: (_startPositionSec * 1000).toInt(),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Add to Story',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
