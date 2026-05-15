import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CommunitySetupConfirmationScreen extends StatelessWidget {
  final Map<String, dynamic> communityData;

  const CommunitySetupConfirmationScreen({
    super.key,
    required this.communityData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF1152D4).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 60,
                  color: Color(0xFF1152D4),
                ),
              ),
              const SizedBox(height: 32),
              // Title
              const Text(
                'Community Created!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Subtitle
              Text(
                'Your ${communityData['name']} community is now live!',
                style: const TextStyle(fontSize: 16, color: Color(0xFF9DA6B9)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              // Community Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E232D),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Community Name
                    Text(
                      communityData['name'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Community Theme
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF282E39),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        communityData['theme'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Privacy Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: communityData['isPrivate']
                            ? const Color(0xFF2E1A33)
                            : const Color(0xFF1A2E28),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            communityData['isPrivate']
                                ? Icons.lock_outline
                                : Icons.public,
                            size: 16,
                            color: communityData['isPrivate']
                                ? const Color(0xFFD32F2F)
                                : const Color(0xFF4CAF50),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            communityData['isPrivate']
                                ? 'Private Community'
                                : 'Public Community',
                            style: TextStyle(
                              color: communityData['isPrivate']
                                  ? const Color(0xFFD32F2F)
                                  : const Color(0xFF4CAF50),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Member Count
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 20,
                          color: Color(0xFF9DA6B9),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '1 member',
                          style: TextStyle(
                            color: Color(0xFF9DA6B9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              // Action Buttons
              Column(
                children: [
                  // Invite Members Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Invite members functionality
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1152D4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Invite Members',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Go to Community Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        // Navigate to the community
                        context.go('/community/${communityData['id']}');
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF3D4451)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Go to Community',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Share Button
                  TextButton(
                    onPressed: () {
                      // Share community functionality
                    },
                    child: const Text(
                      'Share Community',
                      style: TextStyle(
                        color: Color(0xFF1152D4),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
