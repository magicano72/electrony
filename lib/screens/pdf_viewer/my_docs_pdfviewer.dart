import 'dart:io';
import 'dart:typed_data';

import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/bloc/master_event.dart';
import 'package:Electrony/bloc/master_logic.dart';
import 'package:Electrony/custom/success_screen.dart';
import 'package:Electrony/helper/important_fun.dart';
import 'package:Electrony/models/sign_model.dart';
import 'package:Electrony/networking/api_services.dart';
import 'package:Electrony/theming/colors.dart';
import 'package:Electrony/theming/style.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:page_transition/page_transition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../dashboard/dashboard.dart';

class MyDocsPdfViewer extends StatefulWidget {
  final String pdfUrl;
  final String? name;
  final bool? isImage;
  final bool? meAndOthers;
  final bool? isShared;
  final bool? isMe;
  final String? isDrafted;
  final List<SignatureData>? futureSignatures;

  MyDocsPdfViewer({
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
  _MyDocsPdfViewerState createState() => _MyDocsPdfViewerState();
}

class _MyDocsPdfViewerState extends State<MyDocsPdfViewer> {
  final authApiService =
      AuthApiService(baseUrl: dotenv.env['API_BASE_URL'] ?? '');
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
          currentPage = _pdfController.pageNumber; // Update page number
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
        _userEmail = userProfile['email']?.toString() ?? 'No email available';
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
        _userEmail = userProfile['email']?.toString() ?? 'No email available';
        userId = userProfile['id']?.toString() ?? 'No user ID available';
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
              Text("Edit Name", style: textStyleVersion2()),
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
                          .sign = controller.text;
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
                          widget.futureSignatures?.firstOrNull
                              ?.signers[signerIndex].signatureId = signatureId;
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
                style: textStyleVersion2(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(LucideIcons.pencil, color: Colors.blueAccent),
                title: Text(
                  "New Sign",
                  style: textStyleVersion2(),
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
                  style: textStyleVersion2(),
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
  );

  void _showSignaturePad(int signerIndex) async {
    List<ConnectivityResult> connectivityResult =
        await Connectivity().checkConnectivity();
    bool isConnected = connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.mobile);

    // Update state with connection status
    context.read<MasterBloc>().add(CheckInternetConnection());

    if (!isConnected) {
      showCustomSnackBar(
        context,
        'No internet connection. Please check your network.',
        isError: true,
      );
      return;
    } else
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
                          style: textStyleVersion2(
                              fontSize: 22, fontWeight: FontWeight.bold),
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
                      label: Text(
                        'Clear',
                        style: textStyleVersion2(color: Colors.white),
                      ),
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

                            final signatureFileIds =
                                await authApiService.uploadFile(signatureFiles);
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
                                  .signatureId = signatureId;
                            });

                            Navigator.pop(context);
                          } catch (e) {
                            showCustomSnackBar(
                                context, "Error: ${e.toString()}",
                                isError: true);
                          }
                        } else {
                          showCustomSnackBar(context, "Draw a signature first!",
                              isError: true);
                        }
                      },
                      icon: Text("✅",
                          style:
                              TextStyle(fontSize: 18)), // Replaced Icon with ✅
                      label: Text(
                        'Save',
                        style: textStyleVersion2(),
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
          newPosition.dx;
      widget.futureSignatures?.firstOrNull?.signers[signerIndex].yOffset =
          newPosition.dy;
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

  final TextEditingController _pageNumberController = TextEditingController();
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
          if (widget.isImage == false)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_left),
                    onPressed: () {
                      if (_pdfController.pageNumber > 1) {
                        _pdfController.previousPage();
                      }
                    },
                  ),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _pageNumberController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '${_pdfController.pageNumber}',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                      ),
                      onSubmitted: (value) {
                        final pageNumber = int.tryParse(value);
                        if (pageNumber != null &&
                            pageNumber >= 1 &&
                            pageNumber <= _pdfController.pageCount) {
                          _pdfController.jumpToPage(pageNumber);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Invalid page number. Please enter a number between 1 and ${_pdfController.pageCount}.'),
                            ),
                          );
                          _pageNumberController.text =
                              _pdfController.pageNumber.toString();
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_right),
                    onPressed: () {
                      if (_pdfController.pageNumber <
                          _pdfController.pageCount) {
                        _pdfController.nextPage();
                      }
                    },
                  ),
                ],
              ),
            ),
          if (widget.isDrafted == 'Draft')
            PopupMenuButton<String>(
              onSelected: (value) async {
                List<ConnectivityResult> connectivityResult =
                    await Connectivity().checkConnectivity();
                bool isConnected =
                    connectivityResult.contains(ConnectivityResult.wifi) ||
                        connectivityResult.contains(ConnectivityResult.mobile);

                // Update internet connection state
                context.read<MasterBloc>().add(CheckInternetConnection());

                if (!isConnected) {
                  showCustomSnackBar(
                    context,
                    'No internet connection.',
                    isError: true,
                    isSign: true,
                  );
                  return;
                }
                if (value == 'Submit') {
                  bool loginSuccessful = await showLoginDialog(context,
                      preFilledEmail: _userEmail);

                  if (loginSuccessful) {
                    try {
                      waitingToSave(context);

                      bool feeValid = await authApiService
                          .validateAndDeductSignatureFee(context);
                      if (!feeValid) return;

                      bool confirmSubmission =
                          await showSignatureConfirmationDialog(context);
                      if (!confirmSubmission) return;

                      authApiService.updateSignatureData(
                        documentId: (widget.futureSignatures?.firstOrNull?.id)
                                .toString() ??
                            '',
                        signModelList:
                            widget.futureSignatures?.firstOrNull?.signers ?? [],
                        status: DocumentStatus.Submitted.name,
                        userEmail: _userEmail!,
                      );

                      Navigator.push(
                        context,
                        PageTransition(
                          type: PageTransitionType.fade,
                          child: SuccessScreen(
                            onContinue: () {
                              Navigator.pushReplacement(
                                context,
                                PageTransition(
                                  type: PageTransitionType.fade,
                                  child: DashboardScreen(),
                                ),
                              );
                            },
                            title: 'Success',
                            subtitle: 'Document submitted successfully!',
                            buttonText: 'Go Back',
                          ),
                        ),
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
                  bool loginSuccessful = await showLoginDialog(context,
                      preFilledEmail: _userEmail);

                  if (loginSuccessful) {
                    try {
                      waitingToSave(context);
                      authApiService.updateSignatureData(
                          documentId: (widget.futureSignatures?.firstOrNull?.id)
                                  .toString() ??
                              '',
                          signModelList:
                              widget.futureSignatures?.firstOrNull?.signers ??
                                  [],
                          status: DocumentStatus.Draft.name,
                          userEmail: _userEmail!);
                      Navigator.push(
                        context,
                        PageTransition(
                          type: PageTransitionType.fade,
                          child: SuccessScreen(
                            onContinue: () {
                              Navigator.pushReplacement(
                                context,
                                PageTransition(
                                  type: PageTransitionType.fade,
                                  child: DashboardScreen(),
                                ),
                              );
                            },
                            title: 'Success',
                            subtitle: 'Document save as draft successfully!',
                            buttonText: 'Go Back',
                          ),
                        ),
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
                        SizedBox(width: 8.w),
                        Text('Submit', style: textStyleVersion2(fontSize: 18)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'Draft',
                    child: Row(
                      children: [
                        Icon(Icons.save, color: Colors.blue),
                        SizedBox(width: 8.w),
                        Text('Draft', style: textStyleVersion2(fontSize: 18)),
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
            width: MediaQuery.of(context).size.width, // Full screen width
            height: MediaQuery.of(context).size.height, // Full screen height
            child: widget.isImage == true
                ? Image.network(
                    widget.pdfUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit
                        .contain, // This will maintain aspect ratio while filling
                  )
                : SfPdfViewer.network(
                    widget.pdfUrl,
                    controller: _pdfController,
                    canShowScrollHead: true,
                    pageLayoutMode: PdfPageLayoutMode.single,
                  ),
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
                              if (widget.isDrafted == 'Draft' &&
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
                                        '${dotenv.env['API_BASE_URL']}/assets/${signer.signatureId}',
                                        width: 100,
                                        height: 50)
                                    : signatureImage != null
                                        ? Image.network(signatureImage,
                                            width: 100, height: 50)
                                        : Text(textToDisplay!,
                                            style: textStyleVersion2()),
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
