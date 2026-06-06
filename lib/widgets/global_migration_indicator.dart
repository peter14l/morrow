import 'package:flutter/material.dart';
import 'package:oasis/core/theme/oasis_colors.dart';
import 'package:oasis/services/instagram_migration_service.dart';

class GlobalMigrationIndicator extends StatelessWidget {
  const GlobalMigrationIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final service = InstagramMigrationService();
    
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (!service.isMigrating && service.progress == 0.0 && service.currentStatus.isEmpty) {
          return const SizedBox.shrink();
        }

        // Auto-hide when complete
        if (!service.isMigrating && service.progress >= 1.0) {
          Future.delayed(const Duration(seconds: 4), () {
            service.reset();
          });
        }

        return Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: service.isMigrating ? OasisColors.deep.withOpacity(0.9) : OasisColors.sage.withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: service.isMigrating ? OasisColors.glow.withOpacity(0.5) : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                if (service.isMigrating)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(OasisColors.glow),
                    ),
                  )
                else
                  const Icon(Icons.check_circle, color: OasisColors.deep, size: 20),
                
                const SizedBox(width: 12),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        service.isMigrating ? 'Syncing Instagram Posts...' : 'Sync Complete!',
                        style: TextStyle(
                          color: service.isMigrating ? Colors.white : OasisColors.deep,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (service.isMigrating) ...[
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: service.progress,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(OasisColors.glow),
                          minHeight: 2,
                        ),
                      ],
                    ],
                  ),
                ),
                
                if (service.isMigrating) ...[
                  const SizedBox(width: 12),
                  Text(
                    '${(service.progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: OasisColors.mist,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
