import 'package:Electrony/screens/authentication/kyc/instruction.dart';
import 'package:Electrony/theming/style.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:page_transition/page_transition.dart';
import 'package:permission_handler/permission_handler.dart';

/// Screen for selecting an identity verification method (e.g., National ID, Passport).
class ChooseIdentityVerificationMethod extends StatelessWidget {
  const ChooseIdentityVerificationMethod({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.black),
        title: Text(
          'Identity Verification',
          style: textStyleVersion2(),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20.h),
            Text(
              "Choose a method to verify\nyour account",
              style: textStyleVersion2(
                  fontSize: 18.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 24.h),
            _buildVerificationOption(
              context,
              iconPath: 'assets/national_id.png',
              label: 'National ID',
              sides: 2,
            ),
            SizedBox(height: 16.h),
            _buildVerificationOption(
              context,
              iconPath: 'assets/passport.png',
              label: 'Passport',
              sides: 1,
            ),
            SizedBox(height: 16.h),
            _buildVerificationOption(
              context,
              iconPath: 'assets/drivers-license.png',
              label: 'Driver License',
              sides: 2,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a clickable card for a verification option.
  Widget _buildVerificationOption(
    BuildContext context, {
    required String iconPath,
    required String label,
    required int sides,
  }) {
    return InkWell(
      onTap: () => _navigateToInstructions(context, label, sides, iconPath),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Image.asset(iconPath,
                height: 40.h, width: 40.w, fit: BoxFit.contain),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                label,
                style: textStyleVersion2(
                    fontSize: 16.sp, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16.sp, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  /// Navigates to the instruction screen for capturing card images.
  Future<void> _navigateToInstructions(
      BuildContext context, String cardType, int sides, String iconPath) async {
    try {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
        if (!status.isGranted) {
          Fluttertoast.showToast(
              msg: 'Camera permission denied. Please enable it in settings.');
          return;
        }
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        Fluttertoast.showToast(msg: 'No camera available on this device.');
        return;
      }

      Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.fade,
          child: InstructionScreen(
            cardType: cardType,
            sides: sides,
            camera: cameras.first,
            iconPath: iconPath,
          ),
        ),
      );
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error accessing camera: $e');
    }
  }
}
