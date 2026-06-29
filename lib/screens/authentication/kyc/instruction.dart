import 'dart:io';

import 'package:Electrony/screens/authentication/kyc/card_capture.dart';
import 'package:Electrony/screens/authentication/kyc/document_preview.dart';
import 'package:Electrony/custom/button.dart';
import 'package:Electrony/theming/style.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';

class InstructionScreen extends StatefulWidget {
  final String cardType;
  final String iconPath;
  final int sides;
  final CameraDescription camera;

  const InstructionScreen({
    super.key,
    required this.cardType,
    required this.sides,
    required this.camera,
    required this.iconPath,
  });

  @override
  _InstructionScreenState createState() => _InstructionScreenState();
}

class _InstructionScreenState extends State<InstructionScreen> {
  bool _isLoading = false;

  Future<void> _handleTakePhoto() async {
    if (_isLoading) return; // Prevent action if already loading
    setState(() {
      _isLoading = true;
    });
    try {
      // Simulate async work (e.g., checking camera readiness)
      await Future.delayed(Duration(seconds: 1));
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CardCaptureScreen(
              cardType: widget.cardType,
              sides: widget.sides,
              camera: widget.camera,
            ),
          ),
        ).then((capturedImages) {
          setState(() {
            _isLoading = false;
          });
          if (capturedImages != null &&
              capturedImages is List<File> &&
              capturedImages.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VerificationDocumentPreview(
                  imagePaths: capturedImages,
                  cardType: widget.cardType,
                ),
              ),
            );
          }
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
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Identity Verification',
          style: textStyleVersion2(),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_user,
                        color: Colors.blue, size: 20),
                    SizedBox(width: 8.w),
                    Text(
                      'Verification',
                      style: textStyleVersion2(
                          fontSize: 16.sp, color: Colors.grey),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xff6AB7E9), width: 7),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Image.asset(
                    widget.iconPath,
                    height: 150.h,
                    width: 150.w,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  'Make sure you capture a clear and complete image',
                  style: textStyleVersion2(
                      fontSize: 18.sp, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20.h),
                Text(
                  'Please make sure that the following requirements are met',
                  style: textStyleVersion2(fontSize: 16.sp),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRequirement('Place the document on a flat surface'),
                    _buildRequirement('Make sure the photo isn\'t blurry'),
                    _buildRequirement('Capture your entire ID'),
                    _buildRequirement('Your ID isn\'t expired'),
                  ],
                ),
                SizedBox(height: 24.h),
                CustomAuthButton(
                  text: 'Take a photo',
                  onPressed: () {
                    _handleTakePhoto();
                  },
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

  Widget _buildRequirement(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: textStyleVersion2(fontSize: 16.sp, color: Colors.black),
          ),
          Expanded(
            child: Text(
              text,
              style: textStyleVersion2(fontSize: 16.sp, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
