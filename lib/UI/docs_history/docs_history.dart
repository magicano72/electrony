import 'dart:convert';
import 'dart:io';

import 'package:Electrony/Custom/search_view.dart';
import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/Helper/important_fun.dart';
import 'package:Electrony/Theming/colors.dart';
import 'package:Electrony/UI/docs_history/my_docs.dart'; // Add this import
import 'package:Electrony/UI/docs_history/my_shared_docs.dart';
import 'package:Electrony/UI/docs_history/receved_docs.dart';
import 'package:Electrony/UI/pdf_viewer/my_docs_pdfviewer.dart';
import 'package:Electrony/models/sign_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:page_transition/page_transition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; // Updated import
import 'package:shared_preferences/shared_preferences.dart';

bool? _hasNewSignature = false; // Initialize to false

class SignedDocumentsListScreen extends StatefulWidget {
  @override
  _SignedDocumentsListScreenState createState() =>
      _SignedDocumentsListScreenState();
}

class _SignedDocumentsListScreenState extends State<SignedDocumentsListScreen>
    with TickerProviderStateMixin {
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
  late TabController _tabController;
  String? _userEmail;
  Future<List<SignatureData>> futureSignatures =
      Future.value([]); // Initialize with an empty list

  int _currentPage = 1;
  bool _isFetchingData = true; // Add this line

  List<String> receivedPdfName = [];
  List<String> receivedPdfUrls = [];
  List<String> receivedCreateTime = [];
  List<String> sharedPdfName = [];
  List<String> sharedPdfUrls = [];
  List<String> sharedCreateTime = [];

  Future<void> loadUserEmail() async {
    try {
      final userProfile = await authApiService.getUserProfile();
      print("User Profile: $userProfile");

      if (mounted) {
        setState(() {
          _userEmail = userProfile["email"]?.toString() ?? 'No email available';
        });
      }
    } catch (e) {
      print("Error loading profile: $e");
    }
  }

  Future<List<SignatureData>> fetchSignatureData() async {
    try {
      final response = await http.get(Uri.parse(
          'http://139.59.134.100:8055/items/docs?fields=user_id.email,created_at,id,created_file.id,created_file.title,created_file.filename_download,signer.signer_id.*'));

      if (response.statusCode == 200) {
        List<SignatureData> documents = parseSignatureData(response.body);

        String? token = await authApiService.getToken();
        if (token == null) throw Exception("Token is null");

        // Fetch the user's ID using their email
        final userId = JwtDecoder.decode(token)['id']?.toString() ??
            'No user ID available';
        if (userId == 'No user ID available')
          throw Exception("Failed to extract user ID from token.");
        await Future.delayed(Duration(milliseconds: 500));
        await Future.wait([
          Future(() {
            documents = documents.where((doc) {
              return doc.creatorEmail == _userEmail &&
                  doc.signers.every((signer) =>
                      signer.contriputerEmail == _userEmail &&
                      signer.userId == userId);
            }).toList();
          }),
          Future(() {
            documents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          })
        ]);

        await Future.delayed(Duration(milliseconds: 500));

        print("Fetched documents: ${documents.length}");
        for (var doc in documents) {
          print("Document ID: ${doc.id}, Title: ${doc.createdFile.title}");
        }

        // Populate the lists for filtering
        pdfUrls = documents.map((doc) => doc.createdFile.id).toList();
        fileIds = documents.map((doc) => doc.createdFile.id).toList();
        createTime = documents.map((doc) => doc.createdAt.toString()).toList();
        id = documents.map((doc) => doc.id).toList();
        pdfName = documents.map((doc) => doc.createdFile.title).toList();

        // Initialize filtered lists
        filteredPdfName = List.from(pdfName);
        filteredPdfUrls = List.from(pdfUrls);
        filteredCreateTime = List.from(createTime);

        return documents;
      } else {
        throw Exception('Failed to load signature data');
      }
    } on Exception catch (e) {
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
        receivedPdfName = List.from(pdfName);
        receivedPdfUrls = List.from(pdfUrls);
        receivedCreateTime = List.from(createTime);
        sharedPdfName = List.from(pdfName);
        sharedPdfUrls = List.from(pdfUrls);
        sharedCreateTime = List.from(createTime);
      } else {
        filteredPdfName = [];
        filteredPdfUrls = [];
        filteredCreateTime = [];
        receivedPdfName = [];
        receivedPdfUrls = [];
        receivedCreateTime = [];
        sharedPdfName = [];
        sharedPdfUrls = [];
        sharedCreateTime = [];
        for (int i = 0; i < pdfName.length; i++) {
          if (pdfName[i].toLowerCase().contains(query.toLowerCase())) {
            filteredPdfName.add(pdfName[i]);
            filteredPdfUrls.add(pdfUrls[i]);
            filteredCreateTime.add(createTime[i]);
          }
        }
        for (int i = 0; i < pdfName.length; i++) {
          if (pdfName[i].toLowerCase().contains(query.toLowerCase())) {
            receivedPdfName.add(pdfName[i]);
            receivedPdfUrls.add(pdfUrls[i]);
            receivedCreateTime.add(createTime[i]);
          }
        }
        for (int i = 0; i < pdfName.length; i++) {
          if (pdfName[i].toLowerCase().contains(query.toLowerCase())) {
            sharedPdfName.add(pdfName[i]);
            sharedPdfUrls.add(pdfUrls[i]);
            sharedCreateTime.add(createTime[i]);
          }
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
    loadUserEmail();
    _tabController = TabController(length: 3, vsync: this);
    _checkInternetAndFetchDocuments();
    checkNewSignature(); // ✅ Call once to check for new signatures

    // Listen for tab changes & remove badge when "Received" tab is selected
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        setState(() {
          _hasNewSignature = false;
        });
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

  Future<void> checkNewSignature() async {
    try {
      final response = await http.get(
        Uri.parse('http://139.59.134.100:8055/items/docs?fields=created_at'),
      );

      if (response.statusCode == 200) {
        bool isNewSignature = await isNewSignatureAvailable(response.body);

        if (mounted) {
          setState(() {
            _hasNewSignature = isNewSignature;
          });
        }
      }
    } catch (e) {
      print("Error in checkNewSignature: $e");
    }
  }

  Future<bool> isNewSignatureAvailable(String responseBody) async {
    try {
      final Map<String, dynamic> parsedJson = json.decode(responseBody);

      if (!parsedJson.containsKey('data') ||
          parsedJson['data'] == null ||
          parsedJson['data'] is! List) {
        print("No valid signature data found.");
        return false;
      }

      final List<dynamic> data = parsedJson['data'];
      if (data.isEmpty) {
        print("Signature list is empty.");
        return false;
      }

      // Extract and sort timestamps
      List<DateTime> createdAtList = data
          .map((item) => DateTime.parse(item['created_at'] as String))
          .toList();
      createdAtList.sort((a, b) => b.compareTo(a));
      final latestCreatedAt = createdAtList.first;

      // Check saved timestamp
      final prefs = await SharedPreferences.getInstance();
      final savedLatestCreatedAtString = prefs.getString('latestCreatedAt');

      if (savedLatestCreatedAtString != null) {
        final savedLatestCreatedAt = DateTime.parse(savedLatestCreatedAtString);

        if (savedLatestCreatedAt.isAfter(latestCreatedAt) ||
            savedLatestCreatedAt.isAtSameMomentAs(latestCreatedAt)) {
          return false; // No new signature
        }
      }

      await prefs.setString(
          'latestCreatedAt', latestCreatedAt.toIso8601String());
      return true;
    } catch (e) {
      print('Error parsing signature data: $e');
      return false;
    }
  }

  Future<void> _checkInternetAndFetchDocuments() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (mounted) {
          setState(() {
            hasInternet = false;
            isLoading = false;
          });
        }
        showCustomSnackBar(context, 'No internet connection.', isError: true);
      } else {
        if (mounted) {
          setState(() {
            hasInternet = true;
          });
        }
        await fetchSignatureData();
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error checking internet: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void previewSignedImage(BuildContext context, String documentId, String name,
      List<SignatureData> data) {
    final pdfUrl = 'http://139.59.134.100:8055/assets/$documentId';
    print(documentId);
    Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.fade,
        child: MyDocsPdfViewer(
          pdfUrl: pdfUrl,
          isImage: true,
          isShared: true,
          isMe: true,
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
      String name, List<SignatureData> data) {
    final pdfUrl = 'http://139.59.134.100:8055/assets/$documentId';
    print(documentId);
    Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.fade,
        child: MyDocsPdfViewer(
            pdfUrl: pdfUrl,
            isImage: false,
            isShared: true,
            meAndOthers: true,
            name: name,
            isMe: true,
            futureSignatures: data),
      ),
    ).then((_) {
      _fetchData(); // Refresh data when returning to the screen
    });
  }

  void _shareDocument(String pdfUrl, String pdfName) async {
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
      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final tempFilePath = '${tempDir.path}/${pdfName ?? 'document'}.pdf';

        final file = File(tempFilePath);
        await file.writeAsBytes(response.bodyBytes);

        await Share.shareXFiles([XFile(file.path)],
            text: 'Check out this document: ${pdfName ?? 'document'}');
      } else {
        throw Exception("Failed to download file");
      }
    } catch (e) {
      print("Error sharing document: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: PrimaryColors.bluegray50,
        body: _isFetchingData // Check if data is still being fetched
            ? Center(
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
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : isLoading
                ? Center(
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
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : hasInternet
                    ? DefaultTabController(
                        length: 3, // Number of tabs
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                SizedBox(height: 10.h),
                                Padding(
                                  padding: const EdgeInsets.all(6.0),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        height: 70, // Reduced height
                                        child: CustomSearchView(
                                          prefix: Icon(Icons.search),
                                          isDark: false,
                                          onChanged: _filterDocuments,
                                          width: double.infinity,
                                          focusNode: FocusNode(),
                                          hintText: "Search by document name",
                                        ),
                                      ),
                                      TabBar(
                                        controller: _tabController,
                                        labelColor: Colors.blue,
                                        unselectedLabelColor: Colors.grey,
                                        indicatorColor: Colors.blue,
                                        labelStyle: TextStyle(
                                            fontWeight: FontWeight.bold),
                                        tabs: [
                                          Tab(text: "My Docs"),
                                          Tab(text: "Received"),
                                          Tab(text: "Shared"),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      // My Docs Tab
                                      MyDocs(
                                        pdfNames: filteredPdfName,
                                        pdfUrls: filteredPdfUrls,
                                        createTime: filteredCreateTime,
                                      ),
                                      // Received Tab
                                      ReceivedDocs(
                                        pdfNames: receivedPdfName,
                                        pdfUrls: receivedPdfUrls,
                                        createTime: receivedCreateTime,
                                      ),
                                      MySharedDocs(
                                        pdfNames: sharedPdfName,
                                        pdfUrls: sharedPdfUrls,
                                        createTime: sharedCreateTime,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  height: 90,
                                )
                              ],
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off, size: 60, color: Colors.red),
                            SizedBox(height: 16),
                            Text(
                              'No Internet Connection',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.black54),
                            ),
                            SizedBox(height: 20.h),
                            Container(
                              width: 190.w,
                              height: 60.h,
                              child: ElevatedButton(
                                style: ButtonStyle(
                                    backgroundColor: MaterialStateProperty.all(
                                        PrimaryColors.mainColor)),
                                onPressed: _checkInternetAndFetchDocuments,
                                child: Text(
                                  'Retry',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 17.sp),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
      ),
    );
  }
}
