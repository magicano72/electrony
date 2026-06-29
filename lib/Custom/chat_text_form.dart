import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ChatTextForm extends StatefulWidget {
  final String hintText;

  final TextEditingController controller;

  final Color containerColor;
  final Color prefixIconColor;
  final VoidCallback? onTap; // Add onTap callback

  final Widget? prefixIcon; // Changed from Icon? to Widget?

  ChatTextForm({
    super.key,
    required this.hintText,
    required this.controller,
    this.onTap,
    this.prefixIcon,
    required this.prefixIconColor,
    required this.containerColor, // Initialize prefixIcon
  });

  @override
  _ChatTextFormState createState() => _ChatTextFormState();
}

class _ChatTextFormState extends State<ChatTextForm> {
  @override
  void initState() {
    super.initState();

    ;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50.h,
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: widget.containerColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(width: 8.w),
          Expanded(
            child: TextField(
              controller: widget.controller,
              decoration: InputDecoration(
                prefixIcon: widget.prefixIcon,
                prefixIconColor: widget.prefixIconColor,
                hintText: widget.hintText,
                hintStyle: textStyleVersion2(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                    fontSize: 15,
                    color: Color(0xff718096)),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
