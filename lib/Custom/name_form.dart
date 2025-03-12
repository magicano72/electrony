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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: _isFocused ? Colors.black12 : Color(0xffEDF1F3),
              width: 1.0,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
          hintText: widget.hintText,
          hintStyle: TextStyle(color: Colors.black),
        ),
      ),
    );
  }
}
