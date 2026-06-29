import 'dart:io';

import 'package:Electrony/custom/button.dart';
import 'package:Electrony/networking/api_services.dart';
import 'package:Electrony/screens/authentication/kyc/chosse_identity_verification_method.dart';
import 'package:Electrony/screens/authentication/kyc/introduction_face.dart';
import 'package:Electrony/theming/style.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';

class VerificationDocumentPreview extends StatefulWidget {
  final List<File> imagePaths;
  final String cardType;

  const VerificationDocumentPreview({
    super.key,
    required this.imagePaths,
    required this.cardType,
  });

  @override
  State<VerificationDocumentPreview> createState() =>
      _VerificationDocumentPreviewState();
}

class _VerificationDocumentPreviewState
    extends State<VerificationDocumentPreview> {
  final authApiService =
      AuthApiService(baseUrl: dotenv.env['API_BASE_URL'] ?? '');
  bool _isLoading = false;

  Future<void> _handleConfirm() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    Fluttertoast.showToast(
        msg: 'Document images confirmed. Now capturing face.');
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        Fluttertoast.showToast(msg: 'No camera available for face capture.');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final CameraDescription frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FaceRecognitionInstruction(
            camera: frontCamera,
            documentImagePaths: widget.imagePaths,
          ),
        ),
      );
      setState(() {
        _isLoading = false;
      });
      if (result != null && result is String) {
        Fluttertoast.showToast(
            msg: 'Face captured successfully. Ready for final processing.');
        print('Document Images: ${widget.imagePaths}');
        print('Face Image: $result');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(
          msg: 'Error accessing camera for face capture: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          '${widget.cardType} Preview',
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
                  child: ListView.builder(
                    itemCount: widget.imagePaths.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 16.h),
                        child: Column(
                          children: [
                            Text(
                              'Side ${index + 1}',
                              style: textStyleVersion2(
                                  fontSize: 16.sp, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 8.h),
                            Image.file(
                              widget.imagePaths[index],
                              height: 200.h,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Text(
                                'Error loading image',
                                style: textStyleVersion2(
                                    fontSize: 14.sp, color: Colors.red),
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    CustomButton(
                      text: 'Retry',
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ChooseIdentityVerificationMethod(),
                          ),
                        );
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
