import 'package:flutter/material.dart';
import 'package:oasis/services/time_capsule_service.dart';
import 'package:oasis/features/capsules/domain/models/time_capsule_entity.dart';
import 'package:oasis/widgets/fluid_mesh_background.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class CapsuleViewScreen extends StatefulWidget {
  final String capsuleId;
  const CapsuleViewScreen({super.key, required this.capsuleId});

  @override
  State<CapsuleViewScreen> createState() => _CapsuleViewScreenState();
}

class _CapsuleViewScreenState extends State<CapsuleViewScreen> {
  TimeCapsule? _capsule;
  bool _isLoading = true;
  final TimeCapsuleService _capsuleService = TimeCapsuleService();

  @override
  void initState() {
    super.initState();
    _loadCapsule();
  }

  Future<void> _loadCapsule() async {
    try {
      final capsule = await _capsuleService.getCapsule(widget.capsuleId);
      setState(() {
        _capsule = capsule;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_capsule == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(
          child: Text(
            'Time Capsule not found',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final isLocked = _capsule!.unlockDate.isAfter(DateTime.now());

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: FluidMeshBackground(streakCount: isLocked ? 0 : 100),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isLocked
                        ? Icons.lock_clock_rounded
                        : Icons.auto_awesome_rounded,
                    size: 80,
                    color: isLocked ? Colors.amber : Colors.greenAccent,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    isLocked
                        ? 'This memory is still sealed'
                        : 'A memory has been unsealed',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white70,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (isLocked) ...[
                    Text(
                      'Unlocks on',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white38,
                      ),
                    ),
                    Text(
                      DateFormat('MMMM d, yyyy').format(_capsule!.unlockDate),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else ...[
                    Text(
                      _capsule!.content,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 48),
                  Text(
                    'Created by ${_capsule!.username}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 64),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.go('/feed'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('GO TO FEED'),
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
}
