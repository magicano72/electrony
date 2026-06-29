import 'package:Electrony/custom/button.dart';
import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SuccessScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onContinue;
  final String imagePath;
  final String? appbarTitle;
  final VoidCallback? textButtonAction;
  final String? textButtontext;

  const SuccessScreen({
    super.key,
    this.title = "Success!",
    this.subtitle =
        "Congratulations! You have been\nsuccessfully authenticated",
    this.buttonText = "Continue",
    this.imagePath = "assets/success.png",
    required this.onContinue,
    this.appbarTitle,
    this.textButtonAction,
    this.textButtontext,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: appbarTitle != null
          ? AppBar(
              centerTitle: true,
              title: Text(appbarTitle ?? "",
                  style: textStyleVersion2(fontSize: 22)),
              backgroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                padding: const EdgeInsets.all(20),
                child: Image.asset(
                  imagePath,
                ),
                width: 250.w,
                height: 250.h),
            SizedBox(height: 30.h),

            Text(
              title,
              style: textStyle(
                "Inter",
                22,
                Color(0xff323232),
                FontWeight.w700,
              ),
            ),

            SizedBox(height: 8.h),

            // ✅ Subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: textStyle(
                "Poppins",
                18,
                Color(0xff898989),
                FontWeight.w500,
              ),
            ),

            SizedBox(height: 60.h),

            // ✅ Continue Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: CustomAuthButton(
                text: buttonText,
                onPressed: onContinue,
              ),
            ),
            textButtontext != null
                ? TextButton(
                    onPressed: textButtonAction!,
                    child: Text("${textButtontext!}",
                        style: textStyleVersion2(
                            fontSize: 14, color: Color(0xff228DD0))))
                : SizedBox()
          ],
        ),
      ),
    );
  }
}
