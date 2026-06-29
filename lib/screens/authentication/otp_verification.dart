import 'package:Electrony/Custom/button.dart';
import 'package:Electrony/screens/authentication/kyc/chosse_identity_verification_method.dart';
import 'package:Electrony/screens/authentication/login.dart';
import 'package:Electrony/bloc/master_event.dart';
import 'package:Electrony/bloc/master_logic.dart';
import 'package:Electrony/bloc/master_state.dart';
import 'package:Electrony/custom/snacbar.dart';
import 'package:Electrony/custom/success_screen.dart';
import 'package:Electrony/networking/api_services.dart';
import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:page_transition/page_transition.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ignore: must_be_immutable
class OtpVerification extends StatefulWidget {
  final String phoneNumber;
  final bool forgotPassword;
  OtpVerification({
    super.key,
    required this.phoneNumber,
    required this.forgotPassword,
  });

  @override
  State<OtpVerification> createState() => _OtpVerificationState();
}

class _OtpVerificationState extends State<OtpVerification> {
  final _formKey = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    _loadOtpToken(); // 🔑 load the token
  }

  String? otpToken;
  Future<void> _loadOtpToken() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('otp_token');

    setState(() {
      otpToken = savedToken;
    });

    if (savedToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('No OTP token found. Please request OTP again.')),
      );
    }
  }

  final apiService = AuthApiService(baseUrl: dotenv.env['API_BASE_URL'] ?? '');
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Scaffold(
        appBar: AppBar(
          title: Text(
            'OTP Verification',
            style: textStyleVersion2(),
          ),
          centerTitle: true,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_outlined, color: Colors.black),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        backgroundColor: Colors.white,
        body: BlocListener<MasterBloc, MasterState>(
          listener: (context, state) async {
            if (widget.forgotPassword) {
              if (state is ResetPasswordSuccess) {
                Navigator.push(
                  context,
                  PageTransition(
                    type: PageTransitionType.fade,
                    child: SuccessScreen(
                      onContinue: () {
                        Navigator.push(
                          context,
                          PageTransition(
                            type: PageTransitionType.fade,
                            child: Login(),
                          ),
                        );
                      },
                      title: 'Password Reset',
                      subtitle: 'Your password has been reset successfully.',
                      buttonText: 'Login',
                    ),
                  ),
                );
              } else if (state is ResetPasswordFailure) {
                showCustomSnackBar(context, state.errMessage, isError: true);
              }
            } else {
              if (state is SignUpSuccess) {
                Navigator.push(
                  context,
                  PageTransition(
                    type: PageTransitionType.fade,
                    child: SuccessScreen(
                      onContinue: () {
                        Navigator.pushReplacement(
                          context,
                          PageTransition(
                            type: PageTransitionType.fade,
                            child: SuccessScreen(
                              imagePath: 'assets/shield1.png',
                              title: 'Its time to verify your identity',
                              subtitle:
                                  'Complete identity verification to increase account security and get access to more services',
                              buttonText: 'Get Verified',
                              textButtonAction: () {
                                apiService.addUserStatus('unverified');
                                Navigator.pushReplacementNamed(
                                    context, '/dashboard');
                              },
                              textButtontext: 'Skip, Verify later',
                              appbarTitle: 'Identity Verification',
                              onContinue: () {
                                Navigator.push(
                                    context,
                                    PageTransition(
                                      type: PageTransitionType.fade,
                                      child: ChooseIdentityVerificationMethod(),
                                    ));
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }
              if (state is SignUpFailure) {
                showCustomSnackBar(context, state.errMessage, isError: true);
              }
            }
          },
          child: BlocBuilder<MasterBloc, MasterState>(
            builder: (context, state) {
              return Form(
                key: _formKey,
                child: SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: 50.h),
                        Image.asset('assets/otp.png',
                            width: 300.w, height: 300.h),
                        SizedBox(height: 40.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Text(
                            'Enter the OTP sent to ${widget.phoneNumber}',
                            style: textStyle(
                              "Poppins",
                              17,
                              Color(0xff1B1B1B),
                              FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 25.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40.w),
                          child: Pinput(
                            length: 4,
                            onCompleted: (pin) {
                              context.read<MasterBloc>().otpController.text =
                                  pin;
                            },
                            defaultPinTheme: PinTheme(
                              width: 56.w,
                              height: 56.h,
                              textStyle: TextStyle(
                                fontSize: 20.sp,
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 25.h),
                        InkWell(
                          onTap: () {},
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 8.w),
                            child: RichText(
                              text: TextSpan(
                                text: 'Didn’t you receive the OTP ?',
                                style: textStyle(
                                  "Poppins",
                                  17,
                                  Color(0xff1B1B1B),
                                  FontWeight.bold,
                                ),
                                children: <TextSpan>[
                                  TextSpan(
                                    text: ' Resend OTP',
                                    style: textStyle(
                                      "Poppins",
                                      17,
                                      Color(0xff007DFC),
                                      FontWeight.bold,
                                    ).copyWith(
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 25.h),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: state is SignUpLoading ||
                                  state is ResetPasswordLoading
                              ? Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xff1D61E7)))
                              : CustomAuthButton(
                                  text: 'Verify OTP',
                                  onPressed: () async {
                                    if (_formKey.currentState!.validate()) {
                                      if (widget.forgotPassword == false) {
                                        context.read<MasterBloc>().add(
                                              AuthRegisterRequested(
                                                context
                                                    .read<MasterBloc>()
                                                    .passwordController
                                                    .text,
                                                context
                                                    .read<MasterBloc>()
                                                    .first_name
                                                    .text,
                                                context
                                                    .read<MasterBloc>()
                                                    .last_name
                                                    .text,
                                                otpToken!,
                                                context
                                                    .read<MasterBloc>()
                                                    .otpController
                                                    .text,
                                              ),
                                            );
                                      } else {
                                        context.read<MasterBloc>().add(
                                              ResetPassword(
                                                  otpToken!,
                                                  context
                                                      .read<MasterBloc>()
                                                      .confirmPasswordController
                                                      .text,
                                                  context
                                                      .read<MasterBloc>()
                                                      .otpController
                                                      .text),
                                            );
                                      }
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text('Please enter OTP'),
                                      ));
                                    }
                                  }),
                        ),
                        SizedBox(height: 15.h),
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
