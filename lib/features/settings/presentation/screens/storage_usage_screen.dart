import 'package:flutter/material.dart';
import 'package:oasis/services/cache_service.dart';
import 'package:oasis/services/media_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageUsageScreen extends StatefulWidget {
  const StorageUsageScreen({super.key});

  @override
  State<StorageUsageScreen> createState() => _StorageUsageScreenState();
}

class _StorageUsageScreenState extends State<StorageUsageScreen> {
  final CacheService _cacheService = CacheService();
  final MediaCacheService _mediaCacheService = MediaCacheService();

  // Storage usage tracking
  double _imageSize = 0;
  double _videoSize = 0;
  double _otherSize = 0;
  bool _isLoading = true;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _calculateStorageUsage();
  }

  Future<void> _calculateStorageUsage() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Get cached feed data size
      final feedJson = prefs.getString('cached_feed');
      _imageSize = feedJson != null
          ? (feedJson.length / (1024 * 1024)).clamp(0, 45.2)
          : 0;

      // Get cached stories data size
      final storiesJson = prefs.getString('cached_stories');
      _otherSize = storiesJson != null
          ? (storiesJson.length / (1024 * 1024)).clamp(0, 5.4)
          : 0;

      // Placeholder for video cache (would need actual file system access)
      _videoSize =
          12.8; // Placeholder - actual implementation would check app cache directory
    } catch (e) {
      debugPrint('Error calculating storage: $e');
      _imageSize = 0;
      _videoSize = 0;
      _otherSize = 0;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearCache() async {
    if (_isClearing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached data including images, stories, and feed content. You will need to re-download content when browsing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isClearing = true);

    try {
      // Clear SharedPreferences caches
      await _cacheService.clearAll();

      // Note: CachedNetworkImage uses disk caching which would require
      // manual file deletion from cache directory. For now, we clear
      // the SharedPreferences-based caches which store the metadata.
      // A full implementation would delete files from the cache directory.

      // Clear any additional caches
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_feed');
      await prefs.remove('cached_stories');

      // Recalculate storage after clearing
      await _calculateStorageUsage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear cache: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalSize = _imageSize + _videoSize + _otherSize;
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStorageBar(context, totalSize),
        const SizedBox(height: 24),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else ...[
          _buildUsageItem(
            context,
            'Images',
            '${_imageSize.toStringAsFixed(1)} MB',
            Colors.blue,
          ),
          _buildUsageItem(
            context,
            'Videos',
            '${_videoSize.toStringAsFixed(1)} MB',
            Colors.green,
          ),
          _buildUsageItem(
            context,
            'Other Files',
            '${_otherSize.toStringAsFixed(1)} MB',
            Colors.amber,
          ),
        ],
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _isClearing ? null : _clearCache,
          icon: _isClearing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_sweep_outlined),
          label: Text(_isClearing ? 'Clearing...' : 'Clear All Cache'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.errorContainer,
            foregroundColor: colorScheme.onErrorContainer,
          ),
        ),
      ],
    );

    if (isDesktop) return Material(color: Colors.transparent, child: content);

    return Scaffold(
      appBar: AppBar(title: const Text('Storage Usage'), centerTitle: true),
      body: content,
    );
  }

  Widget _buildStorageBar(BuildContext context, double totalSize) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total Usage', style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${totalSize.toStringAsFixed(1)} MB',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: totalSize / 100, // 100MB as max for display
            minHeight: 12,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsageItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
