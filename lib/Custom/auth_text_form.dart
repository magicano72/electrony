import 'package:Electrony/theming/colors.dart';
import 'package:Electrony/theming/style.dart';
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

  final Widget? prefixIcon; // Changed from Icon? to Widget?

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
    this.onTap,
    this.prefixIcon, // Initialize prefixIcon
  });

  @override
  _CustomFormState createState() => _CustomFormState();
}

class _CustomFormState extends State<CustomForm> {
  late bool _isPasswordVisible;

  @override
  void initState() {
    super.initState();
    _isPasswordVisible = widget.secure;
    ;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
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
        hintStyle: textStyle(
          "Poppins",
          16,
          Color(0xff1B1B1B),
          FontWeight.w400,
        ),
        prefixIcon: widget.prefixIcon,
        prefixIconColor: Color(0xff3F90C3),
        suffixIcon: widget.secure
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
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
