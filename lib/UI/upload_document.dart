import 'dart:io';

import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/Helper/important_fun.dart';
import 'package:Electrony/Networking/api_services.dart';
import 'package:Electrony/Theming/style.dart';
import 'package:Electrony/UI/sign_flow/only_me_sign.dart';
import 'package:Electrony/UI/sign_flow/signares.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:page_transition/page_transition.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

File? _pdfFile;

String? pdfFileName;

class PdfUploadAndSignScreen extends StatefulWidget {
  @override
  _PdfUploadAndSignScreenState createState() => _PdfUploadAndSignScreenState();
}

class _PdfUploadAndSignScreenState extends State<PdfUploadAndSignScreen> {
  final TextEditingController textEditingController = TextEditingController();

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

  final authApiService = AuthApiService(baseUrl: 'http://139.59.134.100:8055');

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
    FilePickerResult? result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'docx']);

    if (result != null || result?.files.single.path != null) {
      String filePath = result!.files.single.path!;

      SharedPreferences prefs = await SharedPreferences.getInstance();

      prefs.setString('pdfFilePath', filePath);
      setState(() {
        _pdfFile = File(filePath);
        pdfFileName = path.basename(filePath);
        print(_pdfFile); // Extract only the file name
      });
    } else {
      showCustomSnackBar(context, 'No file selected.', isError: true);

      print('No file selected.');
      return;
    }

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
    waitingToSave(context);
    final authApiService =
        AuthApiService(baseUrl: 'http://139.59.134.100:8055');
    final documentFileIds =
        await authApiService.uploadOriginalDocuments([_pdfFile!]);
    await authApiService.saveOriginalDocumentRecords(documentFileIds);
    print("PDF uploaded and saved in backend successfully!");
    Navigator.of(context).pop();
  }

  Future<void> pickAndUploadImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      File imageFile = File(image.path);
      setState(() {
        imageFile = File(image.path);
        pdfFileName = path.basename(image.path);
        print(imageFile);
        print(pdfFileName);
      });
      SharedPreferences prefs = await SharedPreferences.getInstance();
      SharedPreferences imageName = await SharedPreferences.getInstance();
      prefs.setString('pdfFilePath', image.path);
      imageName.setString('pdfFileName', pdfFileName!);
      // Navigator.of(context).

      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Signers(onReturnToPreview: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OnlyMeSign(
                        pdfFile: _pdfFile!,
                        isImage: true,
                        signers: [_userEmail ?? ''],
                      ),
                    ),
                  );
                })),
      );
      waitingToSave(context);
      final authApiService =
          AuthApiService(baseUrl: 'http://139.59.134.100:8055');
      final documentFileIds =
          await authApiService.uploadOriginalDocuments([imageFile]);
      await authApiService.saveOriginalDocumentRecords(documentFileIds);
      print("PDF uploaded and saved in backend successfully!");
      Navigator.of(context).pop();
    } else {
      showCustomSnackBar(context, 'No image selected.', isError: true);
      print('No image selected.');
      return;
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
      showCustomSnackBar(context, 'Failed to load user profile', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w), // Add padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20.h),
            Center(
              child: Text(
                'Upload Document',
                style: Style.font23bold
                    .copyWith(fontSize: 22.sp), // Adaptive font size
              ),
            ),
            SizedBox(height: 25.h),
            _buildUploadCard(
              title: "Upload File",
              imagePath: 'assets/images/file.png',
              onTap: _pickPdf,
              isImage: false,
            ),
            SizedBox(height: 15.h),
            _buildUploadCard(
              title: "Upload Image",
              imagePath: 'assets/images/image-.png',
              onTap: pickAndUploadImage,
              isImage: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard(
      {required String title,
      required bool isImage,
      required String imagePath,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15), // Rounded corners
      splashColor: Colors.blue.withOpacity(0.2), // Tap effect
      highlightColor: Colors.blue.withOpacity(0.1),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 4,
        shadowColor: Colors.grey.withOpacity(0.3),
        child: Padding(
          padding: EdgeInsets.all(10.0),
          child: ListTile(
            leading: Image.asset(
              imagePath,
              width: 45,
              height: 45,
              color: isImage ? Colors.blueAccent : Colors.redAccent,
            ),
            title:
                Text(title, style: Style.font20bold.copyWith(fontSize: 18.sp)),
            trailing:
                Icon(Icons.arrow_forward_ios_outlined, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
