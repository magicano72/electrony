import 'package:Electrony/bloc/master_event.dart';
import 'package:Electrony/bloc/master_logic.dart';
import 'package:Electrony/bloc/master_state.dart';
import 'package:Electrony/custom/auth_text_form.dart';
import 'package:Electrony/custom/button.dart';
import 'package:Electrony/custom/snacbar.dart';
import 'package:Electrony/helper/validation.dart';
import 'package:Electrony/screens/authentication/forgrt_password/new_password.dart';
import 'package:Electrony/theming/style.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:page_transition/page_transition.dart';

// ignore: must_be_immutable
class GetOtp extends StatelessWidget {
  GetOtp({
    super.key,
  });
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
      body: Scaffold(
        backgroundColor: Colors.white,
        body: BlocListener<MasterBloc, MasterState>(
          listener: (context, state) {
            // if (state is OtpSuccess) {
            //   Navigator.push(
            //     context,
            //     PageTransition(
            //       type: PageTransitionType.fade,
            //       child: OtpVerification(
            //         phoneNumber:
            //             context.read<MasterBloc>().phoneController.text,
            //         forgotPassword: true,
            //       ),
            //     ),
            //   );
            // } else if (state is OtpFailure) {
            //   showCustomSnackBar(context, state.errMessage, isError: true);
            // }
          },
          child: BlocBuilder<MasterBloc, MasterState>(
            builder: (context, state) {
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
                            width: 280.w, height: 280.h),
                        SizedBox(height: 40.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Text(
                            'We will send you a one-time password to your registered mobile number.',
                            style: textStyle(
                              "Poppins",
                              18,
                              Color(0xff3A3A3A),
                              FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 30.h),
                        Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40.w),
                            child: CustomForm(
                              hintText: 'Enter Mobile Number',
                              controller:
                                  context.read<MasterBloc>().phoneController,
                              keyType: false,
                              validitor: validatePhoneNumber,
                              secure: false,
                              fixed: false,
                              prefixIcon: Icon(Icons.phone, color: Colors.blue),
                            )),
                        SizedBox(height: 30.h),
                        Container(
                            child: CustomAuthButton(
                                text: 'Continue',
                                onPressed: () async {
                                  // Add +2 prefix if not present
                                  final phoneController = context
                                      .read<MasterBloc>()
                                      .phoneController;
                                  if (!phoneController.text.startsWith('+2')) {
                                    phoneController.text =
                                        '+2${phoneController.text}';
                                  }

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

                                    // Update state with connection status
                                    context
                                        .read<MasterBloc>()
                                        .add(CheckInternetConnection());

                                    if (isConnected) {
                                      Navigator.push(
                                        context,
                                        PageTransition(
                                          type: PageTransitionType.fade,
                                          child: MyNewPasswordScreen(),
                                        ),
                                      );
                                    } else {
                                      showCustomSnackBar(
                                          context, 'No internet connection.',
                                          isError: true);
                                    }
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
