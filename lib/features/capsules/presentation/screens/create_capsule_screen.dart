import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/services/time_capsule_service.dart';
import 'package:oasis/widgets/share_sheet.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/features/settings/presentation/screens/subscription_screen.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:oasis/widgets/adaptive/adaptive_scaffold.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/services/app_initializer.dart';

class CreateCapsuleScreen extends StatefulWidget {
  const CreateCapsuleScreen({super.key});

  @override
  State<CreateCapsuleScreen> createState() => _CreateCapsuleScreenState();
}

class _CreateCapsuleScreenState extends State<CreateCapsuleScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TimeCapsuleService _capsuleService = TimeCapsuleService();

  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));

  // Presets
  final List<Map<String, dynamic>> _datePresets = [
    {
      'label': 'Tomorrow',
      'duration': const Duration(days: 1),
      'icon': Icons.brightness_3,
      'isPro': false,
    },
    {
      'label': 'Next Week',
      'duration': const Duration(days: 7),
      'icon': Icons.calendar_view_week,
      'isPro': false,
    },
    {
      'label': 'Next Year',
      'duration': const Duration(days: 365),
      'icon': Icons.calendar_today,
      'isPro': true,
    },
    {
      'label': '5 Years',
      'duration': const Duration(days: 365 * 5),
      'icon': Icons.rocket_launch,
      'isPro': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final profile = context.read<ProfileProvider>().currentProfile;
        if (profile != null && profile.isPro) {
          setState(() {
            _selectedDate = DateTime.now().add(const Duration(days: 365));
          });
        }
      }
    });
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final profile = context.read<ProfileProvider>().currentProfile;
    final isPro = profile?.isPro ?? false;
    final maxFreeDate = now.add(const Duration(days: 14));

    final picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate.isAfter(
            isPro ? now.add(const Duration(days: 365 * 50)) : maxFreeDate,
          )
          ? now.add(const Duration(days: 1))
          : _selectedDate,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: isPro ? now.add(const Duration(days: 365 * 50)) : maxFreeDate,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _createCapsule() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write a message for your future self'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = context.read<AuthService>().currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final capsule = await _capsuleService.createCapsule(
        userId: userId,
        content: _contentController.text.trim(),
        unlockDate: _selectedDate,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time Capsule sealed successfully!')),
      );

      // Show Share Sheet
      await ShareSheet.show(
        context,
        title: 'Share your memory',
        payload: 'https://oasis-app.com/capsule/${capsule.id}',
        externalMessage:
            'I buried a memory in a Time Capsule. It unlocks on ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}. Download Oasis to open it together: https://oasis-app.com/capsule/${capsule.id}',
      );

      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to seal capsule: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final useFluent = themeProvider.useFluentUI;

    final capsuleContent = SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Write a message to the future',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'This message will stay locked until the date you choose.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Content Input
          if (useFluent && isDesktop)
            fluent.TextBox(
              controller: _contentController,
              placeholder: 'Dear Future Me...',
              maxLines: 8,
              minLines: 4,
              onChanged: (_) => setState(() {}),
            )
          else
            TextField(
              controller: _contentController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Dear Future Me...',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          const SizedBox(height: 32),

          // Date Selection
          Text('Unlock Date', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),

          // Current Selection Display
          InkWell(
            onTap: _pickCustomDate,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.event, color: colorScheme.primary),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Date',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.edit),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Presets Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.5,
            ),
            itemCount: _datePresets.length,
            itemBuilder: (context, index) {
              final preset = _datePresets[index];
              final duration = preset['duration'] as Duration;
              final isProPreset = preset['isPro'] as bool;
              final userIsPro =
                  context.read<ProfileProvider>().currentProfile?.isPro ??
                  false;
              final isLocked = isProPreset && !userIsPro;

              if (useFluent && isDesktop) {
                return fluent.Button(
                  onPressed: () {
                    if (isLocked) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SubscriptionScreen(),
                        ),
                      );
                    } else {
                      setState(() {
                        _selectedDate = DateTime.now().add(duration);
                      });
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isLocked
                            ? fluent.FluentIcons.lock
                            : (index == 0
                                  ? fluent.FluentIcons.brightness
                                  : (index == 1
                                        ? fluent.FluentIcons.calendar_week
                                        : (index == 2
                                              ? fluent.FluentIcons.calendar
                                              : fluent.FluentIcons.rocket))),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(preset['label'] as String),
                    ],
                  ),
                );
              }

              return OutlinedButton.icon(
                onPressed: () {
                  if (isLocked) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SubscriptionScreen(),
                      ),
                    );
                  } else {
                    setState(() {
                      _selectedDate = DateTime.now().add(duration);
                    });
                  }
                },
                icon: Icon(
                  isLocked ? Icons.lock : preset['icon'] as IconData,
                  size: 18,
                ),
                label: Text(preset['label'] as String),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isLocked
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.primary,
                  side: BorderSide(
                    color: isLocked
                        ? colorScheme.outlineVariant
                        : colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
          if (isDesktop) ...[
            const SizedBox(height: 40),
            SizedBox(
              height: 50,
              child: useFluent
                  ? fluent.FilledButton(
                      onPressed: _isLoading ? null : _createCapsule,
                      child: _isLoading
                          ? const fluent.ProgressRing(strokeWidth: 2)
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(fluent.FluentIcons.lock, size: 16),
                                SizedBox(width: 8),
                                Text('Seal Time Capsule'),
                              ],
                            ),
                    )
                  : FilledButton.icon(
                      onPressed: _isLoading ? null : _createCapsule,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.lock_clock),
                      label: const Text(
                        'Seal Time Capsule',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );

    if (isDesktop) {
      if (useFluent) {
        return AdaptiveScaffold(
          title: Row(
            children: [
              fluent.IconButton(
                icon: const Icon(fluent.FluentIcons.back),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/feed'),
              ),
              const SizedBox(width: 8),
              const Text('New Time Capsule'),
            ],
          ),
          actions: [
            fluent.FilledButton(
              onPressed: _isLoading ? null : _createCapsule,
              child: _isLoading
                  ? const fluent.ProgressRing(strokeWidth: 2)
                  : const Text('Seal'),
            ),
          ],
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: capsuleContent,
            ),
          ),
        );
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
            const Text('New Time Capsule'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _createCapsule,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_clock, size: 18),
                label: const Text('Seal'),
              ),
            ),
          ),
        ],
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: capsuleContent,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Time Capsule'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _createCapsule,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_clock),
              label: const Text('Seal'),
            ),
          ),
        ],
      ),
      body: capsuleContent,
    );
  }
}
