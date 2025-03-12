import 'package:Electrony/Custom/button.dart';
import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/Custom/text_form.dart';
import 'package:Electrony/Helper/image_constant.dart';
import 'package:Electrony/Helper/validation.dart';
import 'package:Electrony/Theming/colors.dart';
import 'package:Electrony/Theming/style.dart';
import 'package:Electrony/UI/auth/register.dart';
import 'package:Electrony/UI/dashboard.dart';
import 'package:Electrony/bloc/Auth/auth_blok.dart';
import 'package:Electrony/bloc/Auth/auth_event.dart';
import 'package:Electrony/bloc/Auth/auth_state.dart';
import 'package:Electrony/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:page_transition/page_transition.dart';

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
      body: Stack(
        children: [
          Container(
            color: PrimaryColors.bluegray50.withOpacity(0.3),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              color: PrimaryColors.registerColor,
              height: 400,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 72.h,
                  ),
                  Image.asset(
                    fit: BoxFit.cover,
                    ImageConstant.appLogo,
                    width: 40,
                    height: 40,
                  ),
                  SizedBox(
                    height: 15.h,
                  ),
                  Text(
                    'Sign in to your',
                    style: Style.signIn,
                  ),
                  Text(
                    'Account',
                    style: Style.signIn,
                  ),
                  SizedBox(
                    height: 15.h,
                  ),
                  Text('Enter your email and password to continue',
                      style: Style.signDetail),
                ],
              ),
            ),
          ),
          Center(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              margin: EdgeInsets.only(top: 240.h, left: 20.w, right: 20.w),
              height: 480.h,
              width: double.infinity,
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(15.0),
                  child: BlocListener<AuthBloc, AuthState>(
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
                        showCustomSnackBar(context, state.errMessage,
                            isError: true);
                      }
                    },
                    child: BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        return Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              SizedBox(height: 10.h),
                              CustomForm(
                                hintText: 'Email',
                                controller:
                                    context.read<AuthBloc>().emailController,
                                keyType: true,
                                validitor: validateEmail,
                                secure: false,
                                fixed: false,
                              ),
                              SizedBox(height: 16.h),
                              CustomForm(
                                hintText: 'Password',
                                controller:
                                    context.read<AuthBloc>().passwordController,
                                keyType: true,
                                validitor: validatePassword,
                                secure: true,
                                fixed: false,
                              ),
                              SizedBox(height: 12.h),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
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
                                      Text(
                                        'Remember me',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                      onPressed: () {},
                                      child: Text(
                                        "Forgot Password ?",
                                        style: Style.forget,
                                      ))
                                ],
                              ),
                              SizedBox(height: 22.h),
                              state is SignInLoading
                                  ? CircularProgressIndicator(
                                      color: Color(0xff1D61E7),
                                    )
                                  : Container(
                                      width: 270.w,
                                      height: 60.h,
                                      child: CustomButton(
                                        text: 'Login',
                                        onPressed: () async {
                                          bool isConnected =
                                              await checkInternetConnection();
                                          if (!isConnected) {
                                            showCustomSnackBar(
                                              context,
                                              'No Internet connection. Please try again later.',
                                              isError: true,
                                            );
                                            return;
                                          }
                                          if (_formKey.currentState!
                                              .validate()) {
                                            // Trigger registration with validated data
                                            context
                                                .read<AuthBloc>()
                                                .add(AuthLoginRequested(
                                                  context
                                                      .read<AuthBloc>()
                                                      .emailController
                                                      .text,
                                                  context
                                                      .read<AuthBloc>()
                                                      .passwordController
                                                      .text,
                                                ));
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
                                    style: Style.dontHaveAccount,
                                    children: <TextSpan>[
                                      TextSpan(
                                        text: ' Sign Up',
                                        style: Style.signUpNow.copyWith(
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
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
            ),
          ),
        ],
      ),
    );
  }
}
