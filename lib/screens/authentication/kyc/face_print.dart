import 'dart:io';

import 'package:Electrony/custom/button.dart';
import 'package:Electrony/custom/success_screen.dart';
import 'package:Electrony/networking/api_services.dart';
import 'package:Electrony/theming/style.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

AuthApiService apiServices =
    AuthApiService(baseUrl: dotenv.env['API_BASE_URL'] ?? '');

class FaceCaptureScreen extends StatefulWidget {
  final CameraDescription camera;
  final List<File> documentImagePaths;

  const FaceCaptureScreen({
    super.key,
    required this.camera,
    required this.documentImagePaths,
  });

  @override
  _FaceCaptureScreenState createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen>
    with WidgetsBindingObserver {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
      enableClassification: false,
      minFaceSize: 0.1,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  bool isDetecting = false;
  bool isFaceAligned = false;
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

  /// Initializes the camera controller.
  void _initializeCamera() {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _initializeControllerFuture = _controller.initialize().then((_) {
      if (mounted) {
        _controller.setFlashMode(FlashMode.off);
        _startImageStream();
        setState(() {});
      }
    }).catchError((e) {
      Fluttertoast.showToast(msg: 'Camera initialization failed: $e');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_controller.value.isInitialized) {
      _initializeCamera();
    } else if (state == AppLifecycleState.paused) {
      _controller.stopImageStream();
    }
  }

  /// Starts the camera image stream for real-time face detection.
  void _startImageStream() {
    _controller.startImageStream((CameraImage image) async {
      if (!isDetecting && !isCapturing && !isManualCapture && mounted) {
        setState(() => isDetecting = true);
        await _processImage(image);
        if (mounted) setState(() => isDetecting = false);
      }
    });
  }

  /// Processes camera images for face detection.
  Future<void> _processImage(CameraImage image) async {
    try {
      final inputImage = _convertCameraImage(image);
      final faces = await _faceDetector.processImage(inputImage);

      // Detect a single face
      if (faces.isNotEmpty && faces.length == 1) {
        // Simulate alignment (in production, check face position upon overlay)
        stableFrames++;
        if (stableFrames >= requiredStableFrames && !isCapturing) {
          setState(() => isFaceAligned = true);
          await _captureImage(automatic: true);
        }
      } else {
        stableFrames = 0;
        setState(() => isFaceAligned = false);
      }
    } catch (e) {
      stableFrames = 0;
      setState(() => isFaceAligned = false);
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
        rotation: widget.camera.lensDirection == CameraLensDirection.front
            ? InputImageRotation.rotation270deg
            : InputImageRotation.rotation0deg,
        format: Platform.isAndroid
            ? InputImageFormat.nv21
            : InputImageFormat.bgra8888,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  /// Captures a face image, either automatically or manually.
  Future<void> _captureImage({required bool automatic}) async {
    if (isCapturing) return;
    setState(() => isCapturing = true);

    try {
      await _controller.stopImageStream();
      final XFile image = await _controller.takePicture();

      // Save image securely
      final tempDir = await getTemporaryDirectory();
      final fileName = 'face_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = path.join(tempDir.path, fileName);
      await image.saveTo(filePath);
      File imageFile = File(filePath);
      Fluttertoast.showToast(msg: 'Face captured');

      // Navigate to photo preview
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoPreviewScreen(
              documentsFile: widget.documentImagePaths,
              imageFile: imageFile,
              imagePath: filePath,
              isDocument: false,
              cardType: 'Face Recognition',
              sides: 1,
              camera: widget.camera,
            ),
          ),
        );
        if (result == true) {
          apiServices.addUserStatus('archived');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SuccessScreen(
                imagePath: 'assets/Suspension.png',
                title: 'Verification Submitted',
                subtitle:
                    'Your profile is pending verification. We will notify you once it is approved.',
                onContinue: () =>
                    Navigator.pushReplacementNamed(context, '/dashboard'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error capturing face: $e');
      setState(() {
        isCapturing = false;
        isManualCapture = false;
      });
      if (!automatic) _startImageStream();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.stopImageStream();
    _controller.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Capture Your Face',
          style: textStyleVersion2(fontSize: 18.sp, color: Colors.white),
        ),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
                // Oval overlay for face alignment
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 250.w,
                    height: 350.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isFaceAligned ? Colors.green : Colors.blue,
                        width: 3,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Instruction text
                        Center(
                          child: AnimatedOpacity(
                            opacity: isFaceAligned ? 1.0 : 0.8,
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              isFaceAligned
                                  ? 'Hold steady...'
                                  : 'Align your face within the oval',
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
                      backgroundColor: Colors.white,
                      onPressed: () {
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
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: SpinKitFadingCircle(
                        color: Colors.white,
                        size: 50.sp,
                      ),
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
                      _initializeCamera();
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
}

/// Screen for previewing a captured photo.
class PhotoPreviewScreen extends StatefulWidget {
  final File imageFile;
  final List<File> documentsFile;
  final String imagePath;
  final bool isDocument;
  final String cardType;
  final int sides;
  final CameraDescription camera;

  const PhotoPreviewScreen({
    super.key,
    required this.imagePath,
    required this.isDocument,
    required this.cardType,
    required this.sides,
    required this.camera,
    required this.imageFile,
    required this.documentsFile,
  });

  @override
  _PhotoPreviewScreenState createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  bool _isLoading = false;

  Future<void> _handleConfirm() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      String imageFileId =
          await apiServices.uploadProfileImage(widget.imageFile);
      await apiServices.updateUserVerificationImage(imageFileId);
      List<String> fileIds = [];
      for (File docFile in widget.documentsFile) {
        String docFileId = await apiServices.uploadProfileImage(docFile);
        fileIds.add(docFileId);
      }
      await apiServices.uploadFile(widget.documentsFile);
      await apiServices.saveUserDocumentRecords(fileIds);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Upload error: $e');
      Fluttertoast.showToast(
        msg: 'Error uploading images: $e',
        toastLength: Toast.LENGTH_LONG,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '${widget.isDocument ? widget.cardType : 'Face'} Preview',
          style:
              textStyleVersion2(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.black),
      ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Image.file(
                      File(widget.imagePath),
                      height: 300.h,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Text(
                        'Error loading image',
                        style: textStyleVersion2(
                            fontSize: 14.sp, color: Colors.red),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    CustomButton(
                      text: 'Retry',
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    CustomButton(
                      text: 'Confirm',
                      onPressed: () {
                        _handleConfirm();
                      },
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: SpinKitFadingCircle(
                  color: Colors.white,
                  size: 50.sp,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
