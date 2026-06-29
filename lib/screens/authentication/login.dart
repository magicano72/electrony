import 'package:Electrony/Custom/button.dart';
import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/screens/authentication/forgrt_password/get_otp.dart';
import 'package:Electrony/screens/authentication/register.dart';
import 'package:Electrony/bloc/master_event.dart';
import 'package:Electrony/bloc/master_logic.dart';
import 'package:Electrony/bloc/master_state.dart';
import 'package:Electrony/custom/auth_text_form.dart';
import 'package:Electrony/helper/validation.dart';
import 'package:Electrony/theming/colors.dart';
import 'package:Electrony/theming/style.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:page_transition/page_transition.dart';

import '../dashboard/dashboard.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  bool selected = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: BlocListener<MasterBloc, MasterState>(
            listener: (context, state) {
              if (state is SignInSuccess) {
                Navigator.push(
                  context,
                  PageTransition(
                    type: PageTransitionType.fade,
                    child: DashboardScreen(),
                  ),
                );
              } else if (state is SignInFailure) {
                showCustomSnackBar(context, state.errMessage, isError: true);
              }
            },
            child: BlocBuilder<MasterBloc, MasterState>(
              builder: (context, state) {
                return Form(
                  key: _formKey,
                  child: SafeArea(
                    child: Column(
                      children: [
                        SizedBox(height: 30.h),
                        Text(
                          'Log In',
                          style: textStyle(
                            "Poppins",
                            26,
                            Color(0xff1B1B1B),
                            FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 50.h),
                        CustomForm(
                          hintText: 'Email or phone',
                          controller:
                              context.read<MasterBloc>().emailController,
                          keyType: true,
                          validitor: validateEmailOrPhone,
                          secure: false,
                          fixed: false,
                        ),
                        SizedBox(height: 16.h),
                        CustomForm(
                          hintText: 'Password',
                          controller:
                              context.read<MasterBloc>().passwordController,
                          keyType: true,
                          validitor: validatePassword,
                          secure: true,
                          fixed: false,
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: selected,
                                    onChanged: (newValue) {
                                      setState(() {
                                        selected = newValue!;
                                      });
                                    },
                                    activeColor: PrimaryColors.mainColor,
                                  ),
                                  Flexible(
                                    child: Text(
                                      'Remember me',
                                      style: textStyle(
                                        "Poppins",
                                        16,
                                        Colors.black,
                                        FontWeight.w400,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    PageTransition(
                                      type: PageTransitionType.fade,
                                      child: GetOtp(),
                                    ),
                                  );
                                },
                                child: Text(
                                  "Forgot Password ?",
                                  style: textStyle(
                                    "Poppins",
                                    16,
                                    Color(0xff838383),
                                    FontWeight.w400,
                                  ),
                                ))
                          ],
                        ),
                        SizedBox(height: 22.h),
                        state is SignInLoading
                            ? CircularProgressIndicator(
                                color: Color(0xFF176A9F),
                              )
                            : Container(
                                child: CustomAuthButton(
                                  text: 'Login',
                                  onPressed: () async {
                                    if (_formKey.currentState!.validate()) {
                                      List<ConnectivityResult>
                                          connectivityResult =
                                          await Connectivity()
                                              .checkConnectivity();
                                      bool isConnected =
                                          connectivityResult.contains(
                                                  ConnectivityResult.wifi) ||
                                              connectivityResult.contains(
                                                  ConnectivityResult.mobile);

                                      if (isConnected) {
                                        context
                                            .read<MasterBloc>()
                                            .add(AuthLoginRequested(
                                              normalizePhoneOrEmail(context
                                                  .read<MasterBloc>()
                                                  .emailController
                                                  .text),
                                              context
                                                  .read<MasterBloc>()
                                                  .passwordController
                                                  .text,
                                            ));
                                      } else {
                                        showCustomSnackBar(
                                            context, 'No internet connection.',
                                            isError: true);
                                      }
                                    }
                                  },
                                ),
                              ),
                        SizedBox(
                          height: 27.h,
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              PageTransition(
                                type: PageTransitionType.fade,
                                child: RegisterScreen(),
                              ),
                            );
                          },
                          child: RichText(
                            text: TextSpan(
                              text: 'Don’t have an account ?',
                              style: textStyle(
                                "Poppins",
                                16,
                                Color(0xff1B1B1B),
                                FontWeight.w400,
                              ),
                              children: <TextSpan>[
                                TextSpan(
                                  text: ' Sign Up',
                                  style: textStyle(
                                    "Poppins",
                                    18,
                                    Color(0xff007DFC),
                                    FontWeight.w400,
                                  ).copyWith(
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
