import 'package:Electrony/Helper/otp_input.dart';
import 'package:Electrony/Theming/colors.dart';
import 'package:Electrony/Theming/style.dart';
import 'package:Electrony/bloc/Auth/auth_blok.dart';
import 'package:Electrony/bloc/Auth/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ignore: must_be_immutable
class OTPVerificationScreen extends StatelessWidget {
  final TextEditingController _otpController = TextEditingController();

  OTPVerificationScreen({
    super.key,
  });
  void _verifyOtp(BuildContext context, String otp) {
    // Handle OTP verification logic here
    print("Entered OTP: $otp");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              // if (state.status == AuthStatus.success) {
              //   Navigator.pushNamedAndRemoveUntil(
              //     context,
              //     '/dashboard',
              //     (Route<dynamic> route) => false,
              //   );
              // } else if (state.status == AuthStatus.failure) {
              //   showCustomSnackBar(context, 'OTP Verification Failed.',
              //       isError: true);
              // }
            },
            child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                // if (state.status == AuthStatus.loading) {
                //   return Scaffold(
                //     backgroundColor: Colors.white,
                //     body: Center(
                //       child: Column(
                //         mainAxisAlignment: MainAxisAlignment.center,
                //         children: [
                //           // Use any spinner from flutter_spinkit
                //           SpinKitFadingCircle(
                //             color: Colors.blue,
                //             size: 50.0,
                //           ),
                //           SizedBox(height: 20),
                //           Text(
                //             'Loading, please wait...',
                //             style: TextStyle(
                //                 fontSize: 16, fontWeight: FontWeight.w500),
                //             textAlign: TextAlign.center,
                //           ),
                //         ],
                //       ),
                //     ),
                //   );
                // }

                return Form(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 25.h,
                          ),
                          Text(
                            'Verification OTP',
                            style: Style.font27maincolor,
                          ),
                          Image.asset('assets/otp.png'),
                          OtpInput(
                            onOtpEntered: (p0) {
                              _otpController.text = p0;
                            },
                          ),
                          SizedBox(height: 35.h),
                          Container(
                            width: 220.w,
                            height: 55.h,
                            child: ElevatedButton(
                              style: ButtonStyle(
                                  backgroundColor: WidgetStateProperty.all(
                                      PrimaryColors.mainColor)),
                              onPressed: () {
                                if (_otpController.text.isNotEmpty) {
                                  _verifyOtp(context, _otpController.text);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Please enter OTP')),
                                  );
                                }
                              },
                              child: Text('Verify OTP',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
