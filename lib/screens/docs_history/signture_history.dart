import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/custom/button.dart';
import 'package:Electrony/custom/shimmer_loading.dart';
import 'package:Electrony/networking/api_services.dart';
import 'package:Electrony/screens/pdf_viewer/my_docs_pdfviewer.dart';
import 'package:Electrony/theming/colors.dart';
import 'package:Electrony/theming/style.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';

class SignaturesListScreen extends StatefulWidget {
  @override
  _SignaturesListScreenState createState() => _SignaturesListScreenState();
}

class _SignaturesListScreenState extends State<SignaturesListScreen> {
  SignatureController signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );

  List<String> signatureUrls = [];
  List<String> fileIds = [];
  List<int> id = [];
  bool isLoading = true;
  bool isSaving = false;
  bool isConnected = true;
  bool isOfflineDataAvailable = false;

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  final apiService = AuthApiService(baseUrl: dotenv.env['API_BASE_URL'] ?? '');

  @override
  void initState() {
    super.initState();
    _checkConnectivityAndLoadData();

    // Set up connectivity listener for changes
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final hasConnection = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.mobile);

      if (mounted) {
        // Only reload if we're transitioning from offline to online
        if (!isConnected && hasConnection) {
          setState(() {
            isConnected = true;
          });
          _fetchSignatures();
          showCustomSnackBar(
              context, 'Connection restored! Loading signatures...');
        } else if (isConnected && !hasConnection) {
          setState(() {
            isConnected = false;
          });
          showCustomSnackBar(
              context, 'Connection lost. Some features may be unavailable.',
              isError: true);
        }
      }
    });
  }

  @override
  void dispose() {
    signatureController.dispose();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivityAndLoadData() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final hasConnection =
        connectivityResult.contains(ConnectivityResult.wifi) ||
            connectivityResult.contains(ConnectivityResult.mobile);

    if (mounted) {
      setState(() {
        isConnected = hasConnection;
      });

      if (hasConnection) {
        await _fetchSignatures();
      } else {
        await _loadCachedSignatures();
      }
    }
  }

  // Save signatures to local storage for offline access
  Future<void> _cacheSignatures() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save the signature URLs and IDs
      await prefs.setStringList('cached_signature_urls', signatureUrls);
      await prefs.setStringList('cached_signature_fileIds', fileIds);

      // Save the signature IDs as a string list by converting ints to strings
      List<String> idStrings = id.map((i) => i.toString()).toList();
      await prefs.setStringList('cached_signature_ids', idStrings);

      // Cache images as base64 strings for offline viewing
      for (int i = 0; i < signatureUrls.length; i++) {
        try {
          final response = await http.get(Uri.parse(signatureUrls[i]));
          if (response.statusCode == 200) {
            String base64Image = base64Encode(response.bodyBytes);
            await prefs.setString('signature_image_${fileIds[i]}', base64Image);
          }
        } catch (e) {
          print("Error caching image ${signatureUrls[i]}: $e");
        }
      }
    } catch (e) {
      print("Error caching signatures: $e");
    }
  }

  // Load cached signatures for offline access
  Future<void> _loadCachedSignatures() async {
    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      List<String>? cachedUrls = prefs.getStringList('cached_signature_urls');
      List<String>? cachedFileIds =
          prefs.getStringList('cached_signature_fileIds');
      List<String>? cachedIdStrings =
          prefs.getStringList('cached_signature_ids');

      if (cachedUrls != null &&
          cachedFileIds != null &&
          cachedIdStrings != null) {
        setState(() {
          signatureUrls = cachedUrls;
          fileIds = cachedFileIds;
          id = cachedIdStrings.map((idStr) => int.parse(idStr)).toList();
          isOfflineDataAvailable = true;
        });
      }
    } catch (e) {
      print("Error loading cached signatures: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void previewSignature(BuildContext context, String url) async {
    if (!isConnected) {
      try {
        // For offline mode, try to get cached image from SharedPreferences
        final int index = signatureUrls.indexOf(url);
        if (index >= 0 && index < fileIds.length) {
          final String fileId = fileIds[index];
          final prefs = await SharedPreferences.getInstance();
          final String? cachedImage =
              prefs.getString('signature_image_$fileId');

          if (cachedImage != null && cachedImage.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    OfflineImagePreviewScreen(cachedImage: cachedImage),
              ),
            );
            return;
          }
        }

        showCustomSnackBar(
          context,
          'Cannot preview image while offline',
          isError: true,
        );
      } catch (e) {
        showCustomSnackBar(context, "Error loading cached image",
            isError: true);
      }
      return;
    }

    try {
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
    } catch (e) {
      showCustomSnackBar(context, "Error previewing file: $e", isError: true);
    }
  }

  Future<String> detectFileType(String url) async {
    try {
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
    } catch (e) {
      print("Error detecting file type: $e");
      return 'unknown';
    }
  }

  Future<void> _fetchSignatures() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      id = await apiService.fetchSignatureIntIds();
      fileIds = await apiService.fetchSignatureIds();
      signatureUrls = await apiService.getSignatureUrls(fileIds);

      // Cache the fetched signatures for offline access
      _cacheSignatures();

      if (mounted) {
        setState(() {
          isOfflineDataAvailable = true;
        });
      }
    } catch (e) {
      print("Error fetching signatures: $e");
      showCustomSnackBar(context, "Failed to load signatures", isError: true);

      // Try to load from cache as fallback
      await _loadCachedSignatures();
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteSign(String fileId) async {
    if (!isConnected) {
      showCustomSnackBar(
        context,
        'Cannot delete signatures while offline',
        isError: true,
      );
      return;
    }

    try {
      int indexToRemove = fileIds.indexOf(fileId);
      await apiService.deleteSignature([id[indexToRemove]]);

      if (mounted) {
        setState(() {
          if (indexToRemove != -1) {
            fileIds.removeAt(indexToRemove);
            id.removeAt(indexToRemove);
            signatureUrls.removeAt(indexToRemove);
          }
        });

        // Update cached data after deletion
        _cacheSignatures();

        showCustomSnackBar(context, "Signature deleted successfully.");
      }
    } catch (e) {
      print("Error deleting document: $e");
      if (mounted) {
        showCustomSnackBar(context, "Failed to delete document.",
            isError: true);
      }
    }
  }

  void _showDeleteDialog(String fileId) {
    if (!mounted) return;

    if (!isConnected) {
      showCustomSnackBar(
        context,
        'Cannot delete signatures while offline',
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
          content: Text("Are you sure you want to delete this Signature?"),
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

  void _showSignaturePad() {
    if (!isConnected) {
      showCustomSnackBar(
        context,
        'Cannot create signatures while offline',
        isError: true,
      );
      return;
    }

    // Recreate signature controller
    signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      // exportBackgroundColor: Colors.white, // Remove or comment out this line
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
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
                    onPressed: () => Navigator.pop(context),
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
              SizedBox(height: 12.h),
              Container(
                height: 250.h,
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
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (signatureController.isNotEmpty) {
                              Navigator.pop(context); // Hide pad immediately
                              setState(() {
                                isSaving = true;
                                isLoading = true;
                              });

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

                                signatureController.clear();
                                signatureController.dispose();

                                final signatureFileIds =
                                    await apiService.uploadFile(signatureFiles);
                                if (signatureFileIds.isEmpty) {
                                  showCustomSnackBar(
                                      context, "Signature upload failed!",
                                      isError: true);
                                  return;
                                }

                                await apiService
                                    .saveSignatureRecords(signatureFileIds);
                                await _fetchSignatures();

                                showCustomSnackBar(
                                    context, "Signature saved successfully!");
                              } catch (e) {
                                showCustomSnackBar(
                                    context, "Error: ${e.toString()}",
                                    isError: true);
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    isSaving = false;
                                  });
                                }
                              }
                            } else {
                              showCustomSnackBar(
                                  context, "Draw a signature first!",
                                  isError: true);
                            }
                          },
                    icon: isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text("✓", style: TextStyle(fontSize: 18)),
                    label: Text(
                      isSaving ? 'Saving...' : 'Save',
                      style: textStyleVersion2(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PrimaryColors.mainColor,
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

  Future<File> _saveSignatureToFile(Uint8List signatureBytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath =
        '${directory.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(filePath);
    await file.writeAsBytes(signatureBytes);
    return file;
  }

  Widget _buildOfflineNotice() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[700]!),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.amber[800]),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are offline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[900],
                  ),
                ),
                Text(
                  'Viewing cached signatures. Some features are disabled until connection is restored.',
                  style: TextStyle(
                    color: Colors.amber[900],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.amber[800]),
            onPressed: _checkConnectivityAndLoadData,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/signature.png',
            color: PrimaryColors.mainColor,
            width: 50.w,
            height: 50.h,
          ),
          SizedBox(height: 12.w),
          Text(
            isConnected
                ? 'No signature available'
                : 'No signature available offline',
            style: textStyleVersion2(fontSize: 22),
          ),
          SizedBox(height: 12.h),
          Text(
            isConnected
                ? 'Create your first signature'
                : 'Connect to internet to create a signature',
            style: textStyleVersion2(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 60.h),
          isConnected
              ? CustomAuthButton(
                  text: 'Create New Signature',
                  onPressed: _showSignaturePad,
                )
              : ElevatedButton.icon(
                  icon: Icon(Icons.refresh, color: Colors.white),
                  label: Text(
                    'Try Again',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PrimaryColors.mainColor,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _checkConnectivityAndLoadData,
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_outlined),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        title: Text('My Signature', style: textStyleVersion2()),
        actions: [
          if (!isLoading)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: isConnected
                  ? _fetchSignatures
                  : _checkConnectivityAndLoadData,
              tooltip: 'Refresh',
            ),
        ],
      ),
      floatingActionButton: (isConnected && signatureUrls.isNotEmpty)
          ? FloatingActionButton(
              onPressed: _showSignaturePad,
              backgroundColor: PrimaryColors.mainColor,
              child: Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          // Show an offline banner when not connected
          if (!isConnected && isOfflineDataAvailable) _buildOfflineNotice(),

          // Main content
          Expanded(
            child: isLoading
                ? ShimmerLoading()
                : signatureUrls.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        padding: EdgeInsets.all(8),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: signatureUrls.length,
                        itemBuilder: (context, index) {
                          return Card(
                            color: Color(0xFFF5F5F5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 4,
                            shadowColor: Colors.grey.withOpacity(0.3),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (isConnected)
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _showDeleteDialog(fileIds[index]);
                                          },
                                        )
                                      else
                                        SizedBox(
                                            width:
                                                48), // Placeholder for alignment
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Stack(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          previewSignature(
                                              context, signatureUrls[index]);
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(8),
                                          child: isConnected
                                              ? Image.network(
                                                  signatureUrls[index],
                                                  fit: BoxFit.contain,
                                                  loadingBuilder: (context,
                                                      child, progress) {
                                                    if (progress == null)
                                                      return child;
                                                    return Center(
                                                        child:
                                                            CircularProgressIndicator());
                                                  },
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Center(
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(Icons.error,
                                                              color:
                                                                  Colors.red),
                                                          SizedBox(height: 8),
                                                          Text(
                                                              "Error loading image",
                                                              textAlign:
                                                                  TextAlign
                                                                      .center),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                )
                                              : FutureBuilder<
                                                  SharedPreferences>(
                                                  future: SharedPreferences
                                                      .getInstance(),
                                                  builder: (context, snapshot) {
                                                    if (!snapshot.hasData) {
                                                      return Center(
                                                          child:
                                                              CircularProgressIndicator());
                                                    }

                                                    final prefs =
                                                        snapshot.data!;
                                                    final cachedImage =
                                                        prefs.getString(
                                                            'signature_image_${fileIds[index]}');

                                                    if (cachedImage != null &&
                                                        cachedImage
                                                            .isNotEmpty) {
                                                      try {
                                                        final imageBytes =
                                                            base64Decode(
                                                                cachedImage);
                                                        return Image.memory(
                                                          imageBytes,
                                                          fit: BoxFit.contain,
                                                        );
                                                      } catch (e) {
                                                        return Center(
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Icon(
                                                                  Icons
                                                                      .image_not_supported,
                                                                  color: Colors
                                                                      .grey),
                                                              SizedBox(
                                                                  height: 8),
                                                              Text(
                                                                "Cached image not available",
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        12),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }
                                                    } else {
                                                      return Center(
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Icon(Icons.wifi_off,
                                                                color: Colors
                                                                    .grey),
                                                            SizedBox(height: 8),
                                                            Text(
                                                              "Image not cached",
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: TextStyle(
                                                                  fontSize: 12),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }
                                                  },
                                                ),
                                        ),
                                      ),

                                      // Add offline indicator if needed
                                      if (!isConnected)
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.amber[100],
                                              borderRadius: BorderRadius.only(
                                                bottomLeft: Radius.circular(8),
                                              ),
                                            ),
                                            child: Text(
                                              'Offline',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.amber[900],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
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
        centerTitle: true,
        backgroundColor: PrimaryColors.bluegray50,
        elevation: 4, // Adds a slight shadow for depth
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(10), // Soft rounded bottom corners
          ),
        ),
        title: Text(
          "Signature Preview",
          style: textStyleVersion2(),
        ),
      ),
      body: Center(
        child: Image.network(
          imageUrl,
          loadingBuilder: (context, child, progress) {
            return progress == null
                ? child
                : CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            (progress.expectedTotalBytes ?? 1)
                        : null,
                    color: PrimaryColors.mainColor,
                  );
          },
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 48, color: Colors.red[300]),
                SizedBox(height: 16),
                Text(
                  "Failed to load image",
                  style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Go Back"),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class OfflineImagePreviewScreen extends StatelessWidget {
  final String cachedImage;

  OfflineImagePreviewScreen({required this.cachedImage});

  @override
  Widget build(BuildContext context) {
    final Uint8List imageBytes = base64Decode(cachedImage);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: PrimaryColors.bluegray50,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(10),
          ),
        ),
        title: Text(
          "Signature Preview",
          style: textStyleVersion2(),
        ),
      ),
      body: Center(
        child: Image.memory(
          imageBytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 48, color: Colors.red[300]),
                SizedBox(height: 16),
                Text(
                  "Failed to load cached image",
                  style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Go Back"),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
