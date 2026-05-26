import 'package:universal_io/io.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:oasis/core/utils/haptic_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:camera/camera.dart';

import 'package:oasis/services/stories_service.dart';
import 'package:oasis/widgets/stories/music_picker_sheet.dart';
import 'package:oasis/features/stories/domain/models/story_entity.dart';
import 'package:oasis/features/stories/presentation/providers/stories_provider.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final _storiesService = StoriesService();
  final _captionController = TextEditingController();
  final _imagePicker = ImagePicker();
  final GlobalKey _boundaryKey = GlobalKey();

  File? _selectedFile;
  String _mediaType = 'image';
  bool _isUploading = false;
  bool _isCaptionVisible = false;
  bool _isDrawingMode = false;
  bool _isFilterPickerVisible = false;
  StoryMusicEntity? _selectedMusic;
  Offset _musicPosition = const Offset(0.5, 0.5);

  // New Instagram Features State
  bool _shareToCloseFriends = false;
  int _storyDuration = 5;
  VideoPlayerController? _videoController;

  // Camera UI State
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isCameraAvailable = Platform.isAndroid || Platform.isIOS;
  bool _isFlashOn = false;
  bool _isFrontCamera = true;
  String _activeTool = 'none'; // 'create', 'boomerang', 'layout', 'handsfree'

  // Video Recording State
  bool _isRecordingVideo = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  // Hands-Free Countdown State
  int? _handsFreeCountdown;
  Timer? _countdownTimer;

  // Layout Mode State
  List<File?> _layoutImages = [null, null, null, null];
  final bool _isLayoutMode = false;
  final int _layoutStyle = 0; // 0: 2x2, 1: 2x1, 2: 1x2

  // Text Overlay State
  List<StoryText> _texts = [];
  int? _editingTextIndex;
  bool _isDraggingText = false;
  bool _isTextOverTrash = false;
  int _textBackgroundMode = 0;
  final TextAlign _textAlign = TextAlign.center;
  Color _textColor = Colors.white;
  int _selectedFontIndex = 0;

  // Font style options for text overlay
  final List<Map<String, dynamic>> _fontStyles = [
    {'name': 'Classic', 'fontFamily': null, 'fontWeight': FontWeight.bold},
    {'name': 'Modern', 'fontFamily': 'Roboto', 'fontWeight': FontWeight.w900},
    {
      'name': 'Typewriter',
      'fontFamily': 'Courier',
      'fontWeight': FontWeight.bold,
    },
    {
      'name': 'Neon',
      'fontFamily': null,
      'fontWeight': FontWeight.bold,
      'glow': true,
    },
    {
      'name': 'Strong',
      'fontFamily': 'Arial Black',
      'fontWeight': FontWeight.w900,
    },
  ];

  // Drawing State
  List<List<DrawingPoint>> _strokes = [];
  List<DrawingPoint> _currentStroke = [];
  Color _selectedColor = Colors.white;
  final double _strokeWidth = 5.0;
  bool _isEraserMode = false;

  // Canvas Mode State
  bool _isCanvasMode = false;
  int _canvasColorIndex = 0;
  final List<List<Color>> _canvasGradients = [
    [Colors.purple, Colors.orange],
    [Colors.blue, Colors.teal],
    [Colors.pink, Colors.redAccent],
    [Colors.black87, Colors.black],
    [Colors.indigo, Colors.deepPurple],
    [Colors.green, Colors.tealAccent],
  ];

  // Filter State
  int _selectedFilterIndex = 0;

  Future<bool?> _showDiscardDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isM3E = themeProvider.isM3EEnabled;
    final colorScheme = Theme.of(context).colorScheme;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isM3E ? colorScheme.surface : Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isM3E ? 24 : 16),
        ),
        title: Text(
          'Discard media?',
          style: TextStyle(color: isM3E ? colorScheme.onSurface : Colors.white),
        ),
        content: Text(
          'If you go back now, you will lose any changes you\'ve made.',
          style: TextStyle(
            color: isM3E ? colorScheme.onSurfaceVariant : Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isM3E ? colorScheme.onSurface : Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: Text(
              'Discard',
              style: TextStyle(
                color: isM3E ? colorScheme.error : Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  final List<Map<String, dynamic>> _filterPresets = [
    {
      'name': 'Normal',
      'matrix': <double>[
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ],
    },
    {
      'name': 'Clarendon',
      'matrix': <double>[
        1.2,
        0,
        0,
        0,
        0,
        0,
        1.1,
        0,
        0,
        0,
        0,
        0,
        1.5,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ],
    },
    {
      'name': 'Gingham',
      'matrix': <double>[
        0.9,
        0,
        0,
        0,
        0,
        0,
        0.9,
        0,
        0,
        0,
        0,
        0,
        0.9,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ],
    },
    {
      'name': 'Moon',
      'matrix': <double>[
        0.21,
        0.71,
        0.07,
        0,
        0,
        0.21,
        0.71,
        0.07,
        0,
        0,
        0.21,
        0.71,
        0.07,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ],
    },
    {
      'name': 'Lark',
      'matrix': <double>[
        1.1,
        0,
        0,
        0,
        0,
        0,
        1.1,
        0,
        0,
        0,
        0,
        0,
        1.3,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ],
    },
    {
      'name': 'Reyes',
      'matrix': <double>[
        1,
        0,
        0,
        0,
        50,
        0,
        1,
        0,
        0,
        50,
        0,
        0,
        1,
        0,
        20,
        0,
        0,
        0,
        1,
        0,
      ],
    },
    {
      'name': 'Juno',
      'matrix': <double>[
        1.1,
        0,
        0,
        0,
        0,
        0,
        1.3,
        0,
        0,
        0,
        0,
        0,
        1.1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    if (_isCameraAvailable) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _isCameraAvailable = false);
        return;
      }
      await _switchCamera();
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) setState(() => _isCameraAvailable = false);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.isEmpty) return;

    // Reset initialization state and clear the current controller reference
    // to prevent the UI from trying to render a disposed or transitioning controller.
    setState(() {
      _isCameraInitialized = false;
    });

    final oldController = _cameraController;
    _cameraController = null;

    if (oldController != null) {
      try {
        await oldController.dispose();
      } catch (e) {
        debugPrint('Error disposing old camera during switch: $e');
      }
    }

    final description = _isFrontCamera
        ? _cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => _cameras.first,
          )
        : _cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras.first,
          );

    final newController = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.jpeg,
    );

    try {
      await newController.initialize();

      if (!mounted) {
        await newController.dispose();
        return;
      }

      setState(() {
        _cameraController = newController;
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('Camera switch error: $e');
      try {
        await newController.dispose();
      } catch (disposeError) {
        debugPrint('Error disposing new camera after fail: $disposeError');
      }
      if (mounted) {
        setState(() {
          _isCameraAvailable = false;
          _isCameraInitialized = false;
        });
      }
    }
  }

  int get _nextLayoutSlot {
    for (int i = 0; i < _layoutImages.length; i++) {
      if (_layoutImages[i] == null) return i;
    }
    return -1;
  }

  Future<void> _capturePhoto() async {
    if (_activeTool == 'create') {
      setState(() {
        _isCanvasMode = true;
        _mediaType = 'image';
        _activeTool = 'none';
        _addNewText();
      });
      return;
    }

    if (_cameraController == null || !_isCameraInitialized) return;
    try {
      HapticUtils.mediumImpact();
      final xfile = await _cameraController!.takePicture();
      final file = File(xfile.path);

      if (_activeTool == 'layout') {
        final slot = _nextLayoutSlot;
        if (slot != -1) {
          setState(() {
            _layoutImages[slot] = file;
          });

          // Check if all slots are full
          bool allFull = true;
          int slotsNeeded = 4; // Default for 2x2
          if (_layoutStyle == 1 || _layoutStyle == 2) slotsNeeded = 2;

          for (int i = 0; i < slotsNeeded; i++) {
            if (_layoutImages[i] == null) {
              allFull = false;
              break;
            }
          }

          if (allFull) {
            // Move to edit mode with the composite
            _finishLayout();
          }
          return;
        }
      }

      setState(() {
        _selectedFile = file;
        _mediaType = 'image';
        _texts = [];
        _strokes = [];
        _currentStroke = [];
        _selectedFilterIndex = 0;
        _selectedMusic = null;
        _activeTool = 'none';
      });
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Capture failed: $e')));
      }
    }
  }

  Future<void> _finishLayout() async {
    setState(() => _isUploading = true);
    try {
      final composite = await _captureCompositeImage();
      if (composite != null) {
        setState(() {
          _selectedFile = composite;
          _mediaType = 'image';
          _texts = [];
          _strokes = [];
          _currentStroke = [];
          _selectedFilterIndex = 0;
          _selectedMusic = null;
          _activeTool = 'none';
          _layoutImages = [null, null, null, null];
        });
      }
    } catch (e) {
      debugPrint('Layout finish error: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Widget _buildLayoutSlot(int index) {
    final image = _layoutImages[index];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white38, width: 0.5),
      ),
      child: image != null
          ? Image.file(image, fit: BoxFit.cover)
          : const Center(
              child: Icon(Icons.add_rounded, color: Colors.white24, size: 32),
            ),
    );
  }

  Future<void> _startVideoRecording() async {
    if (_cameraController == null || !_isCameraInitialized) return;
    try {
      await _cameraController!.startVideoRecording();
      HapticUtils.mediumImpact();
      setState(() {
        _isRecordingVideo = true;
        _recordingSeconds = 0;
      });

      final bool isBoomerang = _activeTool == 'boomerang';
      final int maxSeconds = isBoomerang ? 2 : 30;

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _recordingSeconds++);
        if (_recordingSeconds >= maxSeconds) _stopVideoRecording();
      });
    } catch (e) {
      debugPrint('Video record start error: $e');
    }
  }

  Future<void> _stopVideoRecording() async {
    _recordingTimer?.cancel();
    if (_cameraController == null || !_isRecordingVideo) return;
    try {
      final xfile = await _cameraController!.stopVideoRecording();
      HapticUtils.mediumImpact();
      final videoFile = File(xfile.path);

      _videoController?.dispose();
      _videoController = VideoPlayerController.file(videoFile)
        ..initialize().then((_) {
          _videoController!.setLooping(true);
          _videoController!.play();
          if (mounted) setState(() {});
        });

      setState(() {
        _isRecordingVideo = false;
        _recordingSeconds = 0;
        _selectedFile = videoFile;
        _mediaType = 'video';
        _texts = [];
        _strokes = [];
        _currentStroke = [];
        _selectedFilterIndex = 0;
        _selectedMusic = null;
        _activeTool = 'none';
      });
    } catch (e) {
      setState(() => _isRecordingVideo = false);
      debugPrint('Video record stop error: $e');
    }
  }

  void _startHandsFreeCountdown() {
    setState(() {
      _handsFreeCountdown = 3;
    });
    HapticUtils.selectionClick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = (_handsFreeCountdown ?? 0) - 1;
      if (next <= 0) {
        t.cancel();
        setState(() => _handsFreeCountdown = null);
        _startVideoRecording();
      } else {
        setState(() => _handsFreeCountdown = next);
        HapticUtils.selectionClick();
      }
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _countdownTimer?.cancel();

    // Safety for CameraX disposal issues
    final controller = _cameraController;
    _cameraController = null;
    _isCameraInitialized = false;

    if (controller != null) {
      controller.dispose().catchError((e) {
        if (e is PlatformException && e.code == 'IllegalStateException') {
          debugPrint(
            'Suppressed known CameraX release error during dispose: $e',
          );
        } else {
          debugPrint('Camera dispose error: $e');
        }
      });
    }

    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<File?> _captureCompositeImage() async {
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/composite_story_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file;
    } catch (e) {
      debugPrint('Error capturing composite image: $e');
      return null;
    }
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    try {
      XFile? file;
      if (isVideo) {
        file = await _imagePicker.pickVideo(
          source: source,
          maxDuration: const Duration(seconds: 30),
        );
      } else {
        file = await _imagePicker.pickImage(
          source: source,
          maxWidth: 1440,
          maxHeight: 2560,
          imageQuality: 90,
        );
      }

      if (file != null) {
        final pickedFile = File(file.path);

        if (isVideo) {
          _videoController?.dispose();
          _videoController = VideoPlayerController.file(pickedFile)
            ..initialize().then((_) {
              _videoController!.setLooping(true);
              _videoController!.play();
              if (mounted) setState(() {});
            });
        }

        setState(() {
          _selectedFile = pickedFile;
          _mediaType = isVideo ? 'video' : 'image';
          _texts = [];
          _strokes = [];
          _currentStroke = [];
          _selectedFilterIndex = 0;
          _selectedMusic = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _undoDrawing() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
    }
  }

  Future<void> _saveToGallery() async {
    if (_selectedFile == null) return;
    setState(() => _isUploading = true);
    try {
      final composite = await _captureCompositeImage();
      if (composite != null) {
        await Gal.putImage(composite.path);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Saved to gallery!')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _createStory() async {
    if (_selectedFile == null && !_isCanvasMode) return;
    setState(() => _isUploading = true);

    try {
      final File finalFile;
      if (_mediaType == 'video' && _selectedFile != null) {
        finalFile = _selectedFile!;
      } else {
        final composite = await _captureCompositeImage();
        if (composite == null) throw Exception('Failed to generate image');
        finalFile = composite;
      }

      // Prepare interactive metadata for text layers
      final interactiveMetadata = _texts
          .map(
            (t) => {
              'type': 'text',
              'data': {
                'text': t.text,
                'color': '#${t.color.toARGB32().toRadixString(16)}',
                'background_mode': t.backgroundMode,
              },
              'x': t.position.dx / MediaQuery.of(context).size.width,
              'y': t.position.dy / MediaQuery.of(context).size.height,
            },
          )
          .toList();

      interactiveMetadata.add({
        'type': 'story_settings',
        'data': {},
        'x': 0,
        'y': 0,
      });

      // Use the original StoriesService to handle actual file upload
      final story = await _storiesService.createStory(
        file: finalFile,
        mediaType: _mediaType,
        musicId: _selectedMusic?.trackId,
        musicMetadata: _selectedMusic != null
            ? {
                ..._selectedMusic!.toJson(),
                'music_position': {
                  'x': _musicPosition.dx,
                  'y': _musicPosition.dy,
                },
              }
            : null,
        interactiveMetadata: interactiveMetadata,
      );

      if (story != null && mounted) {
        // Refresh stories via provider
        await context.read<StoriesProvider>().loadMyStories();
        if (!mounted) return;
        context.pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story shared!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _addNewText() {
    setState(() {
      _captionController.clear();
      _editingTextIndex = null;
      _isCaptionVisible = true;
      _textColor = Colors.white;
      _textBackgroundMode = 0;
      _selectedFontIndex = 0;
    });
  }

  void _finishTextEditing() {
    if (_captionController.text.trim().isEmpty) {
      if (_editingTextIndex != null) {
        setState(() => _texts.removeAt(_editingTextIndex!));
      }
      setState(() {
        _isCaptionVisible = false;
        _editingTextIndex = null;
      });
      return;
    }

    setState(() {
      final newText = StoryText(
        text: _captionController.text.trim(),
        position: _editingTextIndex != null
            ? _texts[_editingTextIndex!].position
            : Offset(
                MediaQuery.of(context).size.width / 2,
                MediaQuery.of(context).size.height / 2.5,
              ),
        color: _textColor,
        backgroundMode: _textBackgroundMode,
        fontIndex: _selectedFontIndex,
        align: _textAlign,
      );

      if (_editingTextIndex != null) {
        _texts[_editingTextIndex!] = newText;
      } else {
        _texts.add(newText);
      }

      _isCaptionVisible = false;
      _editingTextIndex = null;
    });
  }

  void _openMusicPicker() async {
    final StoryMusicEntity? result =
        await showModalBottomSheet<StoryMusicEntity>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const MusicPickerSheet(),
        );

    if (result != null) {
      setState(() {
        _selectedMusic = result;
      });
      HapticUtils.success();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    debugPrint('=== CreateStoryScreen build ===');
    debugPrint('_selectedFile: $_selectedFile');
    debugPrint('isM3E: $isM3E');
    final colorScheme = Theme.of(context).colorScheme;

    debugPrint(
      'Returning Scaffold with body Stack, children count: ${_selectedFile == null ? 4 : 6}',
    );
    debugPrint('Will show empty state: ${_selectedFile == null}');

    // Adaptive layout: use LayoutBuilder for responsive design
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // Responsive breakpoints (Material 3 adaptive guidelines)
        final isTablet = screenWidth > 600;
        final isDesktop = screenWidth > 900;

        // Adaptive sizes based on screen size
        final double adaptiveIconSize = isDesktop ? 36 : (isTablet ? 32 : 24);
        final double adaptiveButtonSize = isDesktop ? 56 : (isTablet ? 52 : 48);
        final double adaptivePadding = isDesktop ? 24 : (isTablet ? 20 : 16);

        // M3E conditional icon helper - use rounded when M3E enabled, standard otherwise
        IconData getIcon(IconData rounded, IconData standard) =>
            isM3E ? rounded : standard;

        return PopScope(
          canPop: !(_selectedFile != null || _isCanvasMode),
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;

            if (_isDrawingMode) {
              setState(() => _isDrawingMode = false);
            } else if (_isFilterPickerVisible) {
              setState(() => _isFilterPickerVisible = false);
            } else if (_isCaptionVisible) {
              _finishTextEditing();
            } else {
              final discard = await _showDiscardDialog();
              if (discard == true) {
                setState(() {
                  _selectedFile = null;
                  _isCanvasMode = false;
                  _texts.clear();
                  _strokes.clear();
                  _videoController?.pause();
                });
              }
            }
          },
          child: Scaffold(
            backgroundColor: isM3E ? colorScheme.surface : Colors.black,
            resizeToAvoidBottomInset: false,
            body: Stack(
              children: [
                // ── Composite Area (Captured via RepaintBoundary) ──
                RepaintBoundary(
                  key: _boundaryKey,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: isM3E ? colorScheme.surface : Colors.black,
                    child: Stack(
                      children: [
                        if (_selectedFile != null || _isCanvasMode) ...[
                          Positioned.fill(
                            child: _isCanvasMode
                                ? Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors:
                                            _canvasGradients[_canvasColorIndex],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                  )
                                : ColorFiltered(
                                    colorFilter: ui.ColorFilter.matrix(
                                      _filterPresets[_selectedFilterIndex]['matrix'],
                                    ),
                                    child:
                                        _mediaType == 'video' &&
                                            _videoController != null &&
                                            _videoController!
                                                .value
                                                .isInitialized
                                        ? FittedBox(
                                            fit: BoxFit.cover,
                                            child: SizedBox(
                                              width: _videoController!
                                                  .value
                                                  .size
                                                  .width,
                                              height: _videoController!
                                                  .value
                                                  .size
                                                  .height,
                                              child: VideoPlayer(
                                                _videoController!,
                                              ),
                                            ),
                                          )
                                        : Image.file(
                                            _selectedFile!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              debugPrint(
                                                'Error loading story image: $error',
                                              );
                                              return Container(
                                                color: Colors.black,
                                                child: Center(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .broken_image_outlined,
                                                        size: 64,
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                      ),
                                                      const SizedBox(
                                                        height: 16,
                                                      ),
                                                      Text(
                                                        'Failed to load image',
                                                        style: TextStyle(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.7,
                                                              ),
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      TextButton.icon(
                                                        onPressed: () {
                                                          setState(
                                                            () =>
                                                                _selectedFile =
                                                                    null,
                                                          );
                                                        },
                                                        icon: const Icon(
                                                          Icons.refresh,
                                                          color: Colors.white,
                                                        ),
                                                        label: const Text(
                                                          'Choose different',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                          ),

                          // Music Sticker (Draggable)
                          if (_selectedMusic != null)
                            Positioned(
                              left:
                                  _musicPosition.dx *
                                      MediaQuery.of(context).size.width -
                                  60,
                              top:
                                  _musicPosition.dy *
                                      MediaQuery.of(context).size.height -
                                  30,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedMusic = null),
                                onPanStart: (_) {
                                  HapticFeedback.selectionClick();
                                },
                                onPanUpdate: (details) {
                                  setState(() {
                                    final screenWidth = MediaQuery.of(
                                      context,
                                    ).size.width;
                                    final screenHeight = MediaQuery.of(
                                      context,
                                    ).size.height;
                                    _musicPosition = Offset(
                                      (_musicPosition.dx +
                                              details.delta.dx / screenWidth)
                                          .clamp(0.1, 0.9),
                                      (_musicPosition.dy +
                                              details.delta.dy / screenHeight)
                                          .clamp(0.1, 0.9),
                                    );
                                  });
                                },
                                onPanEnd: (_) {
                                  HapticFeedback.lightImpact();
                                },
                                child: _buildMusicStickerWidget(
                                  _selectedMusic!,
                                ),
                              ),
                            ),

                          Positioned.fill(
                            child: CustomPaint(
                              painter: DrawingPainter(
                                strokes: _strokes,
                                currentStroke: _currentStroke,
                              ),
                              size: Size.infinite,
                            ),
                          ),
                          ..._texts.asMap().entries.map((entry) {
                            final i = entry.key;
                            final t = entry.value;
                            final themeProvider = Provider.of<ThemeProvider>(
                              context,
                              listen: false,
                            );
                            final isM3E = themeProvider.isM3EEnabled;
                            return Positioned(
                              left: t.position.dx - 100,
                              top: t.position.dy - 25,
                              child: GestureDetector(
                                onTap: () {
                                  if (_isDraggingText) return;
                                  setState(() {
                                    _editingTextIndex = i;
                                    _captionController.text = t.text;
                                    _textColor = t.color;
                                    _textBackgroundMode = t.backgroundMode;
                                    _selectedFontIndex = t.fontIndex;
                                    _isCaptionVisible = true;
                                  });
                                },
                                onPanStart: (_) {
                                  setState(() => _isDraggingText = true);
                                  HapticFeedback.selectionClick();
                                },
                                onPanUpdate: (details) {
                                  setState(() {
                                    t.position += details.delta;
                                    final screenWidth = MediaQuery.of(
                                      context,
                                    ).size.width;
                                    final screenHeight = MediaQuery.of(
                                      context,
                                    ).size.height;
                                    final trashPos = Offset(
                                      screenWidth / 2,
                                      screenHeight - 100,
                                    );
                                    final distance =
                                        (t.position - trashPos).distance;
                                    if (distance < 120 && !_isTextOverTrash) {
                                      _isTextOverTrash = true;
                                      HapticFeedback.mediumImpact();
                                    } else if (distance >= 120 &&
                                        _isTextOverTrash) {
                                      _isTextOverTrash = false;
                                    }
                                  });
                                },
                                onPanEnd: (_) {
                                  if (_isTextOverTrash) {
                                    setState(() {
                                      _texts.removeAt(i);
                                    });
                                    HapticFeedback.heavyImpact();
                                  }
                                  setState(() {
                                    _isDraggingText = false;
                                    _isTextOverTrash = false;
                                  });
                                },
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 100),
                                  scale: _isDraggingText && _isTextOverTrash
                                      ? 0.5
                                      : 1.0,
                                  child: Opacity(
                                    opacity: _isDraggingText && _isTextOverTrash
                                        ? 0.5
                                        : 1.0,
                                    child: Container(
                                      width: 200,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: t.backgroundMode == 1
                                            ? t.color.withValues(alpha: 0.9)
                                            : (t.backgroundMode == 2
                                                  ? Colors.black54
                                                  : Colors.transparent),
                                        borderRadius: BorderRadius.circular(
                                          isM3E ? 16 : 8,
                                        ),
                                      ),
                                      child: Text(
                                        t.text,
                                        textAlign: t.align,
                                        style: TextStyle(
                                          color: t.backgroundMode == 1
                                              ? (t.color.computeLuminance() >
                                                        0.5
                                                    ? Colors.black
                                                    : Colors.white)
                                              : t.color,
                                          fontSize: 28,
                                          fontWeight: isM3E
                                              ? FontWeight.w900
                                              : FontWeight.bold,
                                          letterSpacing: isM3E ? -0.5 : 0,
                                          fontFamily:
                                              _fontStyles[t
                                                      .fontIndex]['fontFamily']
                                                  as String?,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ] else
                          _buildEmptyState(),
                      ],
                    ),
                  ),
                ),

                // ── Drawing INTERACTION Layer ──
                if (_selectedFile != null && _isDrawingMode)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) {
                        setState(() {
                          _currentStroke = [
                            DrawingPoint(
                              details.localPosition,
                              Paint()
                                ..color = _isEraserMode
                                    ? Colors.transparent
                                    : _selectedColor
                                ..strokeWidth = _isEraserMode
                                    ? 30.0
                                    : _strokeWidth
                                ..strokeCap = StrokeCap.round
                                ..blendMode = _isEraserMode
                                    ? BlendMode.clear
                                    : BlendMode.srcOver
                                ..style = PaintingStyle.stroke
                                ..isAntiAlias = true,
                            ),
                          ];
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          _currentStroke.add(
                            DrawingPoint(
                              details.localPosition,
                              Paint()
                                ..color = _isEraserMode
                                    ? Colors.transparent
                                    : _selectedColor
                                ..strokeWidth = _isEraserMode
                                    ? 30.0
                                    : _strokeWidth
                                ..strokeCap = StrokeCap.round
                                ..blendMode = _isEraserMode
                                    ? BlendMode.clear
                                    : BlendMode.srcOver
                                ..style = PaintingStyle.stroke
                                ..isAntiAlias = true,
                            ),
                          );
                        });
                      },
                      onPanEnd: (details) {
                        setState(() {
                          _strokes.add(List.from(_currentStroke));
                          _currentStroke = [];
                        });
                      },
                    ),
                  ),

                // ── UI Overlays ──
                if (_selectedFile != null) ...[
                  _buildCinematicGradients(),
                  if (_isDraggingText)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: 0.4,
                          duration: const Duration(milliseconds: 200),
                          child: Container(color: Colors.black),
                        ),
                      ),
                    ),
                  if (!_isCaptionVisible &&
                      !_isDrawingMode &&
                      !_isFilterPickerVisible &&
                      !_isDraggingText)
                    _buildSideToolbar(),
                  _buildTopToolbar(),
                  if (_isFilterPickerVisible) _buildFilterPicker(),
                  if (_isCaptionVisible) _buildTextEditor(),
                  if (!_isCaptionVisible && !_isDrawingMode && !_isDraggingText)
                    _buildBottomActionBar(),
                  if (_isDrawingMode) _buildDrawingTools(),
                  _buildTrashArea(),
                ],

                // Close button now integrated into empty state layout
              ],
            ),
          ),
        );
      }, // End LayoutBuilder
    );
  }

  Widget _buildTrashArea() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.all(_isTextOverTrash ? 25 : 18),
                decoration: BoxDecoration(
                  color: _isTextOverTrash
                      ? Colors.red.withValues(alpha: 0.9)
                      : Colors.black45,
                  shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: isM3E ? BorderRadius.circular(24) : null,
                  border: Border.all(
                    color: _isTextOverTrash ? Colors.white : Colors.white38,
                    width: 2,
                  ),
                  boxShadow: [
                    if (_isTextOverTrash)
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                  ],
                ),
                child: Icon(
                  _isTextOverTrash
                      ? Icons.delete_forever_rounded
                      : Icons.delete_outline_rounded,
                  color: Colors.white,
                  size: _isTextOverTrash ? 36 : 30,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedOpacity(
                opacity: _isTextOverTrash ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Text(
                  'Remove',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: isM3E ? FontWeight.w900 : FontWeight.bold,
                    letterSpacing: isM3E ? -0.5 : 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return _buildCameraInterface();
  }

  Widget _buildCameraInterface() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview Layer
          if (_isCameraAvailable &&
              _isCameraInitialized &&
              _cameraController != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isM3E ? 24 : 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.biggest;
                    // For portrait, the camera preview aspect ratio is height/width (e.g., 1.77)
                    // We need to scale it to cover the screen
                    var scale =
                        1 /
                        (_cameraController!.value.aspectRatio *
                            size.aspectRatio);
                    if (scale < 1) scale = 1 / scale;

                    return Transform.scale(
                      scale: scale,
                      child: Center(child: CameraPreview(_cameraController!)),
                    );
                  },
                ),
              ),
            )
          else if (!_isCameraAvailable)
            // Empty state for Windows / Desktop
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      size: 64,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select an image to start',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                        fontWeight: isM3E ? FontWeight.w600 : FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 2. Mode-Specific Overlays
          if (_activeTool == 'create')
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.purple.withValues(alpha: 0.8),
                      Colors.orange.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Tap to type',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          if (_activeTool == 'layout')
            Positioned.fill(
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: _buildLayoutSlot(0)),
                            Expanded(child: _buildLayoutSlot(1)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: _buildLayoutSlot(2)),
                            Expanded(child: _buildLayoutSlot(3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Clear Layout button
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 80,
                    right: 16,
                    child: _buildBlurButton(
                      icon: Icons.refresh_rounded,
                      onTap: () {
                        setState(() {
                          _layoutImages = [null, null, null, null];
                        });
                        HapticUtils.mediumImpact();
                      },
                    ),
                  ),
                ],
              ),
            ),

          if (_activeTool == 'handsfree' && _handsFreeCountdown != null)
            Positioned.fill(
              child: Center(
                child: Text(
                  '$_handsFreeCountdown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 20)],
                  ),
                ),
              ),
            ),

          if (_activeTool == 'boomerang')
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.all_inclusive_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Boomerang',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 3. Camera Sidebar (Instagram Tools)
          Positioned(
            left: 16,
            top: MediaQuery.of(context).size.height * 0.15,
            child: Column(
              children: [
                _buildCameraSideTool(
                  icon: Icons.text_fields_rounded,
                  label: 'Create',
                  isActive: _activeTool == 'create',
                  onTap: () {
                    setState(
                      () => _activeTool = _activeTool == 'create'
                          ? 'none'
                          : 'create',
                    );
                  },
                  isM3E: isM3E,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 20),
                if (_isCameraAvailable) ...[
                  _buildCameraSideTool(
                    icon: Icons.all_inclusive_rounded,
                    label: 'Boomerang',
                    isActive: _activeTool == 'boomerang',
                    onTap: () {
                      setState(
                        () => _activeTool = _activeTool == 'boomerang'
                            ? 'none'
                            : 'boomerang',
                      );
                    },
                    isM3E: isM3E,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 20),
                  _buildCameraSideTool(
                    icon: Icons.grid_view_rounded,
                    label: 'Layout',
                    isActive: _activeTool == 'layout',
                    onTap: () {
                      setState(
                        () => _activeTool = _activeTool == 'layout'
                            ? 'none'
                            : 'layout',
                      );
                    },
                    isM3E: isM3E,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 20),
                  _buildCameraSideTool(
                    icon: Icons.timer_outlined,
                    label: 'Hands-free',
                    isActive: _activeTool == 'handsfree',
                    onTap: () {
                      setState(
                        () => _activeTool = _activeTool == 'handsfree'
                            ? 'none'
                            : 'handsfree',
                      );
                    },
                    isM3E: isM3E,
                    colorScheme: colorScheme,
                  ),
                ],
              ],
            ),
          ),

          // 4. Top Controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {},
                  ),
                  const Spacer(),
                  if (_isCameraAvailable)
                    IconButton(
                      icon: Icon(
                        _isFlashOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () async {
                        if (_cameraController == null) return;
                        final newMode = _isFlashOn
                            ? FlashMode.off
                            : FlashMode.torch;
                        await _cameraController!.setFlashMode(newMode);
                        setState(() => _isFlashOn = !_isFlashOn);
                      },
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
          ),

          // 5. Bottom Controls (Gallery, Shutter, Flip)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery Picker
                GestureDetector(
                  onTap: () => _pickMedia(ImageSource.gallery),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      // Fake gallery thumbnail for preview
                      image: const DecorationImage(
                        image: CachedNetworkImageProvider(
                          'https://picsum.photos/100',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                // Shutter Button
                if (_isCameraAvailable || _activeTool == 'create')
                  GestureDetector(
                    onTap: () {
                      if (_activeTool == 'handsfree') {
                        _startHandsFreeCountdown();
                      } else {
                        _capturePhoto();
                      }
                    },
                    onLongPress:
                        (_activeTool == 'create' || _activeTool == 'layout')
                        ? null
                        : _startVideoRecording,
                    onLongPressUp: _isRecordingVideo
                        ? _stopVideoRecording
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isRecordingVideo ? 100 : 80,
                      height: _isRecordingVideo ? 100 : 80,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isRecordingVideo ? Colors.red : Colors.white,
                          width: _isRecordingVideo ? 8 : 4,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isRecordingVideo ? Colors.red : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: _isRecordingVideo
                            ? Center(
                                child: Text(
                                  '$_recordingSeconds',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 80),

                // Flip Camera
                if (_isCameraAvailable)
                  IconButton(
                    icon: const Icon(
                      Icons.flip_camera_ios_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () {
                      HapticUtils.lightImpact();
                      setState(() => _isFrontCamera = !_isFrontCamera);
                      _switchCamera();
                    },
                  )
                else
                  const SizedBox(width: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSideTool({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
    required bool isM3E,
    required ColorScheme colorScheme,
  }) {
    if (isM3E) {
      // M3 Expressive: High-energy pill shapes with active states
      return GestureDetector(
        onTap: () {
          HapticUtils.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
                size: 26,
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w900, // Extra bold for M3E
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Classic Tool Style
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          _buildBlurButton(icon: icon, onTap: onTap),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextEditor() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        child: Column(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildBlurButton(
                      icon: Icons.align_horizontal_left_rounded,
                      onTap: () {},
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(
                        () =>
                            _textBackgroundMode = (_textBackgroundMode + 1) % 3,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _textBackgroundMode > 0
                              ? Colors.white
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(isM3E ? 12 : 8),
                        ),
                        child: Icon(
                          Icons.format_color_text_rounded,
                          color: _textBackgroundMode > 0
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: _finishTextEditing,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        textStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: isM3E ? FontWeight.w500 : FontWeight.bold,
                          letterSpacing: isM3E ? 0.1 : 0,
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: TextField(
                  controller: _captionController,
                  autofocus: true,
                  textAlign: _textAlign,
                  maxLines: null,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 36,
                    fontWeight: isM3E ? FontWeight.w900 : FontWeight.bold,
                    letterSpacing: isM3E ? -1.0 : 0,
                    backgroundColor: _textBackgroundMode == 1
                        ? Colors.white
                        : (_textBackgroundMode == 2 ? Colors.black54 : null),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Type...',
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                ),
              ),
            ),
            _buildColorPicker(),
            _buildFontStylePicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    return Container(
      height: 60,
      margin: const EdgeInsets.only(bottom: 40),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: Colors.primaries.length,
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => setState(() => _textColor = Colors.primaries[index]),
          child: Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: Colors.primaries[index],
              shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isM3E ? BorderRadius.circular(8) : null,
              border: Border.all(
                color: _textColor == Colors.primaries[index]
                    ? Colors.white
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFontStylePicker() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _fontStyles.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedFontIndex == index;
          final fontStyle = _fontStyles[index];
          return GestureDetector(
            onTap: () => setState(() => _selectedFontIndex = index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.white12,
                borderRadius: BorderRadius.circular(isM3E ? 16 : 12),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                fontStyle['name'] as String,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontSize: 13,
                  fontWeight: fontStyle['fontWeight'] as FontWeight,
                  fontFamily: fontStyle['fontFamily'] as String?,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterPicker() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filterPresets.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedFilterIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilterIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 15),
                    child: Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              isM3E
                                  ? 16
                                  : 12, // M3E Large (16dp) vs M3 Medium (12dp)
                            ),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ColorFiltered(
                            colorFilter: ui.ColorFilter.matrix(
                              _filterPresets[index]['matrix'],
                            ),
                            child: Image.file(
                              _selectedFile!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.white54,
                                      size: 32,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _filterPresets[index]['name'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white60,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? (isM3E
                                      ? FontWeight
                                            .w600 // M3E uses Medium (500-600)
                                      : FontWeight.bold)
                                : FontWeight.normal,
                            letterSpacing: isM3E
                                ? -0.5
                                : 0, // M3E tighter spacing
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => setState(() => _isFilterPickerVisible = false),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms).moveY(begin: 10, end: 0),
    );
  }

  Widget _buildSideToolbar() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).size.height * 0.25,
      child: Column(
        children: [
          _buildSideTool(
            icon: Icons.text_fields_rounded,
            label: 'Aa',
            onTap: _addNewText,
          ),
          const SizedBox(height: 24),
          _buildSideTool(
            icon: Icons.sticky_note_2_rounded,
            label: 'Stickers',
            onTap: () {},
          ),
          const SizedBox(height: 24),
          _buildSideTool(
            icon: Icons.gesture_rounded,
            label: 'Draw',
            onTap: () => setState(() => _isDrawingMode = true),
          ),
          const SizedBox(height: 24),
          _buildSideTool(
            icon: Icons.auto_awesome_rounded,
            label: 'Filters',
            onTap: () => setState(() => _isFilterPickerVisible = true),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildBlurButton(icon: Icons.download_rounded, onTap: _saveToGallery),
          if (isM3E) ...[
            const SizedBox(width: 12),
            _buildBlurButton(
              icon: _shareToCloseFriends
                  ? Icons.stars_rounded
                  : Icons.star_border_rounded,
              onTap: () =>
                  setState(() => _shareToCloseFriends = !_shareToCloseFriends),
            ),
          ],
          const Spacer(),
          if (isM3E)
            _buildCircleActionButton(
              icon: _isUploading ? Icons.hourglass_empty : Icons.send_rounded,
              label: _shareToCloseFriends ? 'Close Friends' : 'Share',
              onTap: _isUploading ? () {} : _createStory,
            )
          else
            _buildCircleActionButton(
              icon: _isUploading
                  ? Icons.hourglass_empty
                  : Icons.chevron_right_rounded,
              onTap: _isUploading ? () {} : _createStory,
            ),
        ],
      ),
    );
  }

  Widget _buildTopToolbar() {
    final isM3E = Provider.of<ThemeProvider>(context).isM3EEnabled;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildBlurButton(
              icon: Icons.close_rounded,
              onTap: () async {
                if (_isDrawingMode) {
                  setState(() => _isDrawingMode = false);
                } else if (_isFilterPickerVisible) {
                  setState(() => _isFilterPickerVisible = false);
                } else {
                  final discard = await _showDiscardDialog();
                  if (discard == true) {
                    setState(() {
                      _selectedFile = null;
                      _isCanvasMode = false;
                      _texts.clear();
                      _strokes.clear();
                      _videoController?.pause();
                    });
                  }
                }
              },
            ),
            if (!_isCaptionVisible && !_isDrawingMode) ...[
              const Spacer(),
              if (_isCanvasMode) ...[
                _buildBlurButton(
                  icon: Icons.color_lens_rounded,
                  onTap: () {
                    setState(() {
                      _canvasColorIndex =
                          (_canvasColorIndex + 1) % _canvasGradients.length;
                    });
                    HapticUtils.lightImpact();
                  },
                ),
                const SizedBox(width: 8),
              ],
              if (isM3E)
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_storyDuration == 5) {
                        _storyDuration = 7;
                      } else if (_storyDuration == 7) {
                        _storyDuration = 10;
                      } else if (_storyDuration == 10) {
                        _storyDuration = 15;
                      } else {
                        _storyDuration = 5;
                      }
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black26,
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    '${_storyDuration}s',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(width: 8),
              _buildBlurButton(
                icon: Icons.music_note_rounded,
                onTap: _openMusicPicker,
              ),
              const SizedBox(width: 12),
              _buildBlurButton(
                icon: Icons.face_retouching_natural_rounded,
                onTap: () {},
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDrawingTools() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isM3E = themeProvider.isM3EEnabled;
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBlurButton(icon: Icons.undo_rounded, onTap: _undoDrawing),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => setState(() => _isEraserMode = !_isEraserMode),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isEraserMode ? Colors.white : Colors.white10,
                      borderRadius: BorderRadius.circular(isM3E ? 12 : 20),
                    ),
                    child: Icon(
                      _isEraserMode
                          ? Icons.auto_fix_high_rounded
                          : Icons.auto_fix_off_rounded,
                      color: _isEraserMode ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildColorPickerForDrawing(),
          const SizedBox(height: 20),
          _buildCircleActionButton(
            icon: Icons.check_rounded,
            onTap: () => setState(() => _isDrawingMode = false),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPickerForDrawing() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: Colors.primaries.length,
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => setState(() {
            _selectedColor = Colors.primaries[index];
            _isEraserMode = false;
          }),
          child: Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: Colors.primaries[index],
              shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isM3E ? BorderRadius.circular(8) : null,
              border: Border.all(
                color:
                    _selectedColor == Colors.primaries[index] && !_isEraserMode
                    ? Colors.white
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCinematicGradients() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black54,
                Colors.transparent,
                Colors.transparent,
                Colors.black54,
              ],
              stops: [0.0, 0.15, 0.85, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernPickerItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isM3E = false,
  }) {
    if (isM3E) {
      return Card.filled(
        color: color.withValues(alpha: 0.15),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 100,
            height: 100,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 36),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final colorScheme = Theme.of(context).colorScheme;

    if (isM3E) {
      // M3 Expressive: Bold, high-contrast pill/rounded-square with primary container tint
      return Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20), // Expressive Large Rounded
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: colorScheme.onPrimaryContainer, size: 22),
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      );
    }

    // Non-M3E: classic blurred circle button, height strictly constrained
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                alignment: Alignment.center,
                color: Colors.white10,
                child: Icon(icon, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideTool({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final colorScheme = Theme.of(context).colorScheme;

    if (isM3E) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GestureDetector(
          onTap: () {
            HapticUtils.lightImpact();
            onTap();
          },
          child: Column(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildBlurButton(icon: icon, onTap: onTap),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required VoidCallback onTap,
    String? label,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;

    if (isM3E) {
      if (label != null) {
        return FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 24),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
        );
      }
      return FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.all(16),
          minimumSize: const Size(56, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Icon(icon, size: 24),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.black, size: 24),
      ),
    );
  }

  Widget _buildMusicStickerWidget(StoryMusicEntity music) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    return Center(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMusic = null),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              isM3E ? 16 : 12,
            ), // M3E Large (16dp) vs old
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  isM3E ? 8 : 4,
                ), // M3E Small (8dp)
                child: CachedNetworkImage(
                  imageUrl: music.albumArtUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    music.title,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: isM3E
                          ? FontWeight.w600
                          : FontWeight.bold, // M3E Medium
                      letterSpacing: isM3E ? -0.5 : 0,
                    ),
                  ),
                  Text(
                    music.artist,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: isM3E
                          ? FontWeight.w400
                          : FontWeight.normal, // M3E body weight
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              const Icon(Icons.music_note, color: Colors.black),
            ],
          ),
        ),
      ),
    );
  }
}

class StoryText {
  String text;
  Offset position;
  Color color;
  int backgroundMode;
  int fontIndex;
  TextAlign align;
  StoryText({
    required this.text,
    required this.position,
    this.color = Colors.white,
    this.backgroundMode = 0,
    this.fontIndex = 0,
    this.align = TextAlign.center,
  });
}

class DrawingPoint {
  Offset point;
  Paint areaPaint;
  DrawingPoint(this.point, this.areaPaint);
}

class DrawingPainter extends CustomPainter {
  final List<List<DrawingPoint>> strokes;
  final List<DrawingPoint> currentStroke;
  DrawingPainter({required this.strokes, required this.currentStroke});
  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }
    _drawStroke(canvas, currentStroke);
    canvas.restore();
  }

  void _drawStroke(ui.Canvas canvas, List<DrawingPoint> stroke) {
    if (stroke.isEmpty) return;
    if (stroke.length == 1) {
      canvas.drawCircle(
        stroke[0].point,
        stroke[0].areaPaint.strokeWidth / 2,
        stroke[0].areaPaint,
      );
      return;
    }
    final path = ui.Path();
    path.moveTo(stroke[0].point.dx, stroke[0].point.dy);
    for (int i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].point.dx, stroke[i].point.dy);
    }
    canvas.drawPath(path, stroke[0].areaPaint);
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}
