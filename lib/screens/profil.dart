import 'dart:async';

import 'package:Electrony/Custom/button.dart';
import 'package:Electrony/Custom/snacbar.dart';
import 'package:Electrony/bloc/master_event.dart';
import 'package:Electrony/bloc/master_logic.dart';
import 'package:Electrony/bloc/master_state.dart';
import 'package:Electrony/custom/shimmer_loading.dart';
import 'package:Electrony/networking/api_services.dart';
import 'package:Electrony/screens/authentication/kyc/chosse_identity_verification_method.dart';
import 'package:Electrony/screens/authentication/login.dart';
import 'package:Electrony/screens/docs_history/signture_history.dart';
import 'package:Electrony/theming/colors.dart';
import 'package:Electrony/theming/style.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shimmer/shimmer.dart';

import '../profil_feture/privacy.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final apiService = AuthApiService(baseUrl: dotenv.env['API_BASE_URL'] ?? '');
  String? _profileImageUrl;
  String? _userEmail;
  String? _firstName;
  String? _lastName;
  String? _phoneNumber;
  String? _birthDate;
  bool _isConnected = true;
  bool _isLoading = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

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
      'destination': SignaturesListScreen(),
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

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _isLoading = false;
    super.dispose();
  }

  void _updateProfile() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  void _checkConnectivityAndLoadProfile() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isConnected = connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.mobile);

    if (mounted) {
      setState(() {
        _isConnected = isConnected;
      });

      if (isConnected) {
        context.read<MasterBloc>().add(LoadUserProfile());
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Initial connectivity check
    _checkConnectivityAndLoadProfile();

    // Set up connectivity listener for changes
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final bool hasConnection = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.mobile);

      if (mounted) {
        // Only reload if we're transitioning from offline to online
        if (!_isConnected && hasConnection) {
          setState(() {
            _isConnected = true;
          });
          context.read<MasterBloc>().add(LoadUserProfile());
          showCustomSnackBar(
              context, 'Connection restored! Loading profile...');
        } else if (_isConnected && !hasConnection) {
          setState(() {
            _isConnected = false;
          });
        }
      }
    });
  }

  Widget _buildOfflineState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 80, color: Colors.grey[400]),
          SizedBox(height: 24),
          Text(
            'No Internet Connection',
            style: textStyleVersion2(
                fontWeight: FontWeight.bold, color: Colors.black54),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 50),
            child: Text(
              'Check your connection and try again. Some features may be unavailable while offline.',
              textAlign: TextAlign.center,
              style: textStyleVersion2(fontSize: 14, color: Colors.black54),
            ),
          ),
          SizedBox(height: 30),
          Container(
              width: 190.w,
              height: 60.h,
              child: CustomButton(
                  text: 'Retry', onPressed: _checkConnectivityAndLoadProfile)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted) return Container();

    return Scaffold(
      backgroundColor: Colors.white,
      body: !_isConnected
          ? _buildOfflineState()
          : Stack(
              children: [
                BlocListener<MasterBloc, MasterState>(
                  listener: (context, state) {
                    if (state is ProfileImageUploadLoading) {
                      // Show a loading indicator in the center of the screen
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return Center(
                            child: Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!,
                                    highlightColor: Colors.grey[100]!,
                                    child: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!,
                                    highlightColor: Colors.grey[100]!,
                                    child: Container(
                                      width: 150,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    } else if (state is ProfileImageUploadSuccess ||
                        state is ProfileImageUploadFailure) {
                      Navigator.of(context, rootNavigator: true)
                          .pop(); // Dismiss the loading dialog
                    }
                    if (state is ProfileImageUploadSuccess) {
                      showCustomSnackBar(
                        context,
                        'Profile updated successfully.',
                      );
                      context.read<MasterBloc>().add(LoadUserProfile());
                    } else if (state is ProfileImageUploadFailure) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.errorMessage)),
                      );
                    } else if (state is LogoutSuccess) {
                      Navigator.pushReplacement(
                        context,
                        PageTransition(
                          type: PageTransitionType.fade,
                          child: Login(),
                        ),
                      );
                    } else if (state is LogoutFailure) {
                      showCustomSnackBar(
                        context,
                        'Logout failed. Please try again.',
                        isError: true,
                      );
                    }
                  },
                  child: BlocBuilder<MasterBloc, MasterState>(
                    builder: (context, state) {
                      if (state is UserProfileLoading) {
                        return ShimmerLoading();
                      } else if (state is LogoutLoading) {
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
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      } else if (state is UserProfileLoaded) {
                        _userEmail =
                            state.userProfile['email'] ?? 'No email available';
                        _firstName =
                            state.userProfile['first_name'] ?? 'No first name';
                        _lastName =
                            state.userProfile['last_name'] ?? 'No last name';
                        _phoneNumber = state.userProfile['phone'] ?? 'No phone';
                        _birthDate =
                            state.userProfile['birth_date'] ?? 'No birth date';
                        final avatarId = state.userProfile['avatar'];
                        _profileImageUrl =
                            avatarId != null && avatarId.isNotEmpty
                                ? '${apiService.baseUrl}/assets/$avatarId'
                                : null;
                        final userStatus = state.userProfile['status'] ?? '';

                        return SafeArea(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF176A9F),
                                        Color(0xFF6AB7E9)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(30)),
                                  ),
                                  padding:
                                      EdgeInsets.only(top: 50.h, bottom: 90.h),
                                  child: Text(
                                    'My Profile',
                                    style: textStyleVersion2(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Transform.translate(
                                  offset: Offset(0, -70),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                          border: Border.all(
                                              color: Colors.white, width: 4),
                                        ),
                                        child: ClipOval(
                                          child: CircleAvatar(
                                            radius: 65,
                                            backgroundColor: Colors.grey[200],
                                            backgroundImage:
                                                _profileImageUrl != null
                                                    ? NetworkImage(
                                                        _profileImageUrl!)
                                                    : const AssetImage(
                                                            'assets/avatar.png')
                                                        as ImageProvider,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 1,
                                        right: 1,
                                        child: GestureDetector(
                                          onTap: () {
                                            context.read<MasterBloc>().add(
                                                PickAndUploadProfileImage());
                                          },
                                          child: Container(
                                            padding: EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Color(0xFF6AB7E9),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                                Icons
                                                    .mode_edit_outline_outlined,
                                                size: 25,
                                                color: Colors.black),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Transform.translate(
                                  offset: Offset(0, -45),
                                  child: Container(
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$_firstName $_lastName',
                                      style: textStyleVersion2(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                Center(
                                    child: Transform.translate(
                                  offset: Offset(0, -25),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFE6F8FF),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$_userEmail',
                                      style: textStyleVersion2(
                                        color: Color(0xFF3F90C3),
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )),
                                // Added user status section
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 40.w, vertical: 8.h),
                                  child: userStatus == 'unverified'
                                      ? Container(
                                          width: 140.w,
                                          height: 50.h,
                                          child: CustomButton(
                                            text: 'Verify',
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                PageTransition(
                                                  type: PageTransitionType.fade,
                                                  child:
                                                      ChooseIdentityVerificationMethod(),
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                      : userStatus == 'archived'
                                          ? Text(
                                              'Your account is under review. Please wait for approval.',
                                              style: textStyleVersion2(
                                                fontSize: 14,
                                              ),
                                              textAlign: TextAlign.center,
                                            )
                                          : SizedBox.shrink(),
                                ),
                                Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 40.w),
                                  child: Divider(
                                    color: Color(0xFFEAECF0),
                                  ),
                                ),
                                _buildMenuItem(
                                  icon: Icons.person_outline,
                                  title: 'Edit Profile',
                                  onTap: () {},
                                ),
                                Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 40.w),
                                  child: Divider(
                                    color: Color(0xFFEAECF0),
                                  ),
                                ),
                                _buildMenuItem(
                                  icon: Icons.settings_outlined,
                                  title: 'Settings',
                                  onTap: () {},
                                ),
                                Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 40.w),
                                  child: Divider(
                                    color: Color(0xFFEAECF0),
                                  ),
                                ),
                                _buildMenuItem(
                                  icon: Icons.logout,
                                  title: 'Logout',
                                  isLogout: true,
                                  onTap: () {
                                    context
                                        .read<MasterBloc>()
                                        .add(AuthLogoutRequested());
                                  },
                                ),
                                Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 40.w),
                                  child: Divider(
                                    color: Color(0xFFEAECF0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      } else if (state is UserProfileLoadFailure) {
                        return Center(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
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
                                      backgroundColor:
                                          MaterialStateProperty.all(
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
                        );
                      }
                      return Container();
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// Wrap the ProfileScreen with BlocProvider
class ProfileScreenWrapper extends StatelessWidget {
  final apiService = AuthApiService(baseUrl: dotenv.env['API_BASE_URL'] ?? '');

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MasterBloc(apiService: apiService),
      child: ProfileScreen(),
    );
  }
}

Widget _buildMenuItem({
  required IconData icon,
  required String title,
  required VoidCallback onTap,
  bool isLogout = false,
}) {
  final color = isLogout ? Colors.red : Color(0xff186A9E);

  return ListTile(
    leading: Icon(icon, color: color),
    title: Text(
      title,
      style: textStyleVersion2(
        color:
            isLogout ? const Color.fromARGB(255, 232, 106, 97) : Colors.black,
        fontWeight: FontWeight.w400,
      ),
    ),
    trailing: Icon(Icons.chevron_right, color: color, size: 20),
    onTap: onTap,
  );
}
