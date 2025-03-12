// ignore_for_file: unused_local_variable

import 'dart:io';

import 'package:Electrony/Custom/button.dart';
import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/Theming/colors.dart';
import 'package:Electrony/Theming/style.dart';
import 'package:Electrony/UI/sign_flow/mark_signers_places.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Signers extends StatefulWidget {
  final VoidCallback? onReturnToPreview;
  const Signers({super.key, this.onReturnToPreview});

  @override
  State<Signers> createState() => _SignersState();
}

class _SignersState extends State<Signers> {
  // String? _userEmail;
  // Future<void> loadUserEmail() async {
  //   try {
  //     final userProfile = await authApiService.getUserProfile();
  //     print("User Profile: $userProfile");

  //     // Debug print to check if the email field exists
  //     print("User Email: ${userProfile["email"]}");

  //     setState(() {
  //       _userEmail = userProfile["email"] ?? 'No email available';
  //     });
  //   } catch (e) {
  //     print("Error loading profile: $e");
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrimaryColors.bluegray50,
      body: SafeArea(
        child: Container(
            width: double.infinity,
            height: double.infinity,
            color: PrimaryColors.bluegray50,
            child: Column(
              children: [
                SizedBox(
                  height: 8.h,
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                SizedBox(
                  height: 30.h,
                ),
                InkWell(
                  onTap: widget.onReturnToPreview,
                  child: Card(
                    elevation: 2,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: ListTile(
                        leading: Image.asset(
                          'assets/images/person.png',
                          width: 45,
                          height: 45,
                        ),
                        title: Text('  Myself', style: Style.font20bold),
                        subtitle: Text(
                            '  If you need to sign a document\n  yourself'),
                        trailing: Icon(
                          Icons.arrow_forward_ios_outlined,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 8.h,
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                        context,
                        PageTransition(
                            type: PageTransitionType.fade,
                            child: DynamicCardPage()));
                  },
                  child: Card(
                    elevation: 2,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: ListTile(
                        leading: Image.asset(
                          'assets/images/group.png',
                          width: 45,
                          height: 45,
                          color: Colors.blueAccent,
                        ),
                        title: Text('  Myself and Others',
                            style: Style.font20bold),
                        subtitle: Text(
                            '  If you and others need to sign a\n  document'),
                        trailing: Icon(
                          Icons.arrow_forward_ios_outlined,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                )
              ],
            )),
      ),
    );
  }
}

class DynamicCardPage extends StatefulWidget {
  @override
  _DynamicCardPageState createState() => _DynamicCardPageState();
}

class _DynamicCardPageState extends State<DynamicCardPage> {
  TextEditingController _controller = TextEditingController();
  List<String> _cardTitles = [];

  final emailRegExp =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  void _createCard() {
    String input = _controller.text.trim();

    if (!emailRegExp.hasMatch(input)) {
      showCustomSnackBar(context, 'Please enter a valid email', isError: true);
    } else if (_cardTitles.contains(input)) {
      showCustomSnackBar(context, 'This email is already added', isError: true);
    } else {
      setState(() {
        _cardTitles.add(input);
        print(_cardTitles);
        _controller.clear();
      });
    }
  }

  void _deleteCard(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: PrimaryColors.bluegray50,
          title: Text("Are you sure?"),
          content: Text("Do you want to delete this user?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Cancel", style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _cardTitles.removeAt(index);
                });
                Navigator.of(context).pop();
              },
              child: Text("Delete", style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  List orders = ['Name', 'Signature', 'Date'];
  Future<String?> _getPdfFilePath() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    print(prefs.getString('pdfFilePath'));
    return prefs.getString('pdfFilePath');
  }

  Future<String?> _getPdfFileName() async {
    SharedPreferences imageName = await SharedPreferences.getInstance();
    print(imageName.getString('pdfFileName'));
    return imageName.getString('pdfFileName');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                children: [
                  SizedBox(
                    height: 10,
                  ),
                  Container(
                    width: double.infinity,
                    height: 40,
                    color: Colors.white,
                    child: Row(
                      // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: Icon(Icons.arrow_back_ios),
                        ),
                        SizedBox(width: 40),
                        Text(
                          "Who needs to sign?",
                          style: Style.font23bold
                              .copyWith(color: PrimaryColors.mainColor),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 15),
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: PrimaryColors.mainColor.withOpacity(.1),
                      hintText: 'Enter Recipient email',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.add, color: PrimaryColors.mainColor),
                        onPressed: _createCard,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            //SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _cardTitles.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () {
                      // Handle tap on the card
                      print('Tapped on: ${_cardTitles[index]}');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: Card(
                        elevation: 4,
                        color: PrimaryColors.bluegray50,
                        shadowColor: Colors.grey.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: PrimaryColors.mainColor,
                              child: Text(
                                'R${index + 1}',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              _cardTitles[index],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: PrimaryColors.mainColor,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _deleteCard(index),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CustomButton(
                text: 'Save and continue',
                onPressed: () async {
                  if (_cardTitles.isEmpty) {
                    showCustomSnackBar(context, 'Please add at least one user',
                        isError: true);
                    return;
                  }
                  String? filePath = await _getPdfFilePath();
                  String? fileName = await _getPdfFileName();
                  File pdfFile = File(filePath!);

                  if (filePath.endsWith('png') ||
                      filePath.endsWith('jpg') ||
                      filePath.endsWith('jpeg')) {
                    Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.fade,
                        child: MarkSignersPlaces(
                          pdfFile: pdfFile,
                          isImage: true,
                          signers: _cardTitles,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      PageTransition(
                          type: PageTransitionType.fade,
                          child: MarkSignersPlaces(
                            pdfFile: pdfFile,
                            signers: _cardTitles,
                            isImage: false,
                          )),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
