import 'package:flutter/material.dart';

class CustomForm extends StatefulWidget {
  final String hintText;
  final String? Function(String?)? validitor;
  final TextEditingController controller;
  final bool? keyType;
  final bool? phoneNumber; // true for email, false for phone
  final bool secure;
  final bool fixed;
  final bool? birth;
  final VoidCallback? onTap; // Add onTap callback

  CustomForm({
    super.key,
    required this.hintText,
    required this.controller,
    this.keyType,
    this.validitor,
    required this.secure,
    required this.fixed,
    this.phoneNumber,
    this.birth,
    this.onTap, // Initialize onTap
  });

  @override
  _CustomFormState createState() => _CustomFormState();
}

class _CustomFormState extends State<CustomForm> {
  late bool _isPasswordVisible;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _isPasswordVisible = widget.secure;
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
    return TextFormField(
      focusNode: _focusNode,
      validator: widget.validitor,
      keyboardType: widget.keyType == true
          ? TextInputType.emailAddress
          : widget.phoneNumber == true
              ? TextInputType.phone
              : TextInputType.text,
      obscureText: _isPasswordVisible,
      controller: widget.controller,
      enabled: widget.fixed == false,
      readOnly: widget.birth ?? false, // Make read-only if birth is true
      onTap: widget.birth ?? false ? widget.onTap : null, // Handle onTap
      decoration: InputDecoration(
        contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: _isFocused ? Colors.blue : Color(0xffEDF1F3),
            width: 0.5,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        hintText: widget.hintText,
        hintStyle: TextStyle(color: Colors.black),
        suffixIcon: widget.secure || (widget.birth ?? false)
            ? IconButton(
                icon: (widget.birth ?? false)
                    ? Icon(
                        Icons.date_range_outlined,
                        color: Color(0xffACB5BB),
                      )
                    : Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Color(0xffACB5BB),
                      ),
                onPressed: () {
                  if (widget.birth ?? false) {
                    widget.onTap?.call();
                  } else {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  }
                },
              )
            : null,
      ),
    );
  }
}
