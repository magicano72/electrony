import 'package:Electrony/Custom/button.dart';
import 'package:Electrony/Helper/otp_input.dart';
import 'package:Electrony/Theming/style.dart';
import 'package:Electrony/bloc/Auth/auth_blok.dart';
import 'package:Electrony/bloc/Auth/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ignore: must_be_immutable
class OtpVerification extends StatelessWidget {
  final String phoneNumber;
  OtpVerification({
    super.key,
    required this.phoneNumber,
  });
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Scaffold(
        backgroundColor: Colors.white,
        body: BlocListener<AuthBloc, AuthState>(
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
                key: _formKey,
                child: SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(height: 72.h),
                        Image.asset('assets/otp.png',
                            width: 300.w, height: 300.h),
                        SizedBox(height: 40.h),
                        Text(
                          'OTP Verification',
                          style: TextStyle(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        ),
                        SizedBox(height: 20.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Text(
                            'Enter the OTP sent to $phoneNumber',
                            style: Style.getOtpDetail,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 50.w),
                          child: OtpInput(
                            onOtpEntered: (p0) {
                              context.read<AuthBloc>().otpController.text = p0;
                            },
                          ),
                        ),
                        SizedBox(height: 32.h),
                        InkWell(
                          onTap: () {},
                          child: RichText(
                            text: TextSpan(
                              text: 'Didn’t you receive the OTP ?',
                              style: Style.getOtpDetail,
                              children: <TextSpan>[
                                TextSpan(
                                  text: ' Resend OTP',
                                  style: Style.resendOtp.copyWith(
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 42.h),
                        Container(
                            width: 220.w,
                            height: 55.h,
                            child: CustomButton(
                                text: 'Verify OTP',
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    // Handle OTP request logic here
                                    print('Get OTP button pressed');
                                  }
                                })),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
