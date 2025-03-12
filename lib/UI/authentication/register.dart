import 'package:Electrony/Custom/button.dart';
import 'package:Electrony/Custom/name_form.dart';
import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/Custom/text_form.dart';
import 'package:Electrony/Helper/image_constant.dart';
import 'package:Electrony/Helper/validation.dart';
import 'package:Electrony/Theming/colors.dart';
import 'package:Electrony/Theming/style.dart';
import 'package:Electrony/UI/authentication/login.dart';
import 'package:Electrony/UI/authentication/otp_verification.dart';
import 'package:Electrony/bloc/Auth/auth_blok.dart';
import 'package:Electrony/bloc/Auth/auth_event.dart';
import 'package:Electrony/bloc/Auth/auth_state.dart';
import 'package:Electrony/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:page_transition/page_transition.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

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
                    'Sign Up',
                    style: Style.signUp,
                  ),
                  SizedBox(
                    height: 15.h,
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageTransition(
                          type: PageTransitionType.fade,
                          child: Login(),
                        ),
                      );
                    },
                    child: RichText(
                      text: TextSpan(
                        text: 'Already have an account ? ',
                        style: Style.signDetail,
                        children: <TextSpan>[
                          TextSpan(
                            text: 'Sign in',
                            style: Style.signDetail.copyWith(
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
          ),
          Center(
            child: Container(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(15.0),
                  child: BlocListener<AuthBloc, AuthState>(
                    listener: (context, state) {
                      if (state is SignUpSuccess) {
                        Navigator.push(
                          context,
                          PageTransition(
                            type: PageTransitionType.fade,
                            child: OtpVerification(
                                phoneNumber: context
                                    .read<AuthBloc>()
                                    .phoneController
                                    .text),
                          ),
                        );
                      } else if (state is SignUpFailure) {
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
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomNameForm(
                                      hintText: 'First Name',
                                      controller:
                                          context.read<AuthBloc>().first_name,
                                      validitor: validateName,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 12.w,
                                  ),
                                  Expanded(
                                    child: CustomNameForm(
                                      hintText: 'Last Name',
                                      controller:
                                          context.read<AuthBloc>().last_name,
                                      validitor: validateName,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
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
                              SizedBox(height: 16.h),
                              CustomForm(
                                phoneNumber: true,
                                hintText: "phone number",
                                controller:
                                    context.read<AuthBloc>().phoneController,
                                keyType: false, // Phone input
                                validitor: validatePhoneNumber,
                                secure: false,
                                fixed: false,
                                onTap: () {
                                  if (context
                                      .read<AuthBloc>()
                                      .phoneController
                                      .text
                                      .isEmpty) {
                                    context
                                        .read<AuthBloc>()
                                        .phoneController
                                        .text = "+20";
                                  }
                                },
                              ),
                              SizedBox(height: 16.h),
                              CustomForm(
                                phoneNumber: true,
                                hintText: "Birth of Date",
                                controller: context.read<AuthBloc>().birthDate,
                                keyType: false, // Phone input
                                validitor: validateBirthDate,
                                secure: false,
                                fixed: false,
                                birth: true,
                                onTap: () {
                                  DatePicker.showDatePicker(context,
                                      showTitleActions: true,
                                      minTime: DateTime(1950, 1, 1),
                                      maxTime: DateTime(2025, 1, 1),
                                      onChanged: (date) {
                                    print('change $date');
                                  }, onConfirm: (date) {
                                    context.read<AuthBloc>().birthDate.text =
                                        date.toLocal().toString().split(' ')[0];
                                  },
                                      currentTime: DateTime.now(),
                                      locale: LocaleType.en);
                                },
                              ),
                              SizedBox(height: 30.h),
                              state is SignUpLoading
                                  ? CircularProgressIndicator(
                                      color: Color(0xff1D61E7),
                                    )
                                  : Container(
                                      width: 270.w,
                                      height: 60.h,
                                      child: CustomButton(
                                        text: 'Sign Up',
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
                                            context.read<AuthBloc>().add(
                                                  AuthRegisterRequested(
                                                      context
                                                          .read<AuthBloc>()
                                                          .emailController
                                                          .text,
                                                      context
                                                          .read<AuthBloc>()
                                                          .passwordController
                                                          .text,
                                                      context
                                                          .read<AuthBloc>()
                                                          .phoneController
                                                          .text,
                                                      context
                                                          .read<AuthBloc>()
                                                          .first_name
                                                          .text,
                                                      context
                                                          .read<AuthBloc>()
                                                          .last_name
                                                          .text,
                                                      context
                                                          .read<AuthBloc>()
                                                          .birthDate
                                                          .text),
                                                );
                                          }
                                        },
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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              margin: EdgeInsets.only(top: 180.h, left: 20.w, right: 20.w),
              height: 420,
              width: double.infinity,
            ),
          ),
        ],
      ),
    );
  }
}
