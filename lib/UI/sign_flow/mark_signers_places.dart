import 'dart:io';

import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/Helper/important_fun.dart';
import 'package:Electrony/Networking/api_services.dart';
import 'package:Electrony/Theming/colors.dart';
import 'package:Electrony/models/sign_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

Future<bool> checkInternetConnection() async {
  var connectivityResult = await (Connectivity().checkConnectivity());
  return connectivityResult != ConnectivityResult.none;
}

class MarkSignersPlaces extends StatefulWidget {
  final File pdfFile;
  final List<String>? signers;
  final bool? isImage;

  MarkSignersPlaces({
    required this.pdfFile,
    this.signers,
    this.isImage,
  });

  @override
  _DraggableWidgetsScreenState createState() => _DraggableWidgetsScreenState();
}

class _DraggableWidgetsScreenState extends State<MarkSignersPlaces> {
  final authApiService = AuthApiService(baseUrl: 'http://139.59.134.100:8055');

  void initState() {
    super.initState();
    _loadUserEmail();
  }

  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final Map<int, List<_DraggableItemData>> pageItems = {};
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

  int _selectedIndex = -1;

  void _addDraggableItem(String text) {
    print('Adding item to page $_currentPage: $text');
    final color = _itemColors[_selectedIndex % _itemColors.length];
    final String contributorEmail = widget.signers![_selectedIndex];
    final String displayText = '${contributorEmail.substring(0, 5)} - $text';

    setState(() {
      pageItems.putIfAbsent(_currentPage, () => []);
      setState(() {
        switch (text) {
          case "Date":
            pageItems[_currentPage]!.add(_DraggableItemData(
                signId: -1,
                text: displayText,
                offset: Offset(50, 50),
                color: color,
                currentPage: _currentPage,
                contributorEmail: contributorEmail,
                type: SignType.date));
            break;

          case "Name":
            pageItems[_currentPage]!.add(_DraggableItemData(
                signId: -1,
                text: displayText,
                offset: Offset(50, 50),
                color: color,
                currentPage: _currentPage,
                contributorEmail: contributorEmail,
                type: SignType.name));
            break;
          case "Signature":
            pageItems[_currentPage]!.add(_DraggableItemData(
                signId: -1,
                text: displayText,
                offset: Offset(50, 50),
                color: color,
                currentPage: _currentPage,
                contributorEmail: contributorEmail,
                type: SignType.signature,
                signatureId: null));
            break;

          default:
            pageItems[_currentPage]!.add(_DraggableItemData(
                signId: -1,
                text: displayText,
                offset: Offset(50, 50),
                color: color,
                currentPage: _currentPage,
                contributorEmail: contributorEmail,
                type: SignType.name));
            break;
        }
      });
    });
  }

  final List<Color> _itemColors = [
    Colors.black45,
    Colors.black,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.yellow,
  ];

  void _showSignersDialog(String text) {
    TextEditingController newSignerController = TextEditingController();
    final emailRegex =
        RegExp(r'^[^@]+@[^@]+\.[^@]+$'); // Email validation regex

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0), // Rounded corners
          ),
          backgroundColor: PrimaryColors.whiteA700,
          elevation: 5,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                // Wrap with SingleChildScrollView
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    // ...existing code...
                    children: [
                      Text(
                        'Select Signer',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: PrimaryColors.mainColor,
                        ),
                      ),
                      SizedBox(height: 15),
                      TextField(
                          controller: newSignerController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: PrimaryColors.mainColor.withOpacity(.1),
                            labelText: 'Add New Signer',
                            labelStyle: TextStyle(
                              color: PrimaryColors.mainColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                final newSigner = newSignerController.text;
                                if (emailRegex.hasMatch(newSigner)) {
                                  if (widget.signers!.contains(newSigner)) {
                                    showCustomSnackBar(
                                      context,
                                      'Signer already exists',
                                      isError: true,
                                    );
                                  } else {
                                    setState(() {
                                      widget.signers!.add(newSigner);
                                    });
                                    newSignerController.clear();
                                  }
                                } else {
                                  showCustomSnackBar(
                                    context,
                                    'Invalid email format',
                                    isError: true,
                                  );
                                }
                              },
                              icon: Icon(Icons.add,
                                  color: PrimaryColors.mainColor),
                            ),
                          )),
                      SizedBox(height: 15),
                      SizedBox(
                        height: 300, // Limit the height of the ListView
                        child: ListView.builder(
                          itemCount: widget.signers!.length,
                          itemBuilder: (context, index) {
                            Color itemColor =
                                _itemColors[index % _itemColors.length];

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedIndex = index;
                                });
                                Navigator.pop(context); // Close the dialog
                                _addDraggableItem(text);
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: AnimatedContainer(
                                        duration: Duration(
                                            milliseconds:
                                                200), // Smooth transition
                                        decoration: BoxDecoration(
                                          color: _selectedIndex == index
                                              ? itemColor
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                              12.0), // Rounded corners
                                          border: Border.all(
                                            color: _selectedIndex == index
                                                ? Colors.white
                                                : itemColor,
                                            width: 2.0,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Text(
                                            widget.signers![index],
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: _selectedIndex == index
                                                  ? Colors.white
                                                  : itemColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon:
                                          Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          widget.signers!.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: Colors.red, fontSize: 16),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
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
          text: item.text,
          color: item.color,
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
      pageItems[page]![index] = _DraggableItemData(
          signId: pageItems[page]![index].signId,
          text: pageItems[page]![index].text,
          offset: newOffset,
          color: pageItems[page]![index].color,
          currentPage: page,
          contributorEmail: pageItems[page]![index].contributorEmail,
          type: pageItems[page]![index].type,
          signatureId: pageItems[page]![index].signatureId);
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
                  final list = pageItems.values.toList().expand((e) => e);
                  final List<SignModel> signModel = list.map(
                    (e) {
                      return SignModel(
                        status: SignerStatus.Pending.name,
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
                      final authApiService =
                          AuthApiService(baseUrl: 'http://139.59.134.100:8055');
                      waitingToSave(context);
                      if (value == 'Submit') {
                        await authApiService.sendSignatureData(
                            pdfFile: widget.pdfFile,
                            userEmail: _userEmail!,
                            signModelList: signModel,
                            status: DocumentStatus.Pending.name);
                        showCustomSnackBar(
                          context,
                          'Document submitted successfully!',
                          isError: false,
                          isSign: true,
                        );
                      } else if (value == 'Draft') {
                        await authApiService.sendSignatureData(
                            pdfFile: widget.pdfFile,
                            userEmail: _userEmail!,
                            signModelList: signModel,
                            status: DocumentStatus.Draft.name);
                        showCustomSnackBar(
                          context,
                          'Document saved as draft successfully!',
                          isError: false,
                          isSign: true,
                        );
                      }
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
                    showCustomSnackBar(
                      context,
                      'Login failed. Please try again.',
                      isError: true,
                      isSign: true,
                    );
                    return;
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
          widget.isImage == false
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
                _showSignersDialog("Signature");
              } else {
                _addDraggableItem("Signature");
              }
            },
          ),
          SpeedDialChild(
            child: Icon(Icons.text_fields, color: Colors.white),
            label: 'Name',
            backgroundColor: Colors.green,
            onTap: () {
              if (widget.signers != null && widget.signers!.isNotEmpty) {
                _showSignersDialog("Name");
              } else {
                _addDraggableItem("Name");
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
                _showSignersDialog("Date");
              } else {
                _addDraggableItem("Date");
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
  final Color color; // The color of the text
  final ValueChanged<Offset> onDrag; // Callback for when the widget is dragged
  final VoidCallback onTextTap; // Callback for when the text is tapped
  final VoidCallback onDelete; // Callback for when the delete button is pressed

  DraggableWidget({
    required this.text,
    required this.color,
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
          // Render the text as static (non-editable)
          Text(
            widget.text,
            style: TextStyle(
              fontSize: 20,
              color: widget.color,
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

class _DraggableItemData {
  final String text;
  final Offset offset;
  final Color color;
  final String contributorEmail;
  final int currentPage;
  final int signId;
  final SignType type;
  final String? signatureId;
  _DraggableItemData({
    required this.type,
    this.signatureId,
    required this.signId,
    required this.contributorEmail,
    required this.currentPage,
    required this.text,
    required this.offset,
    required this.color,
  });
}
