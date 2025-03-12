import 'package:Electrony/Custom/button.dart';
import 'package:Electrony/Helper/validation.dart';
import 'package:Electrony/Theming/colors.dart';
import 'package:Electrony/Theming/style.dart';
import 'package:Electrony/bloc/Auth/auth_blok.dart';
import 'package:Electrony/bloc/Auth/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ignore: must_be_immutable
class OTPVerificationScreen extends StatelessWidget {
  OTPVerificationScreen({
    super.key,
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
                            'We will send you a one-time password to your registered mobile number.',
                            style: Style.getOtpDetail,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        Text('Enter Mobile Number', style: Style.getOtp),
                        SizedBox(height: 20.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40.w),
                          child: TextFormField(
                            validator: validatePhoneNumber,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              labelStyle: TextStyle(
                                  color: PrimaryColors.mainColor,
                                  fontSize: 16.sp),
                              border: UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: PrimaryColors.mainColor),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: PrimaryColors.mainColor),
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        SizedBox(height: 52.h),
                        Container(
                            width: 220.w,
                            height: 55.h,
                            child: CustomButton(
                                text: 'Get Otp',
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
