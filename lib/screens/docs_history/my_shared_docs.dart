import 'dart:io';

import 'package:Electrony/Custom/search_view.dart';
import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/custom/auth_text_form.dart';
import 'package:Electrony/custom/shimmer_loading.dart';
import 'package:Electrony/helper/image_to_pdf.dart'; // Add this import
import 'package:Electrony/helper/important_fun.dart';
import 'package:Electrony/helper/pdf_creator.dart';
import 'package:Electrony/helper/utils.dart';
import 'package:Electrony/models/sign_model.dart';
import 'package:Electrony/networking/api_services.dart';
import 'package:Electrony/screens/pdf_viewer/shared_docs_pdfViewer.dart';
import 'package:Electrony/theming/colors.dart';
import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:page_transition/page_transition.dart';
import 'package:path_provider/path_provider.dart';

import '../dashboard/dashboard.dart';

class MySharedDocs extends StatefulWidget {
  MySharedDocs({
    Key? key,
  }) : super(key: key);

  @override
  State<MySharedDocs> createState() => _MySharedDocsState();
}

class _MySharedDocsState extends State<MySharedDocs> {
  Future<List<SignatureData>> futureSignatures =
      Future.value([]); // Initialize with an empty list
  List<String> pdfUrls = [];
  List<String> pdfStatus = [];
  List<String> fileIds = [];
  List<String> createTime = [];
  List<int> id = [];
  List<String> pdfName = [];

  bool isLoading = true;
  bool hasInternet = true;
  String searchQuery = "";

  String? _userEmail;

  bool isFetchingData = false;

  final apiService = AuthApiService(baseUrl: dotenv.env['API_BASE_URL'] ?? '');
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
      final token = await apiService.getValidToken();
      final response = await http.get(Uri.parse(
          '${dotenv.env['API_BASE_URL']}/items/docs?fields=user_id.email,status,created_at,id,created_file.id,created_file.title,created_file.filename_download,signer.signer_id.*'));

      if (response.statusCode == 200) {
        List<SignatureData> documents = parseSignatureData(response.body);

        final userId = JwtDecoder.decode(token)['id'];
        if (userId == null)
          throw Exception("Failed to extract user ID from token.");
        await Future.delayed(Duration(microseconds: 900));
        await Future.wait([
          Future(() {
            documents = documents.where((doc) {
              return doc.creatorEmail == _userEmail &&
                  doc.signers.any((signer) =>
                      signer.userId == userId &&
                      signer.contriputerEmail != _userEmail);
            }).toList();
          }),
          Future(() {
            documents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          })
        ]);

        await Future.delayed(Duration(microseconds: 900));

        print("Fetched documents: ${documents.length}");
        for (var doc in documents) {
          print(doc.status);
        }
        fileIds = documents.map((doc) => doc.createdFile.id ?? '').toList();
        createTime =
            documents.map((doc) => doc.createdAt?.toString() ?? '').toList();
        id = documents.map((doc) => doc.id).toList();
        pdfName = documents.map((doc) => doc.createdFile.title ?? '').toList();
        pdfStatus = documents.map((doc) => doc.status ?? '').toList();

        return documents;
      } else {
        throw Exception('Failed to load signature data');
      }
    } on Exception catch (e) {
      throw Exception('Failed to load signature data: $e');
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      isFetchingData = true;
    });

    try {
      futureSignatures = fetchSignatureData();
      await futureSignatures;
      if (mounted) {
        setState(() {
          isFetchingData = false;
          print("Data fetched successfully");
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          isFetchingData = false;
          print("Error fetching data: $error");
        });
      }
    }
  }

  void previewSignedImage(BuildContext context, String documentId, String name,
      List<SignatureData> data, String isDraft) {
    final pdfUrl = '${dotenv.env['API_BASE_URL']}/assets/$documentId';
    print(documentId);
    Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.fade,
        child: Material(
          child: SharedDocsPdfViewer(
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
      ),
    );
  }

  void previewSignedDocuments(BuildContext context, String documentId,
      String name, List<SignatureData> data, String isDraft) {
    final pdfUrl = '${dotenv.env['API_BASE_URL']}/assets/$documentId';
    print(documentId);
    Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.fade,
        child: Material(
          child: SharedDocsPdfViewer(
              pdfUrl: pdfUrl,
              isImage: false,
              isShared: true,
              meAndOthers: true,
              name: name,
              isDrafted: isDraft,
              isMe: false,
              futureSignatures: data),
        ),
      ),
    );
  }

  void _showRenameDialog(String documentId, String currentName) {
    final TextEditingController _renameController =
        TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: PrimaryColors.bluegray50,
          title: Text("Rename Document", style: textStyleVersion2()),
          content: CustomForm(
            hintText: 'Email or phone',
            controller: _renameController,
            keyType: true,
            secure: false,
            fixed: false,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Cancel", style: TextStyle(color: Colors.black87)),
            ),
            TextButton(
              onPressed: () async {
                final newName = _renameController.text.trim();
                if (newName.isNotEmpty) {
                  try {
                    await authApiService.renameDocument(documentId, newName);
                    Navigator.pop(dialogContext);
                    _fetchData(); // Refresh the document list
                    if (mounted) {
                      showCustomSnackBar(
                          context, "Document renamed successfully");
                    }
                  } catch (e) {
                    print("Error renaming document: $e");
                    if (mounted) {
                      showCustomSnackBar(context, "Failed to rename document",
                          isError: true);
                    }
                  }
                }
              },
              child: Text("Rename", style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadFile(
      String pdfUrl, String pdfName, List<SignModel> signElements) async {
    waitingToSave(context);
    try {
      final response = await http
          .get(Uri.parse('${dotenv.env['API_BASE_URL']}/assets/$pdfUrl'));
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
    waitingToSave(context);
    try {
      final response = await http
          .get(Uri.parse('${dotenv.env['API_BASE_URL']}/assets/$pdfUrl'));
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
    } finally {
      Navigator.pop(context);
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
            xOffset: signer.xOffset ?? 0.0,
            yOffset: signer.yOffset ?? 0.0,
            contributorEmail: signer.contriputerEmail ?? '',
            signatureText: signer.sign ?? '',
            currentPage: signer.currentPage ?? 1,
            type: SignType.values
                .firstWhere((e) => e.toString() == 'SignType.${signer.type}'),
            signatureId: signer.signatureId ?? '',
          ));
        }
      }
    }
    return signElements;
  }

  void _showDeleteConfirmationDialog(String documentId) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: PrimaryColors.bluegray50,
          title: Text("Delete Document", style: textStyleVersion2()),
          content: Text("Are you sure you want to delete this document?",
              style: textStyleVersion2(
                fontWeight: FontWeight.w400,
                fontSize: 16,
              )),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text("Cancel", style: TextStyle(color: Colors.black87)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await authApiService.deleteSignatureDataDocument(documentId);

                  if (!mounted) return;
                  setState(() {
                    futureSignatures = futureSignatures.then((currentDocs) {
                      return currentDocs
                          .where((doc) => doc.id.toString() != documentId)
                          .toList();
                    });
                  });

                  if (mounted) {
                    showCustomSnackBar(
                        context, "Document deleted successfully");
                  }
                } catch (e) {
                  print("Error deleting document: $e");
                  if (mounted) {
                    showCustomSnackBar(context, "Failed to delete document",
                        isError: true);
                  }
                }
              },
              child: Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void showOptionsBottomSheet(
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
                leading: Icon(Icons.edit, color: Colors.blue),
                title: Text('Rename', style: textStyleVersion2()),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(documentId.toString(), pdfName);
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: textStyleVersion2()),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmationDialog(documentId.toString());
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.download, color: Colors.blue),
                title: Text('Download', style: textStyleVersion2()),
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
                title: Text('Share', style: textStyleVersion2()),
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

  void _filterDocuments(String query) {
    setState(() {
      searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
            child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Row(
                children: [
                  IconButton(
                      onPressed: () {
                        Navigator.pop(
                            context,
                            PageTransition(
                                type: PageTransitionType.fade,
                                child: DashboardScreen()));
                      },
                      icon: Icon(Icons.arrow_back_ios_new)),
                  SizedBox(width: 10.w),
                  Container(
                    width: 320.w,
                    child: CustomSearchView(
                      prefix: Icon(Icons.search),
                      isDark: false,
                      onChanged: _filterDocuments,
                      width: double.infinity,
                      focusNode: FocusNode(),
                      hintText: "Search by document name",
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<SignatureData>>(
                future: futureSignatures,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ShimmerLoading();
                  } else if (snapshot.hasError) {
                    return const Center(
                      child: ShimmerLoading(),
                    );
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
                              color: PrimaryColors.mainColor,
                            ),
                            SizedBox(height: 12.w),
                            Text('No documents yet.',
                                style: textStyleVersion2(fontSize: 22)),
                          ],
                        ),
                      ),
                    );
                  }

                  final userDocuments = snapshot.data!.toList();
                  print("User documents count: ${userDocuments.length}");

                  return ListView.builder(
                    itemCount: userDocuments.length,
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    itemBuilder: (context, index) {
                      final signatureData = userDocuments[index];
                      final pdfName = signatureData.createdFile.title ?? '';
                      if (pdfName
                          .toLowerCase()
                          .contains(searchQuery.toLowerCase())) {
                        final pdfUrl = signatureData.createdFile.id ?? '';
                        final createTime =
                            signatureData.createdAt?.toString() ?? '';
                        bool isImage = signatureData
                                .createdFile.filename_download
                                .endsWith('png') ||
                            signatureData.createdFile.filename_download
                                .endsWith('jpg') ||
                            signatureData.createdFile.filename_download
                                .endsWith('jpeg');
                        DateTime utcDate = DateTime.parse(createTime).toUtc();
                        DateTime egyptTime = utcDate.add(Duration(hours: 6));
                        String formattedDate =
                            DateFormat('dd-MM-yyyy  HH:mm').format(egyptTime);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
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
                              color: Color(0xffF0F4F8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              shadowColor: Colors.grey.withOpacity(0.2),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    // Document icon
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isImage
                                            ? Colors.blue.withOpacity(0.1)
                                            : Colors.red.withOpacity(0.1),
                                      ),
                                      child: Icon(
                                        isImage
                                            ? Icons.image
                                            : Icons.picture_as_pdf,
                                        color:
                                            isImage ? Colors.blue : Colors.red,
                                        size: 22,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    // Document details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pdfName,
                                            style: textStyleVersion2(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            "From: ${signatureData.creatorEmail}",
                                            style: textStyleVersion2(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                          SizedBox(height: 6),
                                          Row(
                                            children: [
                                              // Status indicator
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: getStatusColor(
                                                          signatureData.status!)
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: getStatusColor(
                                                            signatureData
                                                                .status!),
                                                      ),
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      signatureData.status!,
                                                      style: textStyleVersion2(
                                                        fontSize: 12,
                                                        color: getStatusColor(
                                                            signatureData
                                                                .status!),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Spacer(),
                                              Text(
                                                formattedDate,
                                                style: textStyleVersion2(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Trailing menu
                                    IconButton(
                                      icon: Icon(Icons.more_vert,
                                          size: 20, color: Colors.black),
                                      padding: EdgeInsets.zero,
                                      constraints: BoxConstraints(),
                                      onPressed: () => showOptionsBottomSheet(
                                        context,
                                        signatureData.id,
                                        pdfUrl,
                                        signatureData
                                            .createdFile.filename_download,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      } else {
                        return Container();
                      }
                    },
                  );
                },
              ),
            ),
          ],
        )));
  }
}
