// ignore_for_file: unused_field

import 'dart:async';
import 'dart:io';

import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/Helper/important_fun.dart';
import 'package:Electrony/Networking/api_services.dart';
import 'package:Electrony/Theming/colors.dart';
import 'package:Electrony/UI/auth/login.dart';
import 'package:Electrony/UI/signture_history.dart';
import 'package:Electrony/bloc/Auth/auth_blok.dart';
import 'package:Electrony/bloc/Auth/auth_event.dart';
import 'package:Electrony/bloc/Auth/auth_state.dart';
import 'package:Electrony/profil_feture/privacy.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:page_transition/page_transition.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FlutterSecureStorage storage = FlutterSecureStorage();
  final AuthApiService apiService =
      AuthApiService(baseUrl: 'http://139.59.134.100:8055');
  String? _profileImageUrl; // Store the URL for the profile image
  String? _userEmail;
  String? _firstName;
  String? _lastName;
  String? _phonneNumber;

  List profilFeatures = [
    {
      'leading': Image.asset(
        'assets/images/signature.png',
        width: 30,
        height: 30,
      ),
      'title': Text('My Signature',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17)),
      'trailing': Icon(Icons.arrow_forward_ios_outlined),
      'destination': SignaturesListScreen(), // Replace with the actual screen
    },
    {
      'leading': Image.asset(
        'assets/images/privacy-policy.png',
        width: 30,
        height: 30,
      ),
      'title': Text('Privacy and Policy',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17)),
      'trailing': Icon(Icons.arrow_forward_ios_outlined),
      'destination': Privacy(),
    },
  ];
  bool _isConnected = true;
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    loadUserProfile();
    _loadUserProfileWithTimeout();
    _checkInternetAndLoadProfile();
  }

  Future<void> _checkInternetAndLoadProfile() async {
    ConnectivityResult connectivityResult =
        await Connectivity().checkConnectivity();
    bool isConnected = connectivityResult != ConnectivityResult.none;

    setState(() {
      _isConnected = isConnected;
    });

    if (isConnected) {
      await _loadUserProfileWithTimeout();
    } else {
      showCustomSnackBar(context, 'No internet connection. Please try again.',
          isError: true);
    }
  }

  Future<void> _handleExpiredToken() async {
    final token = await storage.read(key: 'authToken');
    if (token == null) {
      // Navigate to login if token is missing or expired
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserProfileWithTimeout() async {
    // Show the loading spinner for 4 seconds max
    try {
      final result = await Future.any([
        loadUserProfile(),
        Future.delayed(Duration(seconds: 3),
            () => throw TimeoutException("Loading timed out"))
      ]);
      setState(() {
        _isLoading = false;
      });
      return result;
    } on TimeoutException catch (_) {
      // Timeout reached, check if token has expired
      await _handleExpiredToken();
    } catch (e) {
      print("Error loading profile: $e");
      await _handleExpiredToken();
    }
  }

  Future<void> loadUserProfile() async {
    try {
      final userProfile = await apiService.getUserProfile();
      print("User Profile: $userProfile");

      setState(() {
        _userEmail = userProfile['email'] ?? 'No email available';
        _firstName = userProfile['first_name'] ?? 'No first name';
        _lastName = userProfile['last_name'] ?? 'No last name';
        _phonneNumber = userProfile['phone_number'] ?? 'No phone';
        // Safely handle different types in signedDocument

        final avatarId = userProfile['avatar'];
        _profileImageUrl = avatarId != null && avatarId.isNotEmpty
            ? 'http://139.59.134.100:8055/assets/$avatarId'
            : 'http://139.59.134.100:8055/assets/fe9e38f9-d43d-4d34-97d6-7e759ff91a9e'; // Default avatar
      });
    } catch (e) {
      print("Error loading profile: $e");
    }
  }

  // Function to pick image
  Future<void> _pickAndUploadProfileImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      File imageFile = File(image.path);
      await _uploadProfileImage(
          imageFile); // Call the upload function after picking the image
    } else {
      // Handle no image selected case
      print('No image selected.');
    }
  }

  // Upload and update the profile image
  Future<void> _uploadProfileImage(File imageFile) async {
    try {
      waitingToSave(context);
      String imageFileId = await apiService.uploadProfileImage(imageFile);
      await apiService.updateUserProfileImage(imageFileId);
      print("Profile image uploaded successfully");
      Navigator.of(context).pop();
      // Reload user profile to reflect the new image
      loadUserProfile();
      showCustomSnackBar(
        context,
        'Profile updated successfully.',
      );
    } catch (e) {
      print("Error uploading profile image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(apiService: apiService),
      child: Scaffold(
        backgroundColor: PrimaryColors.bluegray50,
        body: _isLoading
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
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : !_isConnected
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, size: 60, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          'No Internet Connection',
                          style: TextStyle(fontSize: 18, color: Colors.black54),
                        ),
                        SizedBox(height: 20.h),
                        Container(
                          width: 190.w,
                          height: 60.h,
                          child: ElevatedButton(
                            style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(
                                    PrimaryColors.mainColor)),
                            onPressed: _checkInternetAndLoadProfile,
                            child: Text(
                              'Retry',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 17.sp),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : _userEmail == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/cooldown.png',
                              scale: 3,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Session Expired',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.black54),
                            ),
                            SizedBox(height: 20.h),
                            Container(
                              width: 190.w,
                              height: 60.h,
                              child: ElevatedButton(
                                style: ButtonStyle(
                                    backgroundColor: WidgetStateProperty.all(
                                        PrimaryColors.mainColor)),
                                onPressed: () async {
                                  Navigator.pushAndRemoveUntil(
                                      context,
                                      PageTransition(
                                          type: PageTransitionType.fade,
                                          child: Login()),
                                      (Route<dynamic> route) => false);
                                },
                                child: Text(
                                  'Login',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 17.sp),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          width: double.infinity,
                          child: SafeArea(
                            child: ListView(
                              shrinkWrap: true,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 15.h,
                                    ),
                                    Text('Profile',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 30.sp,
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(height: 30.h),
                                    Row(
                                      children: [
                                        Stack(
                                          children: [
                                            Container(
                                              width: 135.w,
                                              height: 135.h,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Color.fromARGB(
                                                      255, 15, 60, 70),
                                                  width:
                                                      4.0, // Change the width to your desired border width
                                                ),
                                              ),
                                              child: CircleAvatar(
                                                backgroundColor: Colors.white,
                                                radius: 50,
                                                backgroundImage: NetworkImage(
                                                    _profileImageUrl!), // Use NetworkImage for URL
                                              ),
                                            ),
                                            Positioned(
                                                bottom: -8.h,
                                                right: 0,
                                                child: Container(
                                                  width: 52.w,
                                                  height: 52.h,
                                                  decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.white),
                                                  child: IconButton(
                                                    onPressed: () async {
                                                      // This should trigger the image picking and uploading process
                                                      await _pickAndUploadProfileImage();
                                                    },
                                                    icon: Icon(
                                                      Icons.camera_alt,
                                                      color: Colors.black,
                                                    ),
                                                    iconSize: 27.spMin,
                                                  ),
                                                ))
                                          ],
                                        ),
                                        SizedBox(width: 20.w),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '$_firstName $_lastName',
                                                overflow: TextOverflow.visible,
                                                softWrap: true,
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 20.sp,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              SizedBox(height: 5.h),
                                              Text(
                                                '$_userEmail',
                                                overflow: TextOverflow.visible,
                                                softWrap: true,
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 20.sp,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 40.h),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8.0.w),
                                      child: ListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount: profilFeatures.length,
                                          itemBuilder: (context, index) {
                                            return InkWell(
                                              onTap: () {
                                                Navigator.push(
                                                    context,
                                                    PageTransition(
                                                        type: PageTransitionType
                                                            .fade,
                                                        child: profilFeatures[
                                                                index]
                                                            ['destination']));
                                              },
                                              child: Card(
                                                color: Colors.white,
                                                elevation: 3,
                                                child: ListTile(
                                                  leading: profilFeatures[index]
                                                      ['leading'],
                                                  title: profilFeatures[index]
                                                      ['title'],
                                                  trailing:
                                                      profilFeatures[index]
                                                          ['trailing'],
                                                ),
                                              ),
                                            );
                                          }),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8.w, vertical: 3.h),
                                      child: BlocConsumer<AuthBloc, AuthState>(
                                        listener: (context, state) {
                                          if (state is LogoutSuccess) {
                                            Navigator.pushReplacement(
                                                context,
                                                PageTransition(
                                                    type:
                                                        PageTransitionType.fade,
                                                    child: Login()));
                                          } else if (state is LogoutFailure) {
                                            showCustomSnackBar(context,
                                                'Logout failed. Please try again.',
                                                isError: true);
                                          }
                                        },
                                        builder: (context, state) {
                                          return InkWell(
                                            onTap: () async {
                                              context
                                                  .read<AuthBloc>()
                                                  .add(AuthLogoutRequested());
                                            },
                                            child: Card(
                                              color: Colors.white,
                                              elevation: 3,
                                              child: ListTile(
                                                leading:
                                                    Icon(Icons.logout_outlined),
                                                title: Text('Logout',
                                                    style: TextStyle(
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 17)),
                                                trailing: Icon(Icons
                                                    .arrow_forward_ios_outlined),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
      ),
    );
  }
}
