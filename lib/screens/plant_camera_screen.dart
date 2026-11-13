import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class PlantCameraScreen extends StatefulWidget {
  const PlantCameraScreen({super.key});

  @override
  State<PlantCameraScreen> createState() => _PlantCameraScreenState();
}

class _PlantCameraScreenState extends State<PlantCameraScreen> {
  CameraController? _controller;

  bool _isInitializing = true;
  bool _isTakingPicture = false;
  bool _flashEnabled = false;
  Color _guideColor = Colors.white;
  String _qualityMessage = 'Checking lighting...';
  IconData _qualityIcon = Icons.light_mode_outlined;

  int _frameCounter = 0;

  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        if (!mounted) return;

        setState(() {
          _isInitializing = false;
        });

        return;
      }

      await _startCamera(_selectedCameraIndex);
    } catch (e) {
      debugPrint('Camera initialization error: $e');

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _startCamera(int cameraIndex) async {
    await _controller?.dispose();

    final controller = CameraController(
      _cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await controller.initialize();

      await controller.setFlashMode(
        _flashEnabled ? FlashMode.auto : FlashMode.off,
      );

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _selectedCameraIndex = cameraIndex;
        _isInitializing = false;
      });
      await _startLightingCheck();
    } catch (e) {
      debugPrint('Camera start error: $e');
      await controller.dispose();

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _startLightingCheck() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isStreamingImages) {
      return;
    }

    try {
      await controller.startImageStream((CameraImage image) {
        _frameCounter++;

        // Only analyze every 12th frame.
        if (_frameCounter % 12 != 0) {
          return;
        }

        if (image.planes.isEmpty) {
          return;
        }

        final plane = image.planes.first;
        final bytes = plane.bytes;

        if (bytes.isEmpty) {
          return;
        }

        // ---------------------------------------------------------
        // BRIGHTNESS CHECK
        // ---------------------------------------------------------
        int totalBrightness = 0;
        int brightnessSamples = 0;

        for (int i = 0; i < bytes.length; i += 50) {
          totalBrightness += bytes[i];
          brightnessSamples++;
        }

        if (brightnessSamples == 0) {
          return;
        }

        final averageBrightness = totalBrightness / brightnessSamples;

        // ---------------------------------------------------------
        // SHARPNESS / DETAIL CHECK
        // ---------------------------------------------------------
        double totalDifference = 0;
        int differenceSamples = 0;

        const sampleGap = 20;

        for (int i = 0; i < bytes.length - sampleGap; i += 100) {
          final current = bytes[i].toInt();
          final nearby = bytes[i + sampleGap].toInt();

          totalDifference += (current - nearby).abs();

          differenceSamples++;
        }

        final sharpnessScore = differenceSamples == 0
            ? 0.0
            : totalDifference / differenceSamples;

        debugPrint(
          'Brightness: ${averageBrightness.toStringAsFixed(1)} '
          'Sharpness: ${sharpnessScore.toStringAsFixed(1)}',
        );

        Color newColor;
        String newMessage;
        IconData newIcon;

        // ---------------------------------------------------------
        // QUALITY RESULT
        // ---------------------------------------------------------
        if (averageBrightness < 70) {
          newColor = Colors.red;
          newMessage = 'Too dark — move to a brighter area';
          newIcon = Icons.brightness_low;
        } else if (averageBrightness > 210) {
          newColor = Colors.orange;
          newMessage = 'Too bright — avoid harsh light';
          newIcon = Icons.brightness_high;
        } else if (sharpnessScore < 8) {
          newColor = Colors.red;
          newMessage = 'Photo looks blurry — hold the camera steady';
          newIcon = Icons.blur_on;
        } else {
          newColor = Colors.green;
          newMessage = 'Photo looks good!';
          newIcon = Icons.check_circle_outline;
        }

        if (!mounted) {
          return;
        }

        setState(() {
          _guideColor = newColor;
          _qualityMessage = newMessage;
          _qualityIcon = newIcon;
        });
      });
    } catch (e) {
      debugPrint('Camera quality check error: $e');
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _isTakingPicture) {
      return;
    }

    setState(() {
      _isTakingPicture = true;
    });

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }

      final XFile image = await controller.takePicture();

      if (!mounted) return;

      Navigator.pop(context, image);
    } catch (e) {
      debugPrint('Take picture error: $e');

      if (mounted) {
        await _startLightingCheck();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not take picture. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;

    if (controller == null) return;

    final newValue = !_flashEnabled;

    try {
      await controller.setFlashMode(newValue ? FlashMode.auto : FlashMode.off);

      if (!mounted) return;

      setState(() {
        _flashEnabled = newValue;
      });
    } catch (e) {
      debugPrint('Flash error: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;

    setState(() {
      _isInitializing = true;
    });

    await _startCamera(nextIndex);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'Camera unavailable.',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ----------------------------------------------------------
            // CAMERA PREVIEW
            // ----------------------------------------------------------
            Center(child: CameraPreview(_controller!)),

            // ----------------------------------------------------------
            // DARK OVERLAY
            // ----------------------------------------------------------
            Container(color: Colors.black.withValues(alpha: 0.12)),

            // ----------------------------------------------------------
            // TOP BUTTONS
            // ----------------------------------------------------------
            Positioned(
              top: 12,
              left: 16,
              child: _CameraButton(
                icon: Icons.close,
                onTap: () => Navigator.pop(context),
              ),
            ),

            Positioned(
              top: 12,
              right: 16,
              child: _CameraButton(
                icon: _flashEnabled ? Icons.flash_auto : Icons.flash_off,
                onTap: _toggleFlash,
              ),
            ),

            // ----------------------------------------------------------
            // INSTRUCTIONS
            // ----------------------------------------------------------
            const Positioned(
              top: 75,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  Text(
                    'Center the plant inside the frame',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Keep the plant clear, well lit, and in focus.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                    ),
                  ),
                ],
              ),
            ),

            // ----------------------------------------------------------
            // PLANT FRAME
            // ----------------------------------------------------------
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.90,
                height: MediaQuery.of(context).size.width * 0.90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: _guideColor, width: 4),
                ),
              ),
            ),

            // ----------------------------------------------------------
            // PHOTO TIPS
            // ----------------------------------------------------------
            Positioned(
              left: 24,
              right: 24,
              bottom: 125,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_qualityIcon, color: _guideColor, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _qualityMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ----------------------------------------------------------
            // BOTTOM CAMERA CONTROLS
            // ----------------------------------------------------------
            Positioned(
              bottom: 25,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 56),

                  GestureDetector(
                    onTap: _isTakingPicture ? null : _takePicture,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 5),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF2F6B3F),
                          shape: BoxShape.circle,
                        ),
                        child: _isTakingPicture
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),

                  _CameraButton(
                    icon: Icons.cameraswitch_outlined,
                    onTap: _cameras.length > 1 ? _switchCamera : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CameraButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(icon, color: Colors.white, size: 27),
        ),
      ),
    );
  }
}
