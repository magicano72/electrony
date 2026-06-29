import 'dart:io';

import 'package:Electrony/custom/button.dart';
import 'package:Electrony/custom/snacbar.dart';
import 'package:Electrony/theming/colors.dart';
import 'package:Electrony/theming/style.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReusableEmailCollectorScreen extends StatefulWidget {
  final String title;
  final String hintText;
  final Function(List<String> emails, File pdfFile, bool isImage)
      onEmailsCollected;

  const ReusableEmailCollectorScreen({
    Key? key,
    required this.title,
    required this.hintText,
    required this.onEmailsCollected,
  }) : super(key: key);

  @override
  State<ReusableEmailCollectorScreen> createState() =>
      _ReusableEmailCollectorScreenState();
}

class _ReusableEmailCollectorScreenState
    extends State<ReusableEmailCollectorScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _emails = [];

  final RegExp emailRegExp =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  void _addEmail() {
    String input = _controller.text.trim();
    if (!emailRegExp.hasMatch(input)) {
      showCustomSnackBar(context, 'Please enter a valid email', isError: true);
    } else if (_emails.contains(input)) {
      showCustomSnackBar(context, 'This email is already added', isError: true);
    } else {
      setState(() {
        _emails.add(input);
        _controller.clear();
      });
    }
  }

  void _removeEmail(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PrimaryColors.bluegray50,
        title: Text("Are you sure?", style: textStyleVersion2()),
        content: Text("Do you want to delete this user?",
            style: textStyleVersion2(color: Colors.black54, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: textStyleVersion2(fontSize: 16)),
          ),
          TextButton(
            onPressed: () {
              setState(() => _emails.removeAt(index));
              Navigator.pop(context);
            },
            child: Text("Delete",
                style:
                    textStyleVersion2(fontSize: 16, color: Color(0xff3F90C3))),
          ),
        ],
      ),
    );
  }

  Future<String?> _getPdfFilePath() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('pdfFilePath');
  }

  Future<void> _handleSubmit() async {
    if (_emails.isEmpty) {
      showCustomSnackBar(context, 'Please add at least one user',
          isError: true);
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    final isConnected = connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.mobile);

    if (!isConnected) {
      showCustomSnackBar(context, 'No internet connection.', isError: true);
      return;
    }

    final filePath = await _getPdfFilePath();
    if (filePath == null) {
      showCustomSnackBar(context, 'No PDF selected.', isError: true);
      return;
    }

    final file = File(filePath);
    final isImage = filePath.endsWith('png') ||
        filePath.endsWith('jpg') ||
        filePath.endsWith('jpeg');

    widget.onEmailsCollected(_emails, file, isImage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text(widget.title,
            style: textStyle("Poppins", 22, Colors.black, FontWeight.w500)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                hintText: widget.hintText,
                hintStyle: textStyle(
                    "Poppins", 16, Colors.grey.shade600, FontWeight.w400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(Icons.add, color: PrimaryColors.mainColor),
                  onPressed: _addEmail,
                ),
              ),
            ),
            SizedBox(height: 10.h),
            Expanded(
              child: ListView.builder(
                itemCount: _emails.length,
                itemBuilder: (context, index) => Card(
                  elevation: 2,
                  color: const Color(0xffF0F4F8).withOpacity(0.1),
                  shadowColor: Colors.grey.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xff3F90C3),
                        child: Text('R${index + 1}',
                            style: textStyle(
                                "Poppins", 16, Colors.white, FontWeight.bold)),
                      ),
                      title: Text(
                        _emails[index],
                        style: textStyle(
                            "Poppins", 16, Colors.black45, FontWeight.w500),
                      ),
                      trailing: InkWell(
                        onTap: () => _removeEmail(index),
                        child: Image.asset('assets/mdi_bin-outline.png',
                            height: 30.h, width: 30.w),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: CustomAuthButton(
                  text: 'Save and continue', onPressed: _handleSubmit),
            ),
            SizedBox(height: 15.h),
          ],
        ),
      ),
    );
  }
}
