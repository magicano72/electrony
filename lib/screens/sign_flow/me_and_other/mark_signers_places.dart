import 'dart:io';

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
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:page_transition/page_transition.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../dashboard/dashboard.dart';

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
  final authApiService =
      AuthApiService(baseUrl: dotenv.env['API_BASE_URL'] ?? '');

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

  final TextEditingController _pageNumberController = TextEditingController();
  final PdfViewerController _pdfController = PdfViewerController();
  int _selectedIndex = -1;

  void _addDraggableItem(String text) {
    print('Adding item to page $_currentPage: $text');
    final color = _itemColors[_selectedIndex % _itemColors.length];
    final String contributorEmail = widget.signers![_selectedIndex];
    final String displayText = '${contributorEmail.substring(0, 3)}*$text';

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
          case "Sign":
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
    Colors.black,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.red,
    Colors.brown,
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
                      Text('Select Signer', style: textStyleVersion2()),
                      SizedBox(height: 15),
                      TextField(
                          controller: newSignerController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Color(0xFFF5F5F5),
                            hintText: 'Enter Recipient email',
                            hintStyle: textStyle(
                              "Poppins",
                              16,
                              Colors.grey.shade600,
                              FontWeight.w400,
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
                              style: textStyleVersion2(),
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
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xFFF5F5F5),
          elevation: 4, // Adds a slight shadow for depth
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(15), // Soft rounded bottom corners
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_outlined,
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          centerTitle: true,
          title: Text(
            'Add Signatures',
            style: textStyle(
              "Poppins",
              18,
              Colors.black,
              FontWeight.w500,
            ),
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
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: PopupMenuButton<String>(
                onSelected: (value) async {
                  // Check connectivity
                  List<ConnectivityResult> connectivityResult =
                      await Connectivity().checkConnectivity();
                  bool isConnected = connectivityResult
                          .contains(ConnectivityResult.wifi) ||
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

                  // Collect signature data
                  final list = pageItems.values.toList().expand((e) => e);
                  final List<SignModel> signModel = list
                      .map(
                        (e) => SignModel(
                          status: SignerStatus.Pending.name,
                          signId: e.signId,
                          xOffset: e.offset.dx,
                          yOffset: e.offset.dy,
                          contributorEmail: e.contributorEmail,
                          signatureText: e.text,
                          currentPage: e.currentPage,
                          type: e.type,
                          signatureId: e.signatureId,
                        ),
                      )
                      .toList();

                  bool loginSuccessful = await showLoginDialog(context,
                      preFilledEmail: _userEmail);
                  if (loginSuccessful) {
                    try {
                      final authApiService = AuthApiService(
                          baseUrl: dotenv.env['API_BASE_URL'] ?? '');
                      waitingToSave(context);

                      if (value == 'Submit') {
                        bool feeValid = await authApiService
                            .validateAndDeductSignatureFee(context);
                        if (!feeValid) {
                          if (Navigator.canPop(context))
                            Navigator.pop(context); // Close waiting
                          return;
                        }

                        bool confirmSubmission =
                            await showSignatureConfirmationDialog(context);
                        if (!confirmSubmission) {
                          if (Navigator.canPop(context))
                            Navigator.pop(context); // Close waiting
                          return;
                        }
                      }
                      await authApiService.sendSignatureData(
                        pdfFile: widget.pdfFile,
                        userEmail: _userEmail!,
                        signModelList: signModel,
                        status: value == 'Submit'
                            ? DocumentStatus.Pending.name
                            : DocumentStatus.Draft.name,
                        context: context, // Pass the context to the function
                      );

                      // Close the waiting dialog
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }

                      Navigator.push(
                        context,
                        PageTransition(
                          type: PageTransitionType.fade,
                          child: SuccessScreen(
                            onContinue: () {
                              Navigator.push(
                                context,
                                PageTransition(
                                  type: PageTransitionType.fade,
                                  child: DashboardScreen(),
                                ),
                              );
                            },
                            title: 'Success',
                            subtitle: value == 'Submit'
                                ? 'Document submitted successfully!'
                                : 'Document saved as draft successfully!',
                            buttonText: 'Go to Home',
                          ),
                        ),
                      );
                    } catch (e) {
                      // Make sure to close the waiting dialog if there's an error
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }

                      print("Error submitting document: $e");
                      showCustomSnackBar(
                        context,
                        'Failed to submit document. Please try again later.',
                        isError: true,
                        isSign: true,
                      );
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
                          Text('Submit',
                              style: textStyleVersion2(fontSize: 18)),
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
                    borderRadius: BorderRadius.circular(10)),
                color: Colors.white,
                elevation: 8,
              ),
            )
          ]),
      body: Stack(
        children: [
          widget.isImage == false
              ? SfPdfViewer.file(
                  controller: _pdfController,
                  canShowScrollHead: true,
                  pageLayoutMode: PdfPageLayoutMode.single,
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
        childMargin: EdgeInsets.only(bottom: 20, right: 20),
        child: Image.asset(
          'assets/sign.png',
          width: 35,
          height: 35,
          color: Colors.white,
        ),
        activeIcon: Icons.close,
        backgroundColor: Colors.blue,
        children: [
          SpeedDialChild(
            child: Image.asset(
              'assets/sign.png',
              width: 30,
              height: 30,
            ),
            label: 'Signature',
            labelStyle:
                textStyle('Poppins', 14, Color(0xff2D3748), FontWeight.w500),
            backgroundColor: Colors.blue,
            onTap: () {
              if (widget.signers != null && widget.signers!.isNotEmpty) {
                _showSignersDialog("Sign");
              } else {
                _addDraggableItem("Sign");
              }
            },
          ),
          SpeedDialChild(
            child: Image.asset(
              'assets/text.png',
              width: 30,
              height: 30,
            ),
            label: 'Name',
            labelStyle:
                textStyle('Poppins', 14, Color(0xff2D3748), FontWeight.w500),
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
            labelStyle:
                textStyle('Poppins', 14, Color(0xff2D3748), FontWeight.w500),
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
  Offset position = Offset(0, 0);
  bool isDragging = false;
  bool isSelected = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) {
        setState(() {
          isDragging = true;
        });
      },
      onPanUpdate: (details) {
        setState(() {
          position += details.delta;
        });
        widget.onDrag(position);
      },
      onPanEnd: (_) {
        setState(() {
          isDragging = false;
        });
      },
      onTap: () {
        setState(() {
          isSelected = !isSelected;
        });
        widget.onTextTap();
      },
      child: Stack(
        children: [
          // Colored container with text
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.1), // Light background color
              border: Border.all(
                color: widget.color, // Border color matches text color
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.text,
              style: textStyleVersion2(
                color: widget.color,
              ),
            ),
          ),

          // Delete icon when selected
          if (isSelected)
            Positioned(
              right: -15.w,
              top: -15.h,
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: widget.onDelete,
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
