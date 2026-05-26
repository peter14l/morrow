import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class CanvasAudioService {
  static final CanvasAudioService _instance = CanvasAudioService._internal();
  factory CanvasAudioService() => _instance;
  CanvasAudioService._internal();

  final List<String> _playlist = [
    'audio/hasin2004-nature-sound-near-river-or-waterfall-247409.mp3',
    'audio/richardmultimedia-birds-and-waterfall-250309.mp3',
    'audio/richardmultimedia-birds-near-waterfall-324855.mp3',
  ];

  final AudioPlayer _player1 = AudioPlayer();
  final AudioPlayer _player2 = AudioPlayer();

  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isFirstPlay = true;
  Timer? _crossfadeTimer;

  Future<void> start() async {
    if (_isPlaying) return;
    _isPlaying = true;
    _isFirstPlay = true;
    _currentIndex = 0;

    debugPrint('CanvasAudioService: Starting ambient loop');
    await _playNext();
  }

  Future<void> _playNext() async {
    if (!_isPlaying) return;

    final currentAsset = _playlist[_currentIndex];
    final nextIndex = (_currentIndex + 1) % _playlist.length;
    final nextAsset = _playlist[nextIndex];

    final activePlayer = _currentIndex % 2 == 0 ? _player1 : _player2;
    final idlePlayer = _currentIndex % 2 == 0 ? _player2 : _player1;

    try {
      debugPrint('CanvasAudioService: Playing $currentAsset');

      // 1. Start current track
      await activePlayer.setSource(AssetSource(currentAsset));
      await activePlayer.setVolume(_isFirstPlay ? 1.0 : 1.0);
      await activePlayer.resume();
      _isFirstPlay = false;

      // 2. Wait for duration to be available
      Duration? duration;
      int attempts = 0;
      while (duration == null && attempts < 10 && _isPlaying) {
        duration = await activePlayer.getDuration();
        if (duration == null) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
        attempts++;
      }

      if (duration != null && duration.inSeconds > 10) {
        // Start crossfade 5 seconds before the end
        final crossfadeStart = duration.inMilliseconds - 5000;

        _crossfadeTimer?.cancel();
        _crossfadeTimer = Timer(
          Duration(milliseconds: crossfadeStart),
          () async {
            if (!_isPlaying) return;

            debugPrint('CanvasAudioService: Crossfading to $nextAsset');

            // Prepare next player
            await idlePlayer.setSource(AssetSource(nextAsset));
            await idlePlayer.setVolume(0.0);
            await idlePlayer.resume();

            // Smooth transition
            for (int i = 1; i <= 10; i++) {
              if (!_isPlaying) break;
              await activePlayer.setVolume(1.0 - (i / 10));
              await idlePlayer.setVolume(i / 10);
              await Future.delayed(const Duration(milliseconds: 500));
            }

            await activePlayer.stop();
            _currentIndex = nextIndex;
            _playNext();
          },
        );
      } else {
        debugPrint(
          'CanvasAudioService: Duration unknown, using completion listener',
        );
        activePlayer.onPlayerComplete.first.then((_) {
          if (_isPlaying) {
            _currentIndex = nextIndex;
            _playNext();
          }
        });
      }
    } catch (e) {
      debugPrint('CanvasAudioService error: $e');
      if (_isPlaying) {
        await Future.delayed(const Duration(seconds: 5));
        _currentIndex = nextIndex;
        _playNext();
      }
    }
  }

  void stop() {
    _isPlaying = false;
    _crossfadeTimer?.cancel();
    _player1.stop();
    _player2.stop();
    debugPrint('CanvasAudioService: Stopped ambient loop');
  }

  void dispose() {
    stop();
    _player1.dispose();
    _player2.dispose();
  }
}
