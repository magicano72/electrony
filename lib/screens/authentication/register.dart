import 'package:Electrony/Custom/button.dart';
import 'package:Electrony/Custom/name_form.dart';
import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/bloc/master_event.dart';
import 'package:Electrony/bloc/master_logic.dart';
import 'package:Electrony/bloc/master_state.dart';
import 'package:Electrony/custom/auth_text_form.dart';
import 'package:Electrony/helper/validation.dart';
import 'package:Electrony/screens/authentication/otp_verification.dart';
import 'package:Electrony/theming/style.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
                      forgotPassword: false,
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
                  child: SafeArea(
                    child: Column(
                      children: [
                        SizedBox(height: 30.h),
                        Text(
                          'Sign Up',
                          style: textStyle(
                            "Poppins",
                            26,
                            Color(0xff1B1B1B),
                            FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 50.h),
                        Row(
                          children: [
                            Expanded(
                              child: CustomNameForm(
                                hintText: 'First Name',
                                controller:
                                    context.read<MasterBloc>().first_name,
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
                                    context.read<MasterBloc>().last_name,
                                validitor: validateName,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        CustomForm(
                          hintText: 'Email',
                          controller:
                              context.read<MasterBloc>().emailController,
                          keyType: true,
                          validitor: validateEmail,
                          secure: false,
                          fixed: false,
                          prefixIcon: Icon(
                            Icons.email_outlined,
                          ),
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
                          prefixIcon: Icon(
                            Icons.lock_outline,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        CustomForm(
                          phoneNumber: true,
                          hintText: "phone number",
                          controller:
                              context.read<MasterBloc>().phoneController,
                          keyType: false,
                          validitor: validatePhoneNumber,
                          secure: false,
                          fixed: false,
                          prefixIcon: Container(
                            margin: EdgeInsets.symmetric(horizontal: 8),
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Color(0xff3F90C3), width: 2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("🇪🇬", style: TextStyle(fontSize: 20)),
                                SizedBox(width: 4),
                                Text("+2", style: textStyleVersion2()),
                              ],
                            ),
                          ),
                          onTap: () {
                            if (!context
                                .read<MasterBloc>()
                                .phoneController
                                .text
                                .startsWith('+2')) {
                              context.read<MasterBloc>().phoneController.text =
                                  '+2${context.read<MasterBloc>().phoneController.text}';
                            }
                          },
                        ),
                        SizedBox(height: 16.h),
                        CustomForm(
                          phoneNumber: true,
                          hintText: "Birth of Date",
                          controller: context.read<MasterBloc>().birthDate,
                          keyType: false, // Phone input
                          validitor: validateBirthDate,
                          secure: false,
                          fixed: false,
                          birth: true,
                          prefixIcon: Icon(
                            Icons.calendar_month_outlined,
                          ),
                          onTap: () {
                            DatePicker.showDatePicker(context,
                                showTitleActions: true,
                                minTime: DateTime(1950, 1, 1),
                                maxTime: DateTime(2025, 1, 1),
                                onChanged: (date) {
                              print('change $date');
                            }, onConfirm: (date) {
                              context.read<MasterBloc>().birthDate.text =
                                  date.toLocal().toString().split(' ')[0];
                            },
                                currentTime: DateTime.now(),
                                locale: LocaleType.en);
                          },
                        ),
                        SizedBox(height: 40.h),
                        state is OtpLoading
                            ? CircularProgressIndicator(
                                color: Color(0xFF176A9F),
                              )
                            : Container(
                                child: CustomAuthButton(
                                  text: 'Sign Up',
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
                                        context.read<MasterBloc>().add(
                                              OtpVerificationRequested(
                                                "+2${context.read<MasterBloc>().phoneController.text.replaceAll('+2', '')}",
                                                context
                                                    .read<MasterBloc>()
                                                    .emailController
                                                    .text,
                                              ),
                                            );
                                      } else {
                                        showCustomSnackBar(
                                          context,
                                          "No internet connection.",
                                          isError: true,
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                        SizedBox(height: 20.h),
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: RichText(
                            text: TextSpan(
                              text: 'Already have an account ? ',
                              style: textStyle(
                                "Poppins",
                                16,
                                Color(0xff1B1B1B),
                                FontWeight.w400,
                              ),
                              children: <TextSpan>[
                                TextSpan(
                                  text: 'Login',
                                  style: textStyle(
                                    "Poppins",
                                    16,
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
