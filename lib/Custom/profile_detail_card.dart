import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProfileDetailCard extends StatelessWidget {
  final String title;
  final String content;
  final Icon icon;
  final VoidCallback? onTap;
  ProfileDetailCard(
      {required this.title,
      required this.content,
      required this.icon,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20.w),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 5.h),
        Card(
          color: Colors.white,
          margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade300), // Subtle border
          ),
          child: InkWell(
            onTap: title == 'Logout' ? onTap : null,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 12), // Spacing between icon and text
                  Expanded(
                    child: Text(
                      content,
                      style: Style.profileDetail,
                    ),
                  ),
                  icon
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
