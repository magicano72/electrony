import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final Color textColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  CustomButton({
    required this.text,
    required this.onPressed,
    this.color = const Color(0xFF2980B9),
    this.textColor = Colors.white,
    this.borderRadius = 8.0,
    EdgeInsets? padding,
  }) : this.padding =
            padding ?? EdgeInsets.symmetric(vertical: 8.h, horizontal: 20.w);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(text, style: textStyleVersion2(color: Colors.white)),
        ),
      ),
    );
  }
}

class CustomAuthButton extends StatelessWidget {
  final String text;
  final double width;
  final double height;
  final VoidCallback onPressed;

  const CustomAuthButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.width = 380,
    this.height = 48,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: width.w,
        height: height.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF2980B9),
              Color(0xFF3498DB),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: textStyle(
              "Poppins",
              18,
              Colors.white,
              FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
