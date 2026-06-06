import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart' as services;
import 'package:oasis/widgets/mesh_gradient_background.dart';
import 'package:oasis/themes/app_theme.dart';

class IncomingCallOverlayScreen extends StatelessWidget {
  final String callerName;
  final String callId;
  final String callerAvatar;
  final services.MethodChannel channel;

  const IncomingCallOverlayScreen({
    super.key,
    required this.callerName,
    required this.callId,
    required this.callerAvatar,
    required this.channel,
  });

  @override
  Widget build(BuildContext context) {
    return material.Scaffold(
      backgroundColor: const material.Color(0xFF080A0E),
      body: material.Stack(
        children: [
          MeshGradientBackground(
            child: material.SafeArea(
              child: material.Center(
                child: material.Column(
                  mainAxisAlignment: material.MainAxisAlignment.center,
                  children: [
                    if (callerAvatar.isNotEmpty)
                      material.CircleAvatar(
                        radius: 60,
                        backgroundImage: CachedNetworkImageProvider(
                          callerAvatar,
                        ),
                      )
                    else
                      const material.CircleAvatar(
                        radius: 60,
                        backgroundColor: material.Color(0xFF1A1D24),
                        child: material.Icon(
                          material.Icons.person,
                          size: 60,
                          color: material.Colors.white54,
                        ),
                      ),

                    const material.SizedBox(height: 32),

                    material.Text(
                      callerName,
                      style: const material.TextStyle(
                        color: material.Colors.white,
                        fontSize: 32,
                        fontWeight: material.FontWeight.bold,
                      ),
                    ),

                    const material.SizedBox(height: 8),

                    material.Text(
                      'Oasis Audio Call',
                      style: material.TextStyle(
                        color: material.Colors.white.withValues(alpha: 0.7),
                        fontSize: 16,
                      ),
                    ),

                    const material.Spacer(),

                    // Buttons
                    material.Padding(
                      padding: const material.EdgeInsets.symmetric(
                        horizontal: 48.0,
                        vertical: 64.0,
                      ),
                      child: material.Row(
                        mainAxisAlignment:
                            material.MainAxisAlignment.spaceBetween,
                        children: [
                          // Decline
                          material.Column(
                            children: [
                              material.FloatingActionButton(
                                heroTag: 'decline_btn',
                                onPressed: () async {
                                  await channel.invokeMethod(
                                    'finishCallActivity',
                                  );
                                },
                                backgroundColor: material.Colors.redAccent,
                                child: const material.Icon(
                                  material.Icons.call_end,
                                  color: material.Colors.white,
                                animateRange: null,
                                ),
                              ),
                              const material.SizedBox(height: 12),
                              const material.Text(
                                'Decline',
                                style: material.TextStyle(
                                  color: material.Colors.white,
                                ),
                              ),
                            ],
                          ),

                          // Accept
                          material.Column(
                            children: [
                              material.FloatingActionButton(
                                heroTag: 'accept_btn',
                                onPressed: () async {
                                  // Signal native to accept the call and launch the main app
                                  await channel.invokeMethod('acceptCall', {
                                    'callId': callId,
                                    'callerName': callerName,
                                  });
                                },
                                backgroundColor: material.Colors.greenAccent,
                                child: const material.Icon(
                                  material.Icons.call,
                                  color: material.Colors.white,
                                ),
                              ),
                              const material.SizedBox(height: 12),
                              const material.Text(
                                'Accept',
                                style: material.TextStyle(
                                  color: material.Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
