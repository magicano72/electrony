import 'package:Electrony/Custom/button.dart';
import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/Custom/text_form.dart';
import 'package:Electrony/Helper/validation.dart';
import 'package:Electrony/Theming/colors.dart';
import 'package:Electrony/Theming/style.dart';
import 'package:Electrony/bloc/Auth/auth_blok.dart';
import 'package:Electrony/bloc/Auth/auth_event.dart';
import 'package:Electrony/bloc/Auth/auth_state.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../Networking/api_services.dart';

TextEditingController email = TextEditingController();

final authApiService = AuthApiService(baseUrl: 'http://139.59.134.100:8055');

Future<bool> showLoginDialog(
  BuildContext context, {
  String? preFilledEmail, // Allow passing an email to pre-fill the email field
}) async {
  bool loginSuccessful = false; // Default value for login status
  GlobalKey<FormState> _formKey =
      GlobalKey<FormState>(); // GlobalKey for form validation
  TextEditingController password = TextEditingController();
  TextEditingController email = TextEditingController();

  if (preFilledEmail != null) {
    email.text = preFilledEmail;
  }

  await showDialog(
    barrierDismissible: false,
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is SignInSuccess) {
              loginSuccessful = true; // Set login as successful
              Navigator.of(context).pop(); // Close the dialog
            } else if (state == SignInFailure) {
              showCustomSnackBar(context, 'Wrong password. Please try again.',
                  isError: true);
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    backgroundColor: Colors.white,
                    title: Text('Login Failed'),
                    content: Text(
                      'Wrong password. Please try again.',
                      style: TextStyle(color: Colors.red),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'OK',
                          style: Style.font20bold,
                        ),
                      ),
                    ],
                  );
                },
              );
            }
          },
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is SignInLoading) {
                return SizedBox(
                  height: 150,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.blueAccent,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Authenticating...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Authenticating',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 10),
                    CustomForm(
                      hintText: 'Email',
                      controller: email,
                      validitor: validateEmail,
                      secure: false,
                      fixed: false,
                    ),
                    SizedBox(height: 10),
                    CustomForm(
                      hintText: 'Password',
                      controller: password,
                      keyType: true,
                      validitor: validatePassword,
                      secure: true,
                      fixed: false,
                    ),
                    SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        CustomButton(
                          text: 'Save',
                          onPressed: () async {
                            if (_formKey.currentState?.validate() ?? false) {
                              bool isConnected =
                                  await _checkInternetConnection();
                              if (!isConnected) {
                                showCustomSnackBar(context,
                                    'No Internet connection. Please try again later.',
                                    isError: true, isSign: true);
                                return;
                              }
                            }
                            context.read<AuthBloc>().add(
                                  AuthLoginRequested(
                                    email.text,
                                    password.text,
                                  ),
                                );
                          },
                        ),
                        CustomButton(
                          text: 'Back',
                          onPressed: () {
                            // Close the dialog if Back is clicked
                            Navigator.of(context).pop();
                          },
                        )
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );

  // Return whether the login was successful
  return loginSuccessful;
}

Future<bool> _checkInternetConnection() async {
  var connectivityResult = await (Connectivity().checkConnectivity());
  return connectivityResult != ConnectivityResult.none;
}

void waitingToSave(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false, // Prevent dismissing the dialog
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        content: Row(
          children: [
            CircularProgressIndicator(
              color: PrimaryColors.mainColor,
            ),
            SizedBox(width: 10),
            Text('  please wait...'),
          ],
        ),
      );
    },
  );
}

class NetworkUtil {
  static Future<bool> isConnectedToInternet() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult == ConnectivityResult.mobile ||
          connectivityResult == ConnectivityResult.wifi;
    } catch (e) {
      print("Error checking connectivity: $e");
      return false;
    }
  }
}
