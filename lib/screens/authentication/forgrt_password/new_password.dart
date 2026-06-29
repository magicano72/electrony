import 'package:Electrony/Custom/button.dart';
import 'package:Electrony/bloc/master_event.dart';
import 'package:Electrony/bloc/master_logic.dart';
import 'package:Electrony/bloc/master_state.dart';
import 'package:Electrony/custom/auth_text_form.dart';
import 'package:Electrony/custom/snacbar.dart';
import 'package:Electrony/helper/validation.dart';
import 'package:Electrony/networking/api_services.dart';
import 'package:Electrony/screens/authentication/otp_verification.dart';
import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyNewPasswordScreen extends StatefulWidget {
  const MyNewPasswordScreen({super.key});

  @override
  State<MyNewPasswordScreen> createState() => _MyNewPasswordScreenState();
}

class _MyNewPasswordScreenState extends State<MyNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    _loadOtpToken(); // 🔑 load the token
  }

  final authApiService =
      AuthApiService(baseUrl: dotenv.env['API_BASE_URL'] ?? '');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Reset Password',
          style: textStyle(
            "Poppins",
            24,
            Color(0xff1B1B1B),
            FontWeight.w500,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: BlocListener<MasterBloc, MasterState>(
            listener: (context, state) {
              if (state is OtpSuccess) {
                Navigator.push(
                  context,
                  PageTransition(
                    type: PageTransitionType.fade,
                    child: OtpVerification(
                      phoneNumber:
                          context.read<MasterBloc>().phoneController.text,
                      forgotPassword: true,
                    ),
                  ),
                );
              } else if (state is OtpFailure) {
                showCustomSnackBar(context, state.errMessage, isError: true);
              }
            },
            child: BlocBuilder<MasterBloc, MasterState>(
              builder: (context, state) {
                return Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 30.h),
                      Text(
                        'Enter New Password',
                        style: textStyle(
                          "Poppins",
                          18,
                          Color(0xff1B1B1B),
                          FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 20.h),
                      CustomForm(
                        hintText: 'New Password',
                        controller:
                            context.read<MasterBloc>().passwordController,
                        keyType: true,
                        validitor: validatePassword,
                        secure: true,
                        fixed: false,
                        prefixIcon: Icon(
                          Icons.lock_outline,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      CustomForm(
                        hintText: 'Confirm Password',
                        controller: context
                            .read<MasterBloc>()
                            .confirmPasswordController,
                        keyType: true,
                        validitor: (value) {
                          if (value !=
                              context
                                  .read<MasterBloc>()
                                  .passwordController
                                  .text) {
                            return 'Passwords dosn\'t match';
                          }
                          return null;
                        },
                        secure: true,
                        fixed: false,
                        prefixIcon: Icon(
                          Icons.lock_outline,
                        ),
                      ),
                      SizedBox(height: 30.h),
                      Center(
                        child: state is OtpLoading
                            ? CircularProgressIndicator(
                                color: Color(0xff1D61E7),
                              )
                            : Container(
                                width: double.infinity,
                                child: CustomAuthButton(
                                  text: 'Reset Password',
                                  onPressed: () {
                                    if (_formKey.currentState!.validate()) {
                                      context.read<MasterBloc>().add(
                                            OtpVerificationRestPasswordRequested(
                                              context
                                                  .read<MasterBloc>()
                                                  .phoneController
                                                  .text,
                                            ),
                                          );
                                    }
                                  },
                                ),
                              ),
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
