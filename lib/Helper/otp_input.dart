import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

late final String? verificationId;

class OtpInput extends StatefulWidget {
  final Function(String) onOtpEntered;
  // Callback when OTP is fully entered

  const OtpInput({Key? key, required this.onOtpEntered}) : super(key: key);

  @override
  _OtpInputState createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final String? verificationId;
  // TextEditingControllers for each digit
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    // Dispose controllers and focus nodes
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onOtpChanged() {
    // Combine the text from all the controllers
    String otp = _controllers.map((controller) => controller.text).join();

    if (otp.length == 6) {
      widget.onOtpEntered(otp); // Callback when the OTP is complete
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 40,
              child: TextFormField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                maxLength: 1, // Limit to one character per field
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24.sp),
                decoration: const InputDecoration(
                  counterText: '', // Hide counter below the text field
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    // Move to the next field if there’s input and it's not the last field
                    FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
                  } else if (value.isEmpty && index > 0) {
                    // Move back to the previous field if the current one is empty
                    FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
                  }
                  _onOtpChanged(); // Check OTP status
                },
              ),
            );
          }),
        ),
        SizedBox(
          height: 15.h,
        ),
      ],
    );
  }
}
