import 'package:Electrony/custom/button.dart';
import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const CustomErrorWidget({
    Key? key,
    required this.message,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/empty.png',
              width: 180.w,
              height: 180.h,
              fit: BoxFit.cover,
            ),
            SizedBox(height: 16.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textStyleVersion2(),
            ),
            if (onRetry != null) ...[
              SizedBox(height: 20.h),
              Container(
                  width: 190.w,
                  height: 50.h,
                  child: CustomButton(text: 'Retry', onPressed: onRetry!))
            ]
          ],
        ),
      ),
    );
  }
}
