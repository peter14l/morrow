import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oasis/core/storage/prefs_storage.dart';
import 'package:oasis/models/home_location.dart';
import 'package:oasis/services/home_location_service.dart';

class HomeLocationScreen extends StatefulWidget {
  const HomeLocationScreen({super.key});

  @override
  State<HomeLocationScreen> createState() => _HomeLocationScreenState();
}

class _HomeLocationScreenState extends State<HomeLocationScreen> {
  late final HomeLocationService _homeLocationService;
  HomeLocation? _currentLocation;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _homeLocationService = HomeLocationService(PrefsStorage());
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    final location = await _homeLocationService.getHomeLocation();
    setState(() {
      _currentLocation = location;
      _isLoading = false;
    });
  }

  Future<void> _setLocation() async {
    // For now, use a simple coordinate input dialog
    // In a full implementation, this would open a map picker
    final coordinates = await _showCoordinateInputDialog();
    if (coordinates != null) {
      setState(() => _isSaving = true);
      await _homeLocationService.setHomeLocation(
        coordinates.$1,
        coordinates.$2,
      );
      await _loadCurrentLocation();
      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Home location saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _clearLocation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Home Location'),
        content: const Text(
          'Are you sure you want to remove your home location?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      await _homeLocationService.clearHomeLocation();
      await _loadCurrentLocation();
      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Home location cleared')));
      }
    }
  }

  Future<(double, double)?> _showCoordinateInputDialog() async {
    final latController = TextEditingController();
    final lonController = TextEditingController();

    if (_currentLocation != null) {
      latController.text = _currentLocation!.latitude.toString();
      lonController.text = _currentLocation!.longitude.toString();
    }

    return showDialog<(double, double)?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Coordinates'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the coordinates for your home location. '
              'In a full implementation, this would open a map picker.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: latController,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: 'e.g., 37.7749',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: lonController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: 'e.g., -122.4194',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final lat = double.tryParse(latController.text);
              final lon = double.tryParse(lonController.text);
              if (lat != null &&
                  lon != null &&
                  lat >= -90 &&
                  lat <= 90 &&
                  lon >= -180 &&
                  lon <= 180) {
                Navigator.pop(context, (lat, lon));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid coordinates'),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Home Location'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Privacy notice
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your home location is stored only on this device and never sent to servers.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Current location status
                  Text(
                    'Current Location',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_currentLocation == null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_off,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Home location not set',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.home, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Home Set',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _currentLocation!.getDisplayString(),
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Set on: ${_formatDate(_currentLocation!.timestamp)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                  const SizedBox(height: 8),

                  // Action buttons
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _setLocation,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_location_alt),
                      label: Text(
                        _currentLocation == null
                            ? 'Set Home Location'
                            : 'Update Location',
                      ),
                    ),
                  ),

                  if (_currentLocation != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _clearLocation,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Clear Location'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(
                            color: colorScheme.error.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // How it works section
                  Text(
                    'How It Works',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.gps_fixed,
                    title: 'Auto-Detection',
                    description:
                        'Oasis detects when you arrive home using a 100-meter geofence around your saved location.',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoCard(
                    icon: Icons.notifications_active,
                    title: 'Partner Notification',
                    description:
                        'When you arrive home, your partner receives a notification letting them know you\'re safe.',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoCard(
                    icon: Icons.smartphone,
                    title: 'Privacy First',
                    description:
                        'Location monitoring only works when the app is open. Background tracking can be enabled in settings.',
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
