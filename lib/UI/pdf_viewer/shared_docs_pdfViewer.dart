import 'dart:io';
import 'dart:typed_data';

import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/Helper/important_fun.dart';
import 'package:Electrony/Networking/api_services.dart';
import 'package:Electrony/Theming/colors.dart';
import 'package:Electrony/UI/sign_flow/mark_signers_places.dart';
import 'package:Electrony/models/sign_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class SharedDocsPdfViewer extends StatefulWidget {
  final String pdfUrl;
  final String? name;
  final bool? isImage;
  final bool? meAndOthers;
  final bool? isShared;
  final bool? isMe;
  final String? isDrafted;
  final List<SignatureData>? futureSignatures;

  SharedDocsPdfViewer({
    required this.pdfUrl,
    this.isImage,
    this.name,
    this.futureSignatures,
    this.meAndOthers,
    this.isShared,
    this.isMe,
    this.isDrafted,
  });

  @override
  _MySharedDocsPdfViewerState createState() => _MySharedDocsPdfViewerState();
}

class _MySharedDocsPdfViewerState extends State<SharedDocsPdfViewer> {
  final authApiService = AuthApiService(baseUrl: 'http://139.59.134.100:8055');

  Map<int, String> editedSigns = {}; // Stores updated text values
  Map<int, String> appliedSignatureImages =
      {}; // Stores selected signature image URLs
  List<String> _signatureUrls = []; // Stores URLs of saved signatures
  final PdfViewerController _pdfController = PdfViewerController();
  int currentPage = 1;
  Map<int, bool> showDeleteIcon = {}; // Track visibility of delete icons

  @override
  void initState() {
    super.initState();
    //  _replaceDateFields();
    _loadSignatures();
    loadUserEmail();
    loadUserId(); // Load userId
    _pdfController.addListener(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          currentPage = _pdfController.pageNumber ??
              1; // Update page number with null check
        });
      });
    });
  }

  String? _userEmail;
  String? userId; // Add userId variable

  Future<void> loadUserEmail() async {
    try {
      final userProfile = await authApiService.getUserProfile();
      print("User Profile: $userProfile");

      setState(() {
        _userEmail = userProfile['email'] ?? 'No email available';
      });
    } catch (e) {
      print("Error loading profile: $e");
    }
  }

  Future<void> loadUserId() async {
    try {
      final userProfile = await authApiService.getUserProfile();
      print("User Profile: $userProfile");

      setState(() {
        _userEmail = userProfile['email'] ?? 'No email available';
        userId = userProfile['id'] ?? 'No user ID available'; // Set userId
      });
    } catch (e) {
      print("Error loading profile: $e");
    }
  }

  void _replaceDateFields() {
    if (widget.futureSignatures != null) {
      for (var signature in widget.futureSignatures!) {
        for (var i = 0; i < signature.signers.length; i++) {
          if (signature.signers[i].sign == "Date") {
            editedSigns[i] = _getCurrentDate();
          }
        }
      }
    }
  }

  String _getCurrentDate() {
    return DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now());
  }

  Future<void> _loadSignatures() async {
    try {
      List<String> signatureIds = await authApiService.fetchSignatureIds();
      List<String> signatureUrls =
          await authApiService.getSignatureUrls(signatureIds);
      setState(() {
        _signatureUrls = signatureUrls;
      });
    } catch (e) {
      print("Error loading signatures: $e");
      setState(() {
        _signatureUrls = [];
      });
    }
  }

  void _editSignature(int signerIndex, String newValue) {
    setState(() {
      editedSigns[signerIndex] = newValue;
    });
  }

  void _showEditDialog(BuildContext context, int signerIndex) async {
    TextEditingController controller = TextEditingController(
      text: editedSigns[signerIndex] ?? "",
    );

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Edit Name",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: "Enter Name",
                  prefixIcon: Icon(LucideIcons.edit3, color: Colors.blueAccent),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel", style: TextStyle(color: Colors.red)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      _editSignature(signerIndex, controller.text);
                      widget.futureSignatures?.firstOrNull?.signers[signerIndex]
                          .sign = controller.text ?? '';
                      Navigator.pop(context);
                    },
                    icon: Text("✅",
                        style: TextStyle(
                            fontSize: 18)), // Replaced Icon with Emoji
                    label: Text(
                      "Ok",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSignatureSelectionSheet(int signerIndex) {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          padding: EdgeInsets.all(16),
          child: _signatureUrls.isEmpty
              ? Center(child: Text('No saved signatures available.'))
              : GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3),
                  itemCount: _signatureUrls.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          appliedSignatureImages[signerIndex] =
                              _signatureUrls[index];
                          final String signatureId =
                              _signatureUrls[index].split('/').last;
                          widget
                              .futureSignatures
                              ?.firstOrNull
                              ?.signers[signerIndex]
                              .signatureId = signatureId ?? '';
                        });
                        Navigator.pop(context);
                      },
                      child: Image.network(_signatureUrls[index]),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showSignatureDialog(BuildContext context, int signerIndex) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Choose Signature",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(LucideIcons.pencil, color: Colors.blueAccent),
                title: Text(
                  "New Sign",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showSignaturePad(signerIndex);
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.folder, color: Colors.green),
                title: Text(
                  "My Sign",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showSignatureSelectionSheet(signerIndex);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  final SignatureController signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  void _showSignaturePad(int signerIndex) async {
    bool isConnected = await NetworkUtil.isConnectedToInternet();

    if (!isConnected) {
      showCustomSnackBar(
        context,
        'No internet connection. Please check your network.',
        isError: true,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showSignatureDialog(context, signerIndex);
                    },
                    icon: Icon(Icons.arrow_back_ios),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Draw Signature',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Signature(
                  controller: signatureController,
                  height: 250,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        signatureController.clear();
                      });
                    },
                    icon: Icon(Icons.clear, color: Colors.white),
                    label: Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (signatureController.isNotEmpty) {
                        try {
                          final signatureImage =
                              await signatureController.toPngBytes();
                          if (signatureImage == null) {
                            showCustomSnackBar(
                                context, "Failed to capture signature!",
                                isError: true);
                            return;
                          }

                          File signatureFile =
                              await _saveSignatureToFile(signatureImage);
                          List<File> signatureFiles = [signatureFile];

                          final signatureFileIds = await authApiService
                              .uploadSignatures(signatureFiles);
                          if (signatureFileIds.isEmpty) {
                            showCustomSnackBar(
                                context, "Signature upload failed!",
                                isError: true);
                            return;
                          }

                          await authApiService
                              .saveSignatureRecords(signatureFileIds);

                          List<String> signatureUrls = await authApiService
                              .getSignatureUrls(signatureFileIds);
                          if (signatureUrls.isEmpty) {
                            showCustomSnackBar(context,
                                "Failed to retrieve uploaded signature!",
                                isError: true);
                            return;
                          }

                          String uploadedUrl = signatureUrls.first;

                          setState(() {
                            _signatureUrls.add(uploadedUrl);
                            appliedSignatureImages[signerIndex] = uploadedUrl;
                            final String signatureId =
                                uploadedUrl.split('/').last;
                            widget
                                .futureSignatures
                                ?.firstOrNull
                                ?.signers[signerIndex]
                                .signatureId = signatureId ?? '';
                          });

                          Navigator.pop(context);
                        } catch (e) {
                          showCustomSnackBar(context, "Error: ${e.toString()}",
                              isError: true);
                        }
                      } else {
                        showCustomSnackBar(context, "Draw a signature first!",
                            isError: true);
                      }
                    },
                    icon: Text("✅",
                        style: TextStyle(fontSize: 18)), // Replaced Icon with ✅
                    label: Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<File> _saveSignatureToFile(Uint8List signatureImage) async {
    Directory tempDir = await getTemporaryDirectory();
    String signatureFilePath =
        '${tempDir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png';
    File signatureFile = File(signatureFilePath);
    await signatureFile.writeAsBytes(signatureImage);
    return signatureFile;
  }

  void _updateSignaturePosition(int signerIndex, Offset newPosition) {
    setState(() {
      widget.futureSignatures?.firstOrNull?.signers[signerIndex].xOffset =
          newPosition.dx ?? 0.0;
      widget.futureSignatures?.firstOrNull?.signers[signerIndex].yOffset =
          newPosition.dy ?? 0.0;
    });
  }

  void _deleteSignature(int signerIndex) async {
    try {
      final signerId =
          widget.futureSignatures?.firstOrNull?.signers[signerIndex].id;
      if (signerId != null) {
        await authApiService.deleteSigner(signerId);
        setState(() {
          widget.futureSignatures?.firstOrNull?.signers.removeAt(signerIndex);
          editedSigns.remove(signerIndex);
          appliedSignatureImages.remove(signerIndex);
        });
        print('Signature deleted successfully!');
      }
    } catch (e) {
      showCustomSnackBar(context, 'Failed to delete signature: $e',
          isError: true);
    }
  }

  void _toggleDeleteIcon(int signerIndex) {
    setState(() {
      showDeleteIcon[signerIndex] = !(showDeleteIcon[signerIndex] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: PrimaryColors.bluegray50,
        elevation: 4, // Adds a slight shadow for depth
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(10), // Soft rounded bottom corners
          ),
        ),
        title: Text(
          widget.name ?? "PDF Preview",
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          if (widget.isDrafted == 'Draft' || widget.isDrafted == 'Pending')
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'Submit') {
                  bool isConnected = await checkInternetConnection();
                  if (!isConnected) {
                    showCustomSnackBar(
                      context,
                      'No Internet connection. Please try again later.',
                      isError: true,
                      isSign: true,
                    );
                    return;
                  }

                  // Show login dialog
                  bool loginSuccessful = await showLoginDialog(context,
                      preFilledEmail: _userEmail);

                  if (loginSuccessful) {
                    try {
                      authApiService.updateSignatureData(
                          status: DocumentStatus.Pending.name,
                          documentId: (widget.futureSignatures?.firstOrNull?.id)
                                  .toString() ??
                              '',
                          signModelList:
                              widget.futureSignatures?.firstOrNull?.signers ??
                                  [],
                          isSignedReceiver: true,
                          userEmail: _userEmail!);
                      showCustomSnackBar(
                        context,
                        'Document submitted successfully!',
                        isError: false,
                        isSign: true,
                      );
                    } catch (e) {
                      print("Error submitting document: $e");
                      showCustomSnackBar(
                        context,
                        'Failed to submit document. Please try again later.',
                        isError: true,
                        isSign: true,
                      );
                    }
                  }
                } else if (value == 'Draft') {
                  bool isConnected = await checkInternetConnection();
                  if (!isConnected) {
                    showCustomSnackBar(
                      context,
                      'No Internet connection. Please try again later.',
                      isError: true,
                      isSign: true,
                    );
                    return;
                  }

                  // Show login dialog
                  bool loginSuccessful = await showLoginDialog(context,
                      preFilledEmail: _userEmail);

                  if (loginSuccessful) {
                    try {
                      authApiService.updateSignatureData(
                          status: DocumentStatus.Draft.name,
                          documentId: (widget.futureSignatures?.firstOrNull?.id)
                                  .toString() ??
                              '',
                          signModelList:
                              widget.futureSignatures?.firstOrNull?.signers ??
                                  [],
                          //  isSignedReceiver: false,
                          userEmail: _userEmail!);
                      showCustomSnackBar(
                        context,
                        'Document saved as draft successfully!',
                        isError: false,
                        isSign: true,
                      );
                    } catch (e) {
                      print("Error saving document as draft: $e");
                      showCustomSnackBar(
                        context,
                        'Failed to save document as draft. Please try again later.',
                        isError: true,
                        isSign: true,
                      );
                    }
                  }
                }
              },
              itemBuilder: (BuildContext context) {
                return [
                  PopupMenuItem(
                    value: 'Submit',
                    child: Row(
                      children: [
                        Icon(Icons.send, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Submit', style: TextStyle(color: Colors.green)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'Draft',
                    child: Row(
                      children: [
                        Icon(Icons.save, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Draft', style: TextStyle(color: Colors.blue)),
                      ],
                    ),
                  ),
                ];
              },
              icon: Icon(Icons.more_vert, color: Colors.black),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              color: Colors.white,
              elevation: 8,
            ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            color: Colors.white,
            width: double.infinity,
            child: widget.isImage == true
                ? Image.network(widget.pdfUrl)
                : SfPdfViewer.network(widget.pdfUrl,
                    controller: _pdfController),
          ),
          if (widget.futureSignatures != null)
            ...widget.futureSignatures!.expand((signature) =>
                signature.signers.asMap().entries.map((entry) {
                  final int signerIndex = entry.key;
                  final signer = entry.value;
                  if (signer.currentPage != currentPage) {
                    return SizedBox(); // Hide if it's not the current page
                  }
                  final String? textToDisplay =
                      editedSigns[signerIndex] ?? signer.sign;
                  final String? signatureImage =
                      appliedSignatureImages[signerIndex];

                  return Positioned(
                      left: signer.xOffset,
                      top: signer.yOffset,
                      child: Visibility(
                        // visible: widget.isShared ??
                        //     signer.contriputerEmail == _userEmail,
                        child: GestureDetector(
                            onPanUpdate: (details) {
                              if (widget.isDrafted == 'Draft' &&
                                  signer.userId == userId) {
                                // Check if signer.userId matches userId
                                _updateSignaturePosition(
                                    signerIndex, details.localPosition);
                              }
                            },
                            onTap: () {
                              if (widget.isDrafted == 'Pending' &&
                                  signer.contriputerEmail == _userEmail) {
                                // Check if signer.userId matches userId
                                if (signer.type == SignType.name.name) {
                                  _showEditDialog(context, signerIndex);
                                } else if (signer.type ==
                                    SignType.signature.name) {
                                  _showSignatureDialog(context, signerIndex);
                                } else if (signer.type == SignType.date.name &&
                                    widget.isMe == false) {
                                  setState(() {
                                    editedSigns[signerIndex] =
                                        _getCurrentDate();
                                    widget
                                        .futureSignatures
                                        ?.firstOrNull
                                        ?.signers[signerIndex]
                                        .sign = _getCurrentDate();
                                  });
                                }
                                _toggleDeleteIcon(
                                    signerIndex); // Toggle delete icon
                              }
                            },
                            child: Stack(
                              children: [
                                signer.signatureId != null
                                    ? Image.network(
                                        'http://139.59.134.100:8055/assets/${signer.signatureId}',
                                        width: 100,
                                        height: 50)
                                    : signatureImage != null
                                        ? Image.network(signatureImage,
                                            width: 100, height: 50)
                                        : Text(
                                            textToDisplay!,
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 16,
                                            ),
                                          ),
                                if (showDeleteIcon[signerIndex] ?? false)
                                  Positioned(
                                    right: -15,
                                    top: -15,
                                    child: widget.isMe == true
                                        ? IconButton(
                                            onPressed: () =>
                                                _deleteSignature(signerIndex),
                                            icon: Icon(Icons.delete,
                                                color: Colors.red),
                                          )
                                        : Container(),
                                  ),
                              ],
                            )),
                      ));
                })),
        ],
      ),
    );
  }
}
