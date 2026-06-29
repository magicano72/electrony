import 'dart:io';

import 'package:Electrony/Custom/button.dart';
import 'package:Electrony/screens/authentication/kyc/face_print.dart';
import 'package:Electrony/theming/style.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';

class FaceRecognitionInstruction extends StatefulWidget {
  final CameraDescription camera;
  final List<File> documentImagePaths;

  const FaceRecognitionInstruction({
    super.key,
    required this.camera,
    required this.documentImagePaths,
  });

  @override
  _FaceRecognitionInstructionState createState() =>
      _FaceRecognitionInstructionState();
}

class _FaceRecognitionInstructionState
    extends State<FaceRecognitionInstruction> {
  bool _isLoading = false;

  Future<void> _handleTakePhoto() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      await Future.delayed(Duration(seconds: 1));
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FaceCaptureScreen(
              camera: widget.camera,
              documentImagePaths: widget.documentImagePaths,
            ),
          ),
        ).then((_) {
          setState(() {
            _isLoading = false;
          });
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(msg: 'Error accessing camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Identity Verification',
            style: textStyleVersion2(fontSize: 24)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                children: [
                  SizedBox(height: 20.h),
                  Image.asset(
                    'assets/face.png',
                    height: 200.h,
                  ),
                  SizedBox(height: 32.h),
                  Text('Facial recognition',
                      style: textStyleVersion2(fontWeight: FontWeight.w600)),
                  SizedBox(height: 8.h),
                  Text(
                      'In order to improve the success rate of face\nrecognition, please follow these requirements below',
                      textAlign: TextAlign.center,
                      style: textStyleVersion2(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xff1D1D1D).withOpacity(0.4))),
                  SizedBox(height: 24.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTip('assets/f3.png', 'Hold phone\nupright'),
                      _buildTip('assets/f1.png', 'Well-lit'),
                      _buildTip('assets/f2.png', "Don't\noccluded face"),
                    ],
                  ),
                  SizedBox(height: 50.h),
                  CustomAuthButton(
                    text: 'Take a photo',
                    onPressed: () {
                      _handleTakePhoto();
                    },
                  ),
                  SizedBox(height: 24.h),
                ],
              ),
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

  Widget _buildTip(String icon, String text) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24.r,
          backgroundColor: const Color(0xFF000D1D05),
          child: Image.asset(
            icon,
          ),
        ),
        SizedBox(height: 8.h),
        Text(text,
            textAlign: TextAlign.center,
            style:
                textStyleVersion2(fontSize: 14, fontWeight: FontWeight.w400)),
      ],
    );
  }
}
