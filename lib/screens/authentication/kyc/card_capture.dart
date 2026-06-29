import 'dart:io';

import 'package:Electrony/theming/style.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class CardCaptureScreen extends StatefulWidget {
  final String cardType;
  final int sides;
  final CameraDescription camera;

  const CardCaptureScreen({
    super.key,
    required this.cardType,
    required this.sides,
    required this.camera,
  });

  @override
  _CardCaptureScreenState createState() => _CardCaptureScreenState();
}

class _CardCaptureScreenState extends State<CardCaptureScreen>
    with WidgetsBindingObserver {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final ImageLabeler _imageLabeler =
      ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.85));
  int currentSide = 1;
  List<File> capturedImagePaths = [];
  bool isDetecting = false;
  bool isCardAligned = false;
  int stableFrames = 0;
  static const int requiredStableFrames = 30; // ~1 second at 30fps
  bool isCapturing = false;
  bool isManualCapture = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  /// Initializes the camera controller with retry logic.
  void _initializeCamera({int retryCount = 0, int maxRetries = 3}) {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _initializeControllerFuture = _controller.initialize().then((_) {
      if (mounted) {
        _controller.setFlashMode(FlashMode.auto);
        _startImageStream();
        setState(() {});
      }
    }).catchError((e) {
      if (retryCount < maxRetries) {
        Fluttertoast.showToast(msg: 'Retrying camera initialization...');
        Future.delayed(Duration(milliseconds: 700), () {
          _initializeCamera(retryCount: retryCount + 1, maxRetries: maxRetries);
        });
      } else {
        Fluttertoast.showToast(msg: 'Camera initialization failed: $e');
        setState(() {
          _initializeControllerFuture = Future.error(e);
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (!_controller.value.isInitialized || _controller.value.hasError)) {
      _initializeCamera();
    } else if (state == AppLifecycleState.paused) {
      if (_controller.value.isStreamingImages) {
        _controller.stopImageStream(); // Returns Future<void>, do not assign
      }
    }
  }

  /// Starts the camera image stream for real-time card detection.
  Future<void> _startImageStream() async {
    if (!_controller.value.isInitialized || _controller.value.hasError) return;
    try {
      await _controller.startImageStream((CameraImage image) async {
        if (!isDetecting && !isCapturing && !isManualCapture && mounted) {
          setState(() => isDetecting = true);
          await _processImage(image);
          if (mounted) setState(() => isDetecting = false);
        }
      });
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error starting image stream: $e');
      setState(() => isDetecting = false);
    }
  }

  /// Processes camera images for card detection.
  Future<void> _processImage(CameraImage image) async {
    try {
      final inputImage = _convertCameraImage(image);
      final labels = await _imageLabeler.processImage(inputImage);

      // Detect card-like objects
      bool cardDetected = labels.any((label) =>
          label.label.toLowerCase().contains('card') ||
          label.label.toLowerCase().contains('document') ||
          label.label.toLowerCase().contains('id'));

      if (cardDetected && labels.first.confidence > 0.9) {
        // Simulate alignment within overlay (in production, use bounding box)
        stableFrames++;
        if (stableFrames >= requiredStableFrames && !isCapturing) {
          setState(() => isCardAligned = true);
          await _captureImage(automatic: true);
        }
      } else {
        stableFrames = 0;
        setState(() => isCardAligned = false);
      }
    } catch (e) {
      stableFrames = 0;
      setState(() => isCardAligned = false);
      Fluttertoast.showToast(msg: 'Error processing image: $e');
    }
  }

  /// Converts CameraImage to InputImage for ML Kit.
  InputImage _convertCameraImage(CameraImage image) {
    final WriteBuffer buffer = WriteBuffer();
    for (Plane plane in image.planes) {
      buffer.putUint8List(plane.bytes);
    }
    final bytes = buffer.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: Platform.isAndroid
            ? InputImageFormat.nv21
            : InputImageFormat.bgra8888,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Future<void> _captureImage({required bool automatic}) async {
    if (isCapturing || !_controller.value.isInitialized) {
      if (!automatic) {
        Fluttertoast.showToast(msg: 'Camera not ready, please try again');
      }
      return;
    }
    setState(() => isCapturing = true);

    try {
      // Add slight delay to ensure camera is ready and buffers are clear
      await Future.delayed(Duration(milliseconds: 100));

      // Stop image stream to free up buffers
      if (_controller.value.isStreamingImages) {
        await _controller
            .stopImageStream(); // Returns Future<void>, do not assign
      }

      final XFile image = await _controller.takePicture();

      // Save image securely
      final tempDir = await getTemporaryDirectory();
      final fileName =
          '${widget.cardType.toLowerCase().replaceAll(' ', '_')}_side_$currentSide${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = path.join(tempDir.path, fileName);
      final file = File(filePath);
      await image.saveTo(filePath);
      setState(() {
        capturedImagePaths.add(file);
      });
      Fluttertoast.showToast(msg: 'Captured side $currentSide');

      if (currentSide < widget.sides) {
        // Prepare for next side
        setState(() {
          currentSide++;
          stableFrames = 0;
          isCardAligned = false;
          isCapturing = false;
          isManualCapture = false;
        });
        await _startImageStream(); // Now correctly awaits Future<void>
      } else {
        // All sides captured
        Navigator.pop(context, capturedImagePaths);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error capturing image: $e');
      setState(() {
        isCapturing = false;
        isManualCapture = false;
      });
      // Attempt to restart image stream only if not automatic
      if (!automatic) {
        await _startImageStream(); // Now correctly awaits Future<void>
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_controller.value.isStreamingImages) {
      _controller.stopImageStream(); // Returns Future<void>, do not assign
    }
    _controller.dispose();
    _imageLabeler.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Scan ${widget.cardType} - Side $currentSide/${widget.sides}',
          style: textStyleVersion2(fontSize: 18.sp, color: Colors.white),
        ),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context); // Returns void, do not assign
          },
        ),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasError) {
            return Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller),
                // Custom overlay
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 320.w,
                    height: 200.h,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isCardAligned ? Colors.green : Colors.blue,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Stack(
                      children: [
                        // Corner indicators
                        Positioned(
                            top: 0, left: 0, child: _buildCornerIndicator()),
                        Positioned(
                            top: 0, right: 0, child: _buildCornerIndicator()),
                        Positioned(
                            bottom: 0, left: 0, child: _buildCornerIndicator()),
                        Positioned(
                            bottom: 0,
                            right: 0,
                            child: _buildCornerIndicator()),
                        // Instruction text
                        Center(
                          child: AnimatedOpacity(
                            opacity: isCardAligned ? 1.0 : 0.8,
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              isCardAligned
                                  ? 'Hold steady...'
                                  : 'Align ${widget.cardType} within box',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                                shadows: [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black.withOpacity(0.5),
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Manual capture button
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 20.h),
                    child: FloatingActionButton(
                      backgroundColor: isCapturing ? Colors.grey : Colors.white,
                      onPressed: isCapturing
                          ? null
                          : () {
                              setState(() => isManualCapture = true);
                              _captureImage(automatic: false);
                            },
                      child:
                          Icon(Icons.camera, color: Colors.black, size: 24.sp),
                    ),
                  ),
                ),
                // Loading indicator
                if (isCapturing)
                  Center(
                    child: SpinKitFadingCircle(
                      color: Colors.white,
                      size: 50.sp,
                    ),
                  ),
              ],
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Camera error: ${snapshot.error}',
                    style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  ),
                  SizedBox(height: 20.h),
                  ElevatedButton(
                    onPressed: () {
                      _initializeCamera(); // Returns void, do not assign
                    },
                    child: Text(
                      'Retry Camera',
                      style: TextStyle(fontSize: 16.sp),
                    ),
                  ),
                ],
              ),
            );
          } else {
            return Center(
              child: SpinKitFadingCircle(
                color: Colors.white,
                size: 50.sp,
              ),
            );
          }
        },
      ),
    );
  }

  /// Builds a corner indicator for the overlay.
  Widget _buildCornerIndicator() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 20.w,
      height: 20.h,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
              color: isCardAligned ? Colors.green : Colors.blue, width: 3),
          top: BorderSide(
              color: isCardAligned ? Colors.green : Colors.blue, width: 3),
        ),
      ),
    );
  }
}
