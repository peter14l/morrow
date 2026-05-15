import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final int? duration;
  final bool isMe;
  final Color color;

  const VoiceMessagePlayer({
    super.key,
    required this.audioUrl,
    this.duration,
    required this.isMe,
    required this.color,
  });

  @override
  VoiceMessagePlayerState createState() => VoiceMessagePlayerState();
}

class VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isError = false;
  bool _isDragging = false;
  double _playbackSpeed = 1.0;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  final List<double> _speeds = [0.5, 1.0, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.duration ?? 0);
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    try {
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      });

      _audioPlayer.onDurationChanged.listen((duration) {
        if (mounted && duration.inSeconds > 0) {
          setState(() {
            _duration = duration;
          });
        }
      });

      _audioPlayer.onPositionChanged.listen((position) {
        if (mounted && !_isDragging) {
          setState(() {
            _position = position;
          });
        }
      });

      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero; // Reset to start
          });
        }
      });

      // Pre-load the source
      if (widget.audioUrl.isNotEmpty) {
        if (widget.audioUrl.startsWith('http') ||
            widget.audioUrl.startsWith('https')) {
          await _audioPlayer.setSourceUrl(widget.audioUrl);
        } else {
          await _audioPlayer.setSourceDeviceFile(widget.audioUrl);
        }
      }
    } catch (e) {
      debugPrint('Error initializing audio: $e');
      if (mounted) setState(() => _isError = true);
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isError) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (widget.audioUrl.isEmpty) return;
        // If we are at the end, restart
        if (_position >= _duration && _duration.inSeconds > 0) {
          await _audioPlayer.seek(Duration.zero);
        }
        await _audioPlayer.setPlaybackRate(_playbackSpeed);

        Source source;
        if (widget.audioUrl.startsWith('http') ||
            widget.audioUrl.startsWith('https')) {
          source = UrlSource(widget.audioUrl);
        } else {
          source = DeviceFileSource(widget.audioUrl);
        }
        await _audioPlayer.play(source);
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
      if (mounted) setState(() => _isError = true);
    }
  }

  Future<void> _cycleSpeed() async {
    final currentIndex = _speeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % _speeds.length;
    final nextSpeed = _speeds[nextIndex];

    setState(() {
      _playbackSpeed = nextSpeed;
    });

    await _audioPlayer.setPlaybackRate(nextSpeed);
  }

  void _onSeek(double value) {
    final targetPosition = Duration(seconds: value.toInt());
    _audioPlayer.seek(targetPosition);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Text(
              'Audio error',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(left: 4, right: 8, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: widget.isMe
            ? widget.color.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              _isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              color: widget.color,
              size: 38,
            ),
            onPressed: _togglePlayPause,
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130, // Slightly reduced to fit speed button
                height: 20,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    activeTrackColor: widget.color,
                    inactiveTrackColor: widget.color.withValues(alpha: 0.2),
                    thumbColor: widget.color,
                    overlayColor: widget.color.withValues(alpha: 0.1),
                  ),
                  child: Slider(
                    value: _position.inSeconds.toDouble().clamp(
                      0,
                      _duration.inSeconds.toDouble(),
                    ),
                    min: 0,
                    max: _duration.inSeconds > 0
                        ? _duration.inSeconds.toDouble()
                        : 1.0,
                    onChangeStart: (_) => setState(() => _isDragging = true),
                    onChangeEnd: (val) {
                      _onSeek(val);
                      setState(() => _isDragging = false);
                    },
                    onChanged: (val) {
                      setState(() {
                        _position = Duration(seconds: val.toInt());
                      });
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                  style: TextStyle(
                    fontSize: 9,
                    color: widget.color.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          // Speed Control Button
          InkWell(
            onTap: _cycleSpeed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_playbackSpeed.toString().replaceAll('.0', '')}x',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
