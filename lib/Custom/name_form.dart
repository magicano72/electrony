import 'package:Electrony/theming/colors.dart';
import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomNameForm extends StatefulWidget {
  final String hintText;
  final String? Function(String?)? validitor;
  final TextEditingController controller;

  CustomNameForm({
    super.key,
    required this.hintText,
    required this.controller,
    this.validitor,
  });

  @override
  _CustomNameFormState createState() => _CustomNameFormState();
}

class _CustomNameFormState extends State<CustomNameForm> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180.w,
      child: TextFormField(
        focusNode: _focusNode,
        controller: widget.controller,
        decoration: InputDecoration(
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: PrimaryColors.gray500),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          hintText: widget.hintText,
          prefixIcon: Icon(Icons.person, color: Colors.blue),
          hintStyle: textStyle(
            "Poppins",
            16,
            Color(0xff1B1B1B),
            FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
