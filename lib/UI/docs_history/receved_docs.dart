import 'dart:io';

import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/Helper/image_to_pdf.dart'; // Add this import
import 'package:Electrony/Helper/important_fun.dart';
import 'package:Electrony/Helper/pdf_creator.dart';
import 'package:Electrony/Theming/colors.dart';
import 'package:Electrony/UI/pdf_viewer/received_docs_pdfViewer.dart';
import 'package:Electrony/models/sign_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:page_transition/page_transition.dart';
import 'package:path_provider/path_provider.dart';

class ReceivedDocs extends StatefulWidget {
  const ReceivedDocs({
    Key? key,
    required this.pdfNames,
    required this.pdfUrls,
    required this.createTime,
  }) : super(key: key);

  final List<String> pdfNames;
  final List<String> pdfUrls;
  final List<String> createTime;

  @override
  State<ReceivedDocs> createState() => _ReceivedDocsState();
}

class _ReceivedDocsState extends State<ReceivedDocs> {
  Future<List<SignatureData>> futureSignatures =
      Future.value([]); // Initialize with an empty list
  List<String> pdfUrls = [];
  List<String> fileIds = [];
  List<String> createTime = [];
  List<int> id = [];
  List<String> pdfName = [];
  List<String> filteredPdfName = [];
  List<String> filteredPdfUrls = [];
  List<String> filteredCreateTime = [];
  bool isLoading = true;
  bool hasInternet = true;
  String searchQuery = "";
  bool _isMyDocsSelected = true; // Track selected tab
  List<String> pdfStatus = [];
  String? _userEmail;
  int _currentPage = 1;
  bool _isFetchingData = true;
  bool? _hasNewSignature = false;
  File? _signedPdfFile;
  final PDFCreator _pdfCreator = PDFCreator();
  final ImageToPDF _imageToPDF = ImageToPDF(); // Add this line

  void initState() {
    super.initState();
    _fetchData();
    loadUserEmail();
  }

  Future<void> loadUserEmail() async {
    try {
      final userProfile = await authApiService.getUserProfile();

      if (mounted) {
        setState(() {
          _userEmail = userProfile["email"] ?? 'No email available';
        });
      }
    } catch (e) {
      print("Error loading profile: $e");
    }
  }

  Future<List<SignatureData>> fetchSignatureData() async {
    try {
      final response = await http.get(Uri.parse(
          'http://139.59.134.100:8055/items/docs?fields=user_id.email,status,created_at,id,created_file.id,created_file.title,created_file.filename_download,signer.signer_id.*'));

      if (response.statusCode == 200) {
        List<SignatureData> documents = parseSignatureData(response.body);

        String? token = await authApiService.getToken();
        if (token == null) throw Exception("Token is null");

        final userId = JwtDecoder.decode(token)['id'];
        if (userId == null)
          throw Exception("Failed to extract user ID from token.");

        await Future.delayed(Duration(seconds: 1));
        await Future.wait([
          Future(() {
            documents = documents.where((doc) {
              return doc.creatorEmail != _userEmail &&
                  doc.signers
                      .any((signer) => signer.contriputerEmail == _userEmail);
            }).toList();
          }),
          Future(() {
            documents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          })
        ]);

        await Future.delayed(Duration(seconds: 1));

        print("Fetched documents: ${documents.length}");
        for (var doc in documents) {
          print("Document ID: ${doc.id}, Title: ${doc.createdFile.title}");
        }

        pdfUrls = documents.map((doc) => doc.createdFile.id ?? '').toList();
        fileIds = documents.map((doc) => doc.createdFile.id ?? '').toList();
        createTime =
            documents.map((doc) => doc.createdAt?.toString() ?? '').toList();
        id = documents.map((doc) => doc.id).toList();
        pdfName = documents.map((doc) => doc.createdFile.title ?? '').toList();
        pdfStatus = documents.map((doc) => doc.status ?? '').toList();

        filteredPdfName = List.from(pdfName);
        filteredPdfUrls = List.from(pdfUrls);
        filteredCreateTime = List.from(createTime);

        return documents;
      } else {
        throw Exception('Failed to load signature data');
      }
    } on Exception catch (e) {
      print('Failed to load signature data: $e');
      throw Exception('Failed to load signature data: $e');
    }
  }

  void _filterDocuments(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredPdfName = List.from(pdfName);
        filteredPdfUrls = List.from(pdfUrls);
        filteredCreateTime = List.from(createTime);
      } else {
        filteredPdfName = [];
        filteredPdfUrls = [];
        filteredCreateTime = [];
        for (int i = 0; i < pdfName.length; i++) {
          if (pdfName[i].toLowerCase().contains(query.toLowerCase())) {
            filteredPdfName.add(pdfName[i]);
            filteredPdfUrls.add(pdfUrls[i]);
            filteredCreateTime.add(createTime[i]);
          }
        }
      }
    });
  }

  Future<void> _fetchData() async {
    setState(() {
      _isFetchingData = true;
    });

    try {
      futureSignatures = fetchSignatureData();
      await futureSignatures;
      if (mounted) {
        setState(() {
          _isFetchingData = false;
          print("Data fetched successfully");
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isFetchingData = false;
          print("Error fetching data: $error");
        });
      }
    }
  }

  void previewSignedImage(BuildContext context, String documentId, String name,
      List<SignatureData> data, String isDraft) {
    final pdfUrl = 'http://139.59.134.100:8055/assets/$documentId';
    print(documentId);
    Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.fade,
        child: ReceivedDocsPdfviewer(
          pdfUrl: pdfUrl,
          isImage: true,
          isShared: true,
          isMe: false,
          isDrafted: isDraft,
          meAndOthers: true,
          name: name,
          futureSignatures: data,
        ),
      ),
    ).then((_) {
      _fetchData(); // Refresh data when returning to the screen
    });
  }

  void previewSignedDocuments(BuildContext context, String documentId,
      String name, List<SignatureData> data, String isDraft) {
    final pdfUrl = 'http://139.59.134.100:8055/assets/$documentId';
    print(documentId);
    Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.fade,
        child: ReceivedDocsPdfviewer(
            pdfUrl: pdfUrl,
            isImage: false,
            isShared: true,
            meAndOthers: true,
            isDrafted: isDraft,
            name: name,
            isMe: false,
            futureSignatures: data),
      ),
    ).then((_) {
      _fetchData(); // Refresh data when returning to the screen
    });
  }

  Future<void> _downloadFile(
      String pdfUrl, String pdfName, List<SignModel> signElements) async {
    waitingToSave(context);
    try {
      final response = await http
          .get(Uri.parse('http://139.59.134.100:8055/assets/$pdfUrl'));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final tempFilePath = '${tempDir.path}/$pdfName';

        final file = File(tempFilePath);
        await file.writeAsBytes(response.bodyBytes);
        print(tempFilePath);
        print(response.bodyBytes);

        bool isImage = pdfName.endsWith('png') ||
            pdfName.endsWith('jpg') ||
            pdfName.endsWith('jpeg');

        if (isImage) {
          // Convert image to PDF
          await _imageToPDF.loadImage(response.bodyBytes);
          await _imageToPDF.addElements(signElements);
          final pdfFile = await _imageToPDF.savePDF(pdfName.split('.').first);
          showCustomSnackBar(context, 'File downloaded successfully');
        } else {
          // Load the existing PDF
          await _pdfCreator.loadExistingPdf(response.bodyBytes);

          // Add elements to the PDF
          await _pdfCreator.addElements(signElements);

          final signedPdfFile =
              await _pdfCreator.savePDF(pdfName.split('.').first);
          showCustomSnackBar(context, 'File downloaded successfully');
        }
      } else {
        throw Exception("Failed to download file");
      }
    } catch (e) {
      print("Error downloading file: $e");
      showCustomSnackBar(context, 'Error downloading file', isError: true);
    } finally {
      Navigator.pop(context);
    }
  }

  void _shareDocument(
      String pdfUrl, String pdfName, List<SignModel> signElements) async {
    bool isConnected = await NetworkUtil.isConnectedToInternet();

    if (!isConnected) {
      showCustomSnackBar(
        context,
        'No internet connection. Please check your network.',
        isError: true,
      );
      return;
    }

    try {
      final response = await http
          .get(Uri.parse('http://139.59.134.100:8055/assets/$pdfUrl'));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final tempFilePath = '${tempDir.path}/$pdfName';

        final file = File(tempFilePath);
        await file.writeAsBytes(response.bodyBytes);

        bool isImage = pdfName.endsWith('png') ||
            pdfName.endsWith('jpg') ||
            pdfName.endsWith('jpeg');

        if (isImage) {
          // Convert image to PDF
          await _imageToPDF.loadImage(response.bodyBytes);
          await _imageToPDF.addElements(signElements);
          final pdfFile = await _imageToPDF.savePDF(pdfName.split('.').first);
          await _imageToPDF.sharePDF(pdfFile);
        } else {
          // Load the existing PDF
          await _pdfCreator.loadExistingPdf(response.bodyBytes);

          // Add elements to the PDF
          await _pdfCreator.addElements(signElements);

          final signedPdfFile =
              await _pdfCreator.savePDF(pdfName.split('.').first);
          await _pdfCreator.sharePDF(signedPdfFile);
        }
      } else {
        throw Exception("Failed to download file");
      }
    } catch (e) {
      print("Error sharing document: $e");
      showCustomSnackBar(context, 'Error sharing document', isError: true);
    }
  }

  Future<List<SignModel>> _getSignElementsForDocument(int documentId) async {
    final signatures = await futureSignatures;
    List<SignModel> signElements = [];
    for (var signatureData in signatures) {
      if (signatureData.id == documentId) {
        for (var signer in signatureData.signers) {
          signElements.add(SignModel(
            signId: signer.id,
            xOffset: signer.xOffset,
            yOffset: signer.yOffset,
            contributorEmail: signer.contriputerEmail,
            signatureText: signer.sign,
            currentPage: signer.currentPage,
            type: SignType.values
                .firstWhere((e) => e.toString() == 'SignType.${signer.type}'),
            signatureId: signer.signatureId,
          ));
        }
      }
    }
    return signElements;
  }

  void _showDeleteConfirmationDialog(String documentId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: PrimaryColors.bluegray50,
          title: Text("Delete Document"),
          content: Text("Are you sure you want to delete this document?"),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Cancel", style: TextStyle(color: Colors.black87)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await authApiService.deleteSignatureDataDocument(documentId);
                setState(() {
                  futureSignatures = fetchSignatureData(); // Refresh the list
                });
              },
              child: Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showOptionsBottomSheet(
      BuildContext context, int documentId, String pdfUrl, String pdfName) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmationDialog(documentId.toString());
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.download, color: Colors.blue),
                title: Text('Download'),
                onTap: () async {
                  Navigator.pop(context);
                  final signElements =
                      await _getSignElementsForDocument(documentId);
                  await _downloadFile(pdfUrl, pdfName, signElements);
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.share, color: Colors.green),
                title: Text('Share'),
                onTap: () async {
                  Navigator.pop(context);
                  final signElements =
                      await _getSignElementsForDocument(documentId);
                  _shareDocument(pdfUrl, pdfName, signElements);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SignatureData>>(
      future: futureSignatures,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitFadingCircle(
                color: Colors.blue,
                size: 50.0,
              ),
              SizedBox(height: 20),
              Text(
                'Loading, please wait...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ));
        } else if (snapshot.hasError) {
          print(snapshot.error);
          return Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitFadingCircle(
                color: Colors.blue,
                size: 50.0,
              ),
              SizedBox(height: 20),
              Text(
                'Loading, please wait...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description,
                    size: 40,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No documents yet.',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final userDocuments = snapshot.data!.toList();
        print("User documents count: ${userDocuments.length}");

        if (userDocuments.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description,
                    size: 40,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No documents yet.',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: userDocuments.length,
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemBuilder: (context, index) {
            final signatureData = userDocuments[index];
            final pdfUrl = signatureData.createdFile.id;
            final pdfName = signatureData.createdFile.title;
            final createTime = signatureData.createdAt.toString();
            bool isImage = signatureData.createdFile.filename_download
                    .endsWith('png') ||
                signatureData.createdFile.filename_download.endsWith('jpg') ||
                signatureData.createdFile.filename_download.endsWith('jpeg');
            DateTime utcDate = DateTime.parse(createTime).toUtc();
            DateTime egyptTime = utcDate.add(Duration(hours: 4));
            String formattedDate =
                DateFormat('dd-MM-yyyy  HH:mm').format(egyptTime);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () {
                  if (isImage) {
                    previewSignedImage(context, pdfUrl, pdfName,
                        [signatureData], signatureData.status!);
                  } else {
                    previewSignedDocuments(context, pdfUrl, pdfName,
                        [signatureData], signatureData.status!);
                  }
                },
                child: Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 4,
                  shadowColor: Colors.grey.withOpacity(0.3),
                  child: signatureData.status != DocumentStatus.Draft.name
                      ? ListTile(
                          contentPadding: EdgeInsets.all(12),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.blueAccent.withOpacity(0.2),
                            child: Icon(
                              isImage ? Icons.image : Icons.picture_as_pdf,
                              color: isImage ? Colors.blue : Colors.red,
                              size: 30,
                            ),
                          ),
                          title: Text(
                            pdfName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      "Created on ${formattedDate} by ${signatureData.creatorEmail} \n",
                                  style: TextStyle(
                                    color: Colors.black,
                                  ),
                                ),
                                WidgetSpan(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: signatureData.signers.any(
                                                    (signer) =>
                                                        signer.status ==
                                                            'Submitted' &&
                                                        signer.contriputerEmail ==
                                                            _userEmail)
                                                ? Colors.green
                                                : Colors.deepOrange,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          signatureData.signers
                                              .firstWhere((signer) =>
                                                  signer.contriputerEmail ==
                                                  _userEmail)
                                              .status,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: signatureData.signers.any(
                                                    (signer) =>
                                                        signer.status ==
                                                            'Submitted' &&
                                                        signer.contriputerEmail ==
                                                            _userEmail)
                                                ? Colors.green
                                                : Colors.deepOrange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.more_vert, color: Colors.black),
                            onPressed: () => _showOptionsBottomSheet(
                                context,
                                signatureData.id,
                                pdfUrl,
                                signatureData.createdFile.filename_download),
                          ),
                        )
                      : null,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
