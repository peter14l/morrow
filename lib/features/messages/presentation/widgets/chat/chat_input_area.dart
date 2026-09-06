import 'dart:ui' as ui;
import 'package:flutter/material.dart'
    hide
        IconButton,
        Icon,
        Row,
        Column,
        Container,
        Padding,
        Center,
        Stack,
        Align,
        Positioned,
        SizedBox,
        Expanded,
        Spacer,
        GestureDetector;
import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:oasis/widgets/dotted_border_painter.dart';
import 'package:oasis/widgets/custom_text_field.dart';
import 'package:oasis/widgets/liquid_glass_wrapper.dart';
import 'package:oasis/features/messages/presentation/widgets/shared/recording_dot.dart';

/// Chat input area with text field, attachment button, and send/record toggle.
/// Matches the legacy chat_screen.dart input section exactly.
class ChatInputArea extends StatefulWidget {
  const ChatInputArea({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onAttachment,
    required this.onSticker,
    required this.isRecording,
    required this.recordDuration,
    required this.isSending,
    required this.isWhisperMode,
    required this.onToggleRecording,
    required this.isSpoiler,
    required this.onSpoilerToggle,
    this.textNotifier,
    this.backgroundUrl,
    this.textColor,
    this.hintText,
    this.hasAttachment = false,
    this.isDesktop = false,
    this.onPickImage,
    this.onPickVideo,
    this.onPickFile,
    this.onPickAudio,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onAttachment;
  final VoidCallback onSticker;
  final bool isRecording;
  final int recordDuration;
  final bool isSending;
  final int isWhisperMode;
  final VoidCallback onToggleRecording;
  final bool isSpoiler;
  final VoidCallback onSpoilerToggle;
  final ValueListenable<String>? textNotifier;
  final String? backgroundUrl;
  final Color? textColor;
  final String? hintText;
  final bool hasAttachment;
  final bool isDesktop;

  final VoidCallback? onPickImage;
  final VoidCallback? onPickVideo;
  final VoidCallback? onPickFile;
  final VoidCallback? onPickAudio;

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  final fluent.FlyoutController _flyoutController = fluent.FlyoutController();
  material.ValueNotifier<String>? _fallbackTextNotifier;

  ValueListenable<String> get _effectiveTextNotifier {
    if (widget.textNotifier != null) return widget.textNotifier!;
    if (_fallbackTextNotifier == null) {
      _fallbackTextNotifier = material.ValueNotifier<String>(widget.controller.text);
      widget.controller.addListener(_onControllerTextChanged);
    }
    return _fallbackTextNotifier!;
  }

  void _onControllerTextChanged() {
    _fallbackTextNotifier?.value = widget.controller.text;
  }

  @override
  void didUpdateWidget(covariant ChatInputArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerTextChanged);
      _fallbackTextNotifier?.value = widget.controller.text;
      widget.controller.addListener(_onControllerTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerTextChanged);
    _fallbackTextNotifier?.dispose();
    _flyoutController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = material.Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = material.BorderRadius.circular(32);

    // Common recording view
    final Widget recordingView = material.Row(
      children: [
        const material.SizedBox(width: 12),
        const RecordingDot(),
        const material.SizedBox(width: 8),
        material.Text(
          'Recording...',
          style: material.TextStyle(
            color: widget.backgroundUrl != null
                ? material.Colors.white
                : colorScheme.error,
            fontWeight: material.FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const material.Spacer(),
        material.ValueListenableBuilder<String>(
          valueListenable: _effectiveTextNotifier,
          builder: (context, text, child) {
            final durationText = widget.controller.text.isEmpty
                ? _formatDuration(widget.recordDuration)
                : '';
            return material.Text(
              durationText,
              style: material.TextStyle(
                color: widget.backgroundUrl != null
                    ? material.Colors.white70
                    : colorScheme.onSurfaceVariant,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
                fontWeight: material.FontWeight.w500,
              ),
            );
          },
        ),
        const material.SizedBox(width: 12),
      ],
    );

    // Send/Mic button builder — circle container stays fixed, only icon morphs inside
    Widget buildActionButton(bool isTyping) {
      final bool showMic = !isTyping && !widget.hasAttachment;
      final String buttonKey;
      if (widget.isSending) {
        buttonKey = 'sending';
      } else if (showMic) {
        buttonKey = widget.isRecording ? 'stop' : 'mic';
      } else {
        buttonKey = 'send';
      }

      return material.Container(
        margin: widget.isDesktop
            ? const material.EdgeInsets.only(right: 4)
            : null,
        decoration: material.BoxDecoration(
          color: widget.isSending
              ? colorScheme.onSurface.withValues(alpha: 0.12)
              : (showMic
                    ? (widget.isRecording
                          ? material.Colors.red
                          : colorScheme.primary)
                    : colorScheme.secondary),
          shape: material.BoxShape.circle,
        ),
        child: material.IconButton(
          onPressed: widget.isSending
              ? null
              : (showMic ? widget.onToggleRecording : widget.onSend),
          icon: material.AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                material.ScaleTransition(scale: animation, child: child),
            child: widget.isSending
                ? material.SizedBox(
                    key: const material.ValueKey('sending'),
                    width: 20,
                    height: 20,
                    child: material.CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : material.Icon(
                    key: material.ValueKey(buttonKey),
                    showMic
                        ? (widget.isRecording
                              ? material.Icons.stop_rounded
                              : material.Icons.mic)
                        : material.Icons.send_rounded,
                    color: showMic
                        ? colorScheme.onPrimary
                        : colorScheme.onSecondary,
                    size: widget.isDesktop ? 22 : null,
                  ),
          ),
        ),
      );
    }

    final Widget inputArea = LiquidGlassWrapper(
      borderRadius: 32,
      config: LiquidGlassConfig.Medium,
      backgroundColor: widget.isDesktop
          ? material.Colors.black.withValues(alpha: 0.8)
          : null,
      shape: const LiquidRoundedSuperellipse(borderRadius: 32),
      child: material.Padding(
        padding: const material.EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 3,
        ),
        child: material.Row(
          crossAxisAlignment: material.CrossAxisAlignment.center,
        children: [          // Left actions container (Attachment, Stickers & Spoiler button).
          // They live in a single fixed-size slot so appearing/disappearing or
          // switching on typing never changes the text field's width or the input area's
          // height — preventing layout jitter and height fluctuations.
          material.ValueListenableBuilder<String>(
            valueListenable: _effectiveTextNotifier,
            builder: (context, text, child) {
              final bool isTyping = text.trim().isNotEmpty;
              final bool showSpoiler = isTyping || widget.hasAttachment;
              final double slotWidth = widget.isDesktop ? 88.0 : 100.0;

              return material.SizedBox(
                width: slotWidth,
                height: 48,
                child: material.AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: showSpoiler
                      ? material.Center(
                          key: const material.ValueKey('spoiler-btn-active'),
                          child: material.IconButton(
                            onPressed: widget.onSpoilerToggle,
                            icon: material.Icon(
                              widget.isSpoiler
                                  ? material.Icons.visibility_off
                                  : material.Icons.visibility_off_outlined,
                              color: widget.isSpoiler
                                  ? colorScheme.primary
                                  : (widget.isDesktop
                                      ? material.Colors.white38
                                      : colorScheme.onSurfaceVariant.withValues(
                                          alpha: 0.6,
                                        )),
                              size: widget.isDesktop ? 22 : 20,
                            ),
                            tooltip: 'Mark as Spoiler',
                            constraints: const material.BoxConstraints(),
                            padding: const material.EdgeInsets.all(8),
                          ),
                        )
                      : material.Row(
                          key: const material.ValueKey('leading-actions-inactive'),
                          mainAxisSize: material.MainAxisSize.min,
                          children: [
                            widget.isDesktop
                                ? fluent.FlyoutTarget(
                                    controller: _flyoutController,
                                    child: material.IconButton(
                                      onPressed: () {
                                        _flyoutController.showFlyout(
                                          autoModeConfiguration:
                                              fluent.FlyoutAutoConfiguration(
                                            preferredMode: fluent
                                                .FlyoutPlacementMode
                                                .topCenter,
                                          ),
                                          barrierDismissible: true,
                                          dismissWithEsc: true,
                                          builder: (context) {
                                            return fluent.MenuFlyout(
                                              items: [
                                                fluent.MenuFlyoutItem(
                                                  leading: const material.Icon(
                                                    material.Icons.image_rounded,
                                                    size: 20,
                                                    color: material.Color(
                                                      0xFF3D8BFF,
                                                    ),
                                                  ),
                                                  text: const material.Text(
                                                    'Photo',
                                                  ),
                                                  onPressed: () {
                                                    _flyoutController.close();
                                                    widget.onPickImage?.call();
                                                  },
                                                ),
                                                fluent.MenuFlyoutItem(
                                                  leading: const material.Icon(
                                                    material
                                                        .Icons
                                                        .videocam_rounded,
                                                    size: 20,
                                                    color: material.Color(
                                                      0xFFFF6B6B,
                                                    ),
                                                  ),
                                                  text: const material.Text(
                                                    'Video',
                                                  ),
                                                  onPressed: () {
                                                    _flyoutController.close();
                                                    widget.onPickVideo?.call();
                                                  },
                                                ),
                                                fluent.MenuFlyoutItem(
                                                  leading: const material.Icon(
                                                    material
                                                        .Icons
                                                        .insert_drive_file_rounded,
                                                    size: 20,
                                                    color: material.Color(
                                                      0xFF51CF66,
                                                    ),
                                                  ),
                                                  text: const material.Text(
                                                    'File',
                                                  ),
                                                  onPressed: () {
                                                    _flyoutController.close();
                                                    widget.onPickFile?.call();
                                                  },
                                                ),
                                                fluent.MenuFlyoutItem(
                                                  leading: const material.Icon(
                                                    material
                                                        .Icons
                                                        .audio_file_rounded,
                                                    size: 20,
                                                    color: material.Color(
                                                      0xFFFFD43B,
                                                    ),
                                                  ),
                                                  text: const material.Text(
                                                    'Audio',
                                                  ),
                                                  onPressed: () {
                                                    _flyoutController.close();
                                                    widget.onPickAudio?.call();
                                                  },
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                      icon: const material.Icon(
                                        material.Icons.add_circle_outline,
                                        color: material.Colors.white70,
                                        size: 24,
                                      ),
                                      constraints:
                                          const material.BoxConstraints(),
                                      padding: const material.EdgeInsets.all(8),
                                    ),
                                  )
                                : material.IconButton(
                                    onPressed: widget.onAttachment,
                                    icon: material.Icon(
                                      material.Icons.add_circle_outline,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                            material.IconButton(
                              onPressed: widget.onSticker,
                              icon: material.Icon(
                                material.Icons.sticky_note_2_outlined,
                                color: widget.isDesktop
                                    ? material.Colors.white
                                    : colorScheme.primary,
                                size: widget.isDesktop ? 24 : null,
                              ),
                              tooltip: 'Stickers & GIFs',
                            ),
                            const material.SizedBox(width: 4),
                          ],
                        ),
                ),
              );
            },
          ),  

          material.Expanded(
            child: material.Padding(
              padding: const material.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: widget.isRecording
                  ? recordingView
                  : material.CallbackShortcuts(
                      bindings: {
                        const material.SingleActivator(
                          LogicalKeyboardKey.enter,
                          includeRepeats: false,
                        ): () {
                          final keys =
                              HardwareKeyboard.instance.logicalKeysPressed;
                          if (keys.contains(LogicalKeyboardKey.shiftLeft) ||
                              keys.contains(LogicalKeyboardKey.shiftRight)) {
                            return;
                          }
                          if (widget.controller.text.trim().isNotEmpty ||
                              widget.hasAttachment) {
                            widget.onSend();
                          }
                        },
                      },
                      child: widget.isDesktop
                          ? fluent.TextBox(
                              controller: widget.controller,
                              focusNode: widget.focusNode,
                              placeholder: widget.hintText ?? 'Type a message...',
                              padding: const material.EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: fluent.WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                return fluent.BoxDecoration(
                                  color: material.Colors.transparent,
                                  borderRadius:
                                      material.BorderRadius.circular(12),
                                  border: material.Border.all(
                                    color: material.Colors.transparent,
                                    width: 0,
                                  ),
                                );
                              }),
                              style: const material.TextStyle(
                                color: material.Colors.white,
                                fontSize: 14,
                                height: 1.2,
                              ),
                              placeholderStyle: const material.TextStyle(
                                color: material.Colors.white38,
                                fontSize: 14,
                                height: 1.2,
                              ),
                              cursorColor: fluent.FluentTheme.of(
                                context,
                              ).accentColor,
                              scrollPhysics:
                                  const material.BouncingScrollPhysics(),
                              maxLines: null,
                              minLines: 1,
                            )
                          : CustomTextField(
                              controller: widget.controller,
                              focusNode: widget.focusNode,
                              hint: widget.hintText ?? 'Type a message...',
                              fillColor: material.Colors.transparent,
                              textColor: widget.isDesktop
                                  ? material.Colors.white
                                  : null,
                              hintColor: widget.isDesktop
                                  ? material.Colors.white38
                                  : null,
                              maxLines: 5,
                              minLines: 1,
                              textCapitalization:
                                  material.TextCapitalization.sentences,
                              isDense: true,
                              contentPadding: const material.EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              margin: material.EdgeInsets.zero,
                              border: material.InputBorder.none,
                              enabledBorder: material.InputBorder.none,
                              focusedBorder: material.InputBorder.none,
                            ),
                    ),
            ),
          ),
          const material.SizedBox(width: 4),
          material.ValueListenableBuilder<String>(
            valueListenable: _effectiveTextNotifier,
            builder: (context, text, child) {
              return material.Padding(
                padding: const material.EdgeInsets.only(bottom: 0),
                child: buildActionButton(text.trim().isNotEmpty),
              );
            },
          ),
        ],
      ),
    ),
  );

    final Widget paddedInputArea = material.Padding(
      padding: const material.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: inputArea,
    );

    if (widget.isWhisperMode > 0) {
      return material.CustomPaint(
        painter: DottedBorderPainter(
          color: material.Colors.white.withValues(alpha: 0.4),
          strokeWidth: 1.5,
          gap: 4,
          dash: 4,
          borderRadius: borderRadius,
        ),
        child: material.Padding(
          padding: const material.EdgeInsets.all(4),
          child: paddedInputArea,
        ),
      );
    }

    return paddedInputArea;
  }
}
