import 'dart:io';

import 'package:Electrony/custom/custom_card.dart';
import 'package:Electrony/helper/important_fun.dart';
import 'package:Electrony/networking/api_services.dart';
import 'package:Electrony/screens/sign_flow/only_me_sign.dart';
import 'package:Electrony/screens/sign_flow/signares.dart';
import 'package:Electrony/theming/style.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:page_transition/page_transition.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../dashboard/dashboard.dart';

File? _pdfFile;

String? pdfFileName;

class PdfUploadAndSignScreen extends StatefulWidget {
  @override
  _PdfUploadAndSignScreenState createState() => _PdfUploadAndSignScreenState();
}

class _PdfUploadAndSignScreenState extends State<PdfUploadAndSignScreen> {
  final TextEditingController textEditingController = TextEditingController();
  DateTime? lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _loadPdfFilePath();

    _loadUserProfile();
  }

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }

  final authApiService = AuthApiService(
      baseUrl: dotenv.env['API_BASE_URL'] ??
          ''); // Update to use centralized apiBaseUrl from environment variable

  Future<void> _loadPdfFilePath() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? filePath = prefs.getString('pdfFilePath');

    if (mounted) {
      if (filePath != null && File(filePath).existsSync())
        setState(() {
          _pdfFile = File(filePath);
          pdfFileName =
              path.basename(filePath); // Ensure file name is set correctly
        });
    } else {
      if (mounted)
        setState(() {
          _pdfFile = null;
          pdfFileName = null;
        });
    }
  }

  // Fetch signature IDs from the backend

  Future<void> _pickPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'docx']);

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;

        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setString('pdfFilePath', filePath);
        setState(() {
          _pdfFile = File(filePath);
          pdfFileName = path.basename(filePath);
        });
      } else {
        print('No file selected.');
        return;
      }

      waitingToSave(context);

      try {
        final documentFileIds = await authApiService.uploadFile([_pdfFile!]);
        await authApiService.saveOriginalDocumentRecords(documentFileIds);
        print("PDF uploaded and saved in backend successfully!");
        Navigator.of(context).pop(); // Remove loading dialog

        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => Signers(onReturnToPreview: () {
                    Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.fade,
                        child: OnlyMeSign(
                          pdfFile: _pdfFile!,
                          isImage: false,
                          signers: [_userEmail ?? ''],
                        ),
                      ),
                    );
                  })),
        );
      } catch (e) {
        Navigator.of(context).pop(); // Remove loading dialog
        if (e.toString().contains('Session expired')) {
          // Clear stored credentials
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.clear();

          // Show error dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: Colors.white,
                title: Text('Session Expired',
                    style: textStyle(
                      "Poppins",
                      20,
                      Color(0xff1B1B1B),
                      FontWeight.bold,
                    )),
                content: Text('Your session has expired. Please log in again.',
                    style: textStyle(
                      "Poppins",
                      16,
                      Color(0xff1B1B1B),
                      FontWeight.w400,
                    )),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                actionsPadding: EdgeInsets.only(right: 20),
                actions: <Widget>[
                  TextButton(
                    child: Text('OK',
                        style: textStyle(
                          "Poppins",
                          16,
                          Color(0xff1B1B1B),
                          FontWeight.w400,
                        )),
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Navigate to login screen
                      Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login', (Route<dynamic> route) => false);
                    },
                  ),
                ],
              );
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading file: ${e.toString()}')),
          );
        }
      }
    } catch (e) {
      print('Error picking or processing file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing file: ${e.toString()}')),
      );
    }
  }

  Future<void> pickAndUploadImage() async {
    try {
      final ImagePicker _picker = ImagePicker();
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (image != null) {
        File imageFile = File(image.path);
        setState(() {
          _pdfFile = imageFile;
          pdfFileName = path.basename(image.path);
        });

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('pdfFilePath', image.path);
        await prefs.setString('pdfFileName', pdfFileName!);

        waitingToSave(context);

        try {
          final documentFileIds = await authApiService.uploadFile([imageFile]);
          await authApiService.saveOriginalDocumentRecords(documentFileIds);
          Navigator.of(context).pop(); // Remove loading dialog

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Signers(onReturnToPreview: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OnlyMeSign(
                      pdfFile: imageFile,
                      isImage: true,
                      signers: [_userEmail ?? ''],
                    ),
                  ),
                );
              }),
            ),
          );
        } catch (e) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading image: ${e.toString()}')),
          );
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: ${e.toString()}')),
      );
    }
  }

  Future<void> scanDocument() async {
    try {
      final ImagePicker _picker = ImagePicker();
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (image != null) {
        File imageFile = File(image.path);
        setState(() {
          _pdfFile = imageFile;
          pdfFileName = path.basename(image.path);
        });

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('pdfFilePath', image.path);
        await prefs.setString('pdfFileName', pdfFileName!);

        waitingToSave(context);

        try {
          final documentFileIds = await authApiService.uploadFile([imageFile]);
          await authApiService.saveOriginalDocumentRecords(documentFileIds);
          Navigator.of(context).pop(); // Remove loading dialog

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Signers(onReturnToPreview: () {
                Navigator.push(
                  context,
                  PageTransition(
                    type: PageTransitionType.fade,
                    child: OnlyMeSign(
                      pdfFile: imageFile,
                      isImage: true,
                      signers: [_userEmail ?? ''],
                    ),
                  ),
                );
              }),
            ),
          );
        } catch (e) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Error uploading scanned document: ${e.toString()}')),
          );
        }
      }
    } catch (e) {
      print('Error scanning document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning document: ${e.toString()}')),
      );
    }
  }

  String? _userEmail;
  Future<void> _loadUserProfile() async {
    try {
      final userProfile = await authApiService.getUserProfile();
      print("User Profile: $userProfile"); // Log the entire user profile

      setState(() {
        _userEmail = userProfile['email'] ?? 'No email available';
        print(_userEmail);
      });
    } catch (e) {
      print("Error loading user profile: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool showBackButton = Navigator.of(context).canPop() &&
        ModalRoute.of(context)?.settings.arguments == 'fromMyDocs';

    return WillPopScope(
      onWillPop: () async {
        if (lastBackPressTime == null ||
            DateTime.now().difference(lastBackPressTime!) >
                Duration(seconds: 2)) {
          lastBackPressTime = DateTime.now();
          if (showBackButton) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacement(
              context,
              PageTransition(
                type: PageTransitionType.fade,
                child: DashboardScreen(),
              ),
            );
          }
          return false;
        }
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: showBackButton
              ? IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: Colors.black),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                )
              : null,
          title: Text(
            'Upload Document',
            style: textStyle(
              "Poppins",
              22,
              Color(0xff1B1B1B),
              FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w), // Add padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 25.h),
                customCard(
                  title: "Upload File",
                  imagePath: 'assets/ant-design_file-pdf-outlined.png',
                  onTap: _pickPdf,
                ),
                SizedBox(height: 15.h),
                customCard(
                  title: "Upload Image",
                  imagePath: 'assets/images/mdi-light_image.png',
                  onTap: pickAndUploadImage,
                ),
                SizedBox(height: 15.h),
                customCard(
                  title: "Scan File",
                  imagePath: 'assets/scan.png',
                  onTap: scanDocument,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
