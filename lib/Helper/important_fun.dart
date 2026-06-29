import 'package:Electrony/Custom/button.dart';
import 'package:Electrony/Custom/snacbar.dart';
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
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../networking/api_services.dart';

TextEditingController email = TextEditingController();

final authApiService =
    AuthApiService(baseUrl: dotenv.env['API_BASE_URL'] ?? '');

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
        child: BlocListener<MasterBloc, MasterState>(
          listener: (context, state) {
            if (state is CheckUserCredential) {
              loginSuccessful = true; // Set login as successful
              Navigator.of(context).pop(); // Close the dialog}
            }
          },
          child: BlocBuilder<MasterBloc, MasterState>(
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
                child: Form(
                  key: _formKey, // Add Form widget and assign the GlobalKey
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        state is SignInFailure
                            ? "Invalid password"
                            : 'Authenticating',
                        style: textStyle(
                          "Poppins",
                          18,
                          Colors.black,
                          FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 10),
                      CustomForm(
                        hintText: 'Email',
                        controller: email,
                        validitor: validateEmail,
                        secure: false,
                        fixed: true,
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
                            text: 'Back',
                            onPressed: () {
                              // Close the dialog if Back is clicked
                              Navigator.of(context).pop();
                            },
                          ),
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
                              context.read<MasterBloc>().add(
                                    CheckingUserCredential(
                                      email.text,
                                      password.text,
                                    ),
                                  );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
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
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        elevation: 6,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        content: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: PrimaryColors.mainColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Please wait...',
                style: textStyleVersion2(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
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

Future<bool> showSignatureConfirmationDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            actionsPadding: const EdgeInsets.only(bottom: 16, right: 16),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Confirm Submission',
                    style: textStyleVersion2(
                        fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
              ],
            ),
            content: Text(
              'Submitting this document will deduct 10 ECP from your account.\n\nDo you want to continue?',
              style: textStyleVersion2(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  textStyle: textStyleVersion2(fontWeight: FontWeight.bold),
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  textStyle: textStyleVersion2(fontWeight: FontWeight.bold),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      ) ??
      false;
}
