import 'dart:typed_data';

import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/Helper/important_fun.dart';
import 'package:Electrony/Networking/api_services.dart';
import 'package:Electrony/Theming/colors.dart';
import 'package:Electrony/Theming/style.dart';
import 'package:Electrony/UI/pdf_viewer/my_docs_pdfviewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;

class SignaturesListScreen extends StatefulWidget {
  @override
  _SignaturesListScreenState createState() => _SignaturesListScreenState();
}

class _SignaturesListScreenState extends State<SignaturesListScreen> {
  List<String> signatureUrls = [];
  List<String> fileIds = [];
  List<int> id = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSignatures();
  }

  void previewSignature(BuildContext context, String url) async {
    final fileType = await detectFileType(url);
    print("Detected file type: $fileType"); // Debug output

    if (fileType == 'application/pdf') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MyDocsPdfViewer(
            pdfUrl: url,
            isImage: false,
          ),
        ),
      );
    } else if (fileType == 'image/png') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImagePreviewScreen(imageUrl: url),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unsupported file format: $fileType")),
      );
    }
  }

  Future<String> detectFileType(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final Uint8List bytes = response.bodyBytes;

      // Check if it's a PDF by looking for "%PDF-" at the start
      if (bytes.length >= 4 &&
          bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46) {
        return 'application/pdf';
      }

      // Check if it's a PNG by looking for PNG signature bytes
      if (bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0D &&
          bytes[5] == 0x0A &&
          bytes[6] == 0x1A &&
          bytes[7] == 0x0A) {
        return 'image/png';
      }
    }
    return 'unknown';
  }

  Future<void> _fetchSignatures() async {
    AuthApiService apiService =
        AuthApiService(baseUrl: 'http://139.59.134.100:8055');

    try {
      id = await apiService.fetchSignatureIntIds();
      fileIds = await apiService.fetchSignatureIds();
      signatureUrls = await apiService.getSignatureUrls(fileIds);
    } catch (e) {
      print("Error fetching signatures: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _deleteSign(String fileId) async {
    AuthApiService apiService =
        AuthApiService(baseUrl: 'http://139.59.134.100:8055');

    try {
      int indexToRemove = fileIds.indexOf(fileId);
      // Delete the document with the specified fileId (now it's a String)
      await apiService.deleteSignature([id[indexToRemove]]);
      showCustomSnackBar(context, "Signature deleted successfully.");
      // Remove the document from the list
      setState(() {
        if (indexToRemove != -1) {
          fileIds.removeAt(indexToRemove);
          id.removeAt(indexToRemove);
          signatureUrls.removeAt(indexToRemove);
        }
      });
    } catch (e) {
      print("Error deleting document: $e");
      showCustomSnackBar(context, "Failed to delete document.", isError: true);
    }
  }

  void _showDeleteDialog(String fileId) async {
    bool isConnected = await NetworkUtil.isConnectedToInternet();

    if (!isConnected) {
      showCustomSnackBar(
        context,
        'No internet connection. Please check your network.',
        isError: true,
      );
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: PrimaryColors.bluegray50,
          title: Text("Delete Signature"),
          content: Text("Are you sure you want to delete this Signature ?"),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                "Cancel",
                style: TextStyle(color: Colors.black87),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteSign(fileId); // Delete the document if confirmed
              },
              child: Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrimaryColors.bluegray50,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_outlined),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        centerTitle: true,
        backgroundColor: PrimaryColors.bluegray50,
        title: Text('My Signature'),
      ),
      body: isLoading
          ? Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Use any spinner from flutter_spinkit
                    SpinKitFadingCircle(
                      color: Colors.blue,
                      size: 50.0,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Loading, please wait...',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : signatureUrls.isEmpty
              ? SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Text(
                                'No signature available ',
                                style: Style.font20Weight,
                              ),
                              Text(
                                'please login again to security',
                                style: Style.font17secondcolor,
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: ListView.builder(
                    itemCount: signatureUrls.length,
                    itemBuilder: (context, index) {
                      return Card(
                        color: Colors.white,
                        elevation: 3,
                        child: ListTile(
                          title: Text(
                            'Signature ${index + 1}',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold),
                          ),
                          onTap: () {
                            previewSignature(context, signatureUrls[index]);
                          },
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {
                              // Show a confirmation dialog before deleting
                              _showDeleteDialog(fileIds[index]);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class ImagePreviewScreen extends StatelessWidget {
  final String imageUrl;

  ImagePreviewScreen({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text("Signature Preview"),
      ),
      body: Center(
        child: Image.network(
          imageUrl,
          loadingBuilder: (context, child, progress) {
            return progress == null ? child : CircularProgressIndicator();
          },
          errorBuilder: (context, error, stackTrace) {
            return Text("Failed to load image");
          },
        ),
      ),
    );
  }
}
