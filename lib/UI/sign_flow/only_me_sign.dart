import 'dart:io';

import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/Helper/important_fun.dart';
import 'package:Electrony/Networking/api_services.dart';
import 'package:Electrony/Theming/colors.dart';
import 'package:Electrony/models/sign_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart'; // Add this import
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

Future<bool> checkInternetConnection() async {
  var connectivityResult = await (Connectivity().checkConnectivity());
  return connectivityResult != ConnectivityResult.none;
}

class OnlyMeSign extends StatefulWidget {
  final File pdfFile;
  final List<String>? signers;
  final bool? isImage;
  final List<SignatureData>? futureSignatures;
  OnlyMeSign({
    required this.pdfFile,
    this.signers,
    this.isImage,
    this.futureSignatures,
  });

  @override
  _DraggableWidgetsScreenState createState() => _DraggableWidgetsScreenState();
}

class _DraggableWidgetsScreenState extends State<OnlyMeSign> {
  final authApiService = AuthApiService(baseUrl: 'http://139.59.134.100:8055');
  final PdfViewerController _pdfController = PdfViewerController();
  int currentPage = 1;
  String? _documentStatus;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
    _loadSignatures();

    _pdfController.addListener(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          currentPage = _pdfController.pageNumber; // Update page number
        });
      });
    });
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

  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final Map<int, List<_DraggableItemDataOnlyMe>> pageItems = {};
  int _currentPage = 1;

  String? _userEmail;
  Future<void> _loadUserEmail() async {
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

  void _addDraggableItemName(String data) {
    print('Adding item to page $_currentPage: $data');

    final String contributorEmail = widget.signers![0];

    setState(() {
      pageItems.putIfAbsent(_currentPage, () => []);

      pageItems[_currentPage]!.add(_DraggableItemDataOnlyMe(
          signId: -1,
          text: data,
          offset: Offset(50, 50),
          currentPage: _currentPage,
          contributorEmail: contributorEmail,
          type: SignType.name));
    });
  }

  void _addDraggableItemDate() {
    print('Adding item to page $_currentPage: ');

    final String contributorEmail = widget.signers![0];

    setState(() {
      pageItems.putIfAbsent(_currentPage, () => []);

      pageItems[_currentPage]!.add(_DraggableItemDataOnlyMe(
          signId: -1,
          text: _getCurrentDate(),
          offset: Offset(50, 50),
          currentPage: _currentPage,
          contributorEmail: contributorEmail,
          type: SignType.date));
    });
  }

  void _addSignature(String signatureImage) {
    final String contributorEmail = widget.signers![0];

    setState(() {
      pageItems.putIfAbsent(_currentPage, () => []);
      final String signatureId = signatureImage.split('/').last;
      pageItems[_currentPage]!.add(_DraggableItemDataOnlyMe(
        signId: -1,
        signatureImage: signatureImage,
        signatureId: signatureId,
        offset: Offset(50, 50),
        currentPage: _currentPage,
        contributorEmail: contributorEmail,
        type: SignType.signature,
      ));
    });
  }

  List<Widget> _buildDraggableItems() {
    if (!pageItems.containsKey(_currentPage)) return [];

    return pageItems[_currentPage]!.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;

      return Positioned(
        left: item.offset.dx,
        top: item.offset.dy,
        child: DraggableWidget(
          text: item.text ?? '',
          signatureImage: item.signatureImage,
          onDrag: (newOffset) {
            _updateDraggableItemPosition(_currentPage, index, newOffset);
          },
          onTextTap: () {},
          onDelete: () {
            setState(() {
              // Remove the draggable item from the pageItems
              pageItems[_currentPage]?.removeAt(index);
            });
          },
        ),
      );
    }).toList();
  }

  void _updateDraggableItemPosition(int page, int index, Offset newOffset) {
    setState(() {
      pageItems[page]![index] = _DraggableItemDataOnlyMe(
          signId: pageItems[page]![index].signId,
          text: pageItems[page]![index].text,
          offset: newOffset,
          currentPage: page,
          contributorEmail: pageItems[page]![index].contributorEmail,
          type: pageItems[page]![index].type,
          signatureId: pageItems[page]![index].signatureId,
          signatureImage: pageItems[page]![index].signatureImage);
    });
  }

  Map<int, String> editedSigns = {};
  void _editSignature(int signerIndex, String newValue) {
    setState(() {
      editedSigns[0] = newValue;
    });
  }

  void _showEditDialog(BuildContext context, int signerIndex) async {
    TextEditingController controller = TextEditingController(
      text: editedSigns[0] ?? "",
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
                          .sign = controller.text;
                      _addDraggableItemName(controller.text);
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

  String _getCurrentDate() {
    return DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now());
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
                  _showSignaturePad();
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
                  _showSignatureSelectionSheet();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  List<String> appliedSignatureImages = [];
  List<String> _signatureUrls = [];
  void _showSignatureSelectionSheet() {
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
                      onTap: () async {
                        final url = _signatureUrls[index];
                        if (url.isEmpty) {
                          showCustomSnackBar(
                            context,
                            'Invalid URL for signature image.',
                            isError: true,
                          );
                          return;
                        }

                        try {
                          final request =
                              await HttpClient().getUrl(Uri.parse(url));
                          final response = await request.close();
                          if (response.statusCode == 404) {
                            showCustomSnackBar(
                              context,
                              'Signature image not found (404).',
                              isError: true,
                            );
                            return;
                          }

                          final bytes =
                              await consolidateHttpClientResponseBytes(
                                  response);
                          setState(() {
                            if (appliedSignatureImages.isEmpty) {
                              appliedSignatureImages.add(url);
                            } else {
                              if (appliedSignatureImages.length <= 0) {
                                appliedSignatureImages.add(url);
                              } else {
                                appliedSignatureImages[0] = url;
                              }
                            }
                            final String signatureId = url.split('/').last;
                            widget.futureSignatures?.firstOrNull?.signers[0]
                                .signatureId = signatureId;
                          });

                          _addSignature(url);

                          Navigator.pop(context);
                        } catch (e) {
                          showCustomSnackBar(
                            context,
                            'Failed to load signature image.',
                            isError: true,
                          );
                        }
                      },
                      child: Image.network(_signatureUrls[index]),
                    );
                  },
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

  final SignatureController signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  void _showSignaturePad() async {
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
                      _showSignatureDialog(context, 0);
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
                          print(uploadedUrl);
                          setState(() {
                            _signatureUrls.add(uploadedUrl);
                            appliedSignatureImages[0] = uploadedUrl;
                            final String signatureId =
                                uploadedUrl.split('/').last;
                            widget.futureSignatures?.firstOrNull?.signers[0]
                                .signatureId = signatureId;
                          });

                          _addSignature(uploadedUrl);
                          print(uploadedUrl);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: PrimaryColors.bluegray50,
          elevation: 4, // Adds a slight shadow for depth
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(15), // Soft rounded bottom corners
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_outlined,
                color: PrimaryColors.mainColor),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          centerTitle: true,
          title: Text('Add Signatures',
              style: TextStyle(color: PrimaryColors.mainColor)),
          actions: [
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'Submit') {
                    final list = pageItems.values.toList().expand((e) => e);
                    print(list);
                    final List<SignModel> signModel = list.map(
                      (e) {
                        return SignModel(
                          status: SignerStatus.Submitted.name,
                          signId: e.signId,
                          xOffset: e.offset.dx,
                          yOffset: e.offset.dy,
                          contributorEmail: e.contributorEmail,
                          signatureText: e.text,
                          currentPage: e.currentPage,
                          type: e.type,
                          signatureId: e.signatureId,
                        );
                      },
                    ).toList();
                    print(list.length);
                    print(list.firstOrNull?.offset);
                    print(list.runtimeType.toString());

                    // Check internet connection
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
                        final authApiService = AuthApiService(
                            baseUrl: 'http://139.59.134.100:8055');
                        waitingToSave(context);
                        await authApiService.sendSignatureData(
                          pdfFile: widget.pdfFile,
                          userEmail: _userEmail!,
                          signModelList: signModel,
                          status: DocumentStatus.Submitted.name,
                        );
                        print(widget.pdfFile);
                        // Show success message
                        showCustomSnackBar(
                          context,
                          'Document submitted successfully!',
                          isError: false,
                          isSign: true,
                        );
                        Navigator.of(context).pop();
                      } catch (e) {
                        print("Error submitting document: $e");
                        showCustomSnackBar(
                          context,
                          'Failed to submit document. Please try again later.',
                          isError: true,
                          isSign: true,
                        );
                      }
                    } else {
                      // If login is unsuccessful, exit the process
                      return;
                    }
                  } else if (value == 'Draft') {
                    final list = pageItems.values.toList().expand((e) => e);
                    print(list);
                    final List<SignModel> signModel = list.map(
                      (e) {
                        return SignModel(
                          status: SignerStatus.Draft.name,
                          signId: e.signId,
                          xOffset: e.offset.dx,
                          yOffset: e.offset.dy,
                          contributorEmail: e.contributorEmail,
                          signatureText: e.text,
                          currentPage: e.currentPage,
                          type: e.type,
                          signatureId: e.signatureId,
                        );
                      },
                    ).toList();
                    print(list.length);
                    print(list.firstOrNull?.offset);
                    print(list.runtimeType.toString());

                    // Check internet connection
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
                        final authApiService = AuthApiService(
                            baseUrl: 'http://139.59.134.100:8055');
                        waitingToSave(context);
                        await authApiService.sendSignatureData(
                          pdfFile: widget.pdfFile,
                          userEmail: _userEmail!,
                          signModelList: signModel,
                          status: DocumentStatus.Draft.name,
                        );
                        print(widget.pdfFile);
                        // Show success message
                        showCustomSnackBar(
                          context,
                          'Document drafted successfully!',
                          isError: false,
                          isSign: true,
                        );
                        Navigator.of(context).pop();
                      } catch (e) {
                        print("Error submitting document: $e");
                        showCustomSnackBar(
                          context,
                          'Failed to submit document. Please try again later.',
                          isError: true,
                          isSign: true,
                        );
                      }
                    } else {
                      // If login is unsuccessful, exit the process
                      return;
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
            )
          ]),
      body: Stack(
        children: [
          Column(
            children: [
              if (_documentStatus != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Document Status: $_documentStatus',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              Expanded(
                child: widget.isImage == false
                    ? SfPdfViewer.file(
                        widget.pdfFile,
                        key: _pdfViewerKey,
                        onPageChanged: (details) {
                          setState(() {
                            _currentPage = details.newPageNumber;
                          });
                        },
                      )
                    : Container(
                        width: double.infinity,
                        child: Image.file(
                          widget.pdfFile,
                        ),
                      ),
              ),
            ],
          ),
          ..._buildDraggableItems(),
        ],
      ),
      floatingActionButton: SpeedDial(
        marginEnd: 27,
        marginBottom: 35,
        child: Image.asset(
          'assets/images/signature.png',
          width: 30,
          height: 30,
        ),
        activeIcon: Icons.close,
        backgroundColor: Colors.blue,
        children: [
          SpeedDialChild(
            child: Icon(Icons.edit, color: Colors.white),
            label: 'Signature',
            backgroundColor: Colors.blue,
            onTap: () {
              if (widget.signers != null && widget.signers!.isNotEmpty) {
                _showSignatureDialog(context, 0);
              }
            },
          ),
          SpeedDialChild(
            child: Icon(Icons.text_fields, color: Colors.white),
            label: 'Name',
            backgroundColor: Colors.green,
            onTap: () {
              if (widget.signers != null && widget.signers!.isNotEmpty) {
                _showEditDialog(context, 0);
              }
            },
          ),
          SpeedDialChild(
            child: Image.asset(
              'assets/images/calendar.png',
              scale: 10,
            ),
            label: 'Date',
            backgroundColor: PrimaryColors.blueA40019,
            onTap: () {
              if (widget.signers != null && widget.signers!.isNotEmpty) {
                _addDraggableItemDate();
              }
            },
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class DraggableWidget extends StatefulWidget {
  String text; // The text to display (e.g., "Sign", "Name", "Date")
  final String? signatureImage; // The signature image data
  final ValueChanged<Offset> onDrag; // Callback for when the widget is dragged
  final VoidCallback onTextTap; // Callback for when the text is tapped
  final VoidCallback onDelete; // Callback for when the delete button is pressed

  DraggableWidget({
    required this.text,
    this.signatureImage,
    required this.onDrag,
    required this.onTextTap,
    required this.onDelete,
  });

  @override
  _DraggableWidgetState createState() => _DraggableWidgetState();
}

class _DraggableWidgetState extends State<DraggableWidget> {
  Offset position = Offset(0, 0); // The position of the widget
  bool isDragging = false; // Track dragging state
  bool isSelected = false; // Track selection state (clicked)

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) {
        setState(() {
          isDragging = true; // Set dragging to true when drag starts
        });
      },
      onPanUpdate: (details) {
        // Update the position when the widget is dragged
        setState(() {
          position += details.delta;
        });
        // Call the onDrag callback with the new position
        widget.onDrag(position);
      },
      onPanEnd: (_) {
        setState(() {
          isDragging = false; // Set dragging to false when drag ends
        });
      },
      onTap: () {
        setState(() {
          isSelected = !isSelected; // Toggle selection state when tapped
        });
        widget.onTextTap(); // Trigger the tap callback
      },
      child: Stack(
        children: [
          // Render the text or signature image
          widget.signatureImage != null
              ? Image.network(
                  widget.signatureImage!,
                  width: 100,
                  height: 50,
                )
              : Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: 20,
                  ),
                ),

          // Show delete icon only when selected
          if (isSelected)
            Positioned(
              right: -15,
              top: -15,
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: widget.onDelete, // Call the delete callback
              ),
            ),
        ],
      ),
    );
  }
}

class _DraggableItemDataOnlyMe {
  final String? text;
  final Offset offset;
  final String contributorEmail;
  final int currentPage;
  final int signId;
  final SignType type;
  final String? signatureId;
  final String? signatureImage; // Add this field to store the signature image

  _DraggableItemDataOnlyMe({
    required this.type,
    this.signatureId,
    this.signatureImage,
    required this.signId,
    required this.contributorEmail,
    required this.currentPage,
    this.text,
    required this.offset,
  });
}
