import 'dart:async';

import 'package:Electrony/bloc/master_event.dart';
import 'package:Electrony/bloc/master_logic.dart';
import 'package:Electrony/bloc/master_state.dart';
import 'package:Electrony/screens/dashboard/transactions/transaction_design.dart';
import 'package:Electrony/screens/docs_history/signture_history.dart';
import 'package:Electrony/screens/profil.dart';
import 'package:Electrony/screens/sign_flow/upload_document.dart';
import 'package:Electrony/screens/transfer/send_point.dart';
import 'package:Electrony/theming/style.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showReactivationNotice = false;
  bool _loadingReactivationFlag = true;
  bool _showNotificationList = false;
  bool _showAllActivities = false;
  bool isConnected = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load initial data with retry logic
      _loadInitialData();
      context.read<MasterBloc>().add(LoadActivities());
    });
    _loadReactivationSeenFlag();
    _checkConnectivityAndLoadData();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final hasConnection = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.mobile);
      if (mounted) {
        setState(() {
          isConnected = hasConnection;
          if (hasConnection) {
            context.read<MasterBloc>().add(LoadUserProfile());
            context.read<MasterBloc>().add(LoadActivities());
          }
        });
      }
    });
  }

  @override
  void dispose() {
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
        if (hasConnection) {
          context.read<MasterBloc>().add(LoadUserProfile());
          context.read<MasterBloc>().add(LoadActivities());
        }
      });
    }
  }

  Widget _buildOfflineNotice() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                  'Some features may be unavailable until connection is restored.',
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

  Future<void> _loadInitialData() async {
    int retries = 3;
    while (retries > 0) {
      try {
        context.read<MasterBloc>().add(LoadUserProfile());
        break;
      } catch (e) {
        print('Failed to load user profile, retries left: $retries');
        retries--;
        if (retries == 0) {
          print('Max retries reached for loading user profile');
          break;
        }
        await Future.delayed(Duration(seconds: 1));
      }
    }
  }

  Future<void> _loadReactivationSeenFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('reactivationSeen') ?? false;
    setState(() {
      _showReactivationNotice = !seen;
      _loadingReactivationFlag = false;
    });
  }

  Future<void> _markReactivationSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reactivationSeen', true);
    setState(() {
      _showReactivationNotice = false;
    });
  }

  Future<String?> _getValidToken() async {
    try {
      final bloc = context.read<MasterBloc>();
      final token = await bloc.apiService.getValidToken();
      return token;
    } catch (e) {
      print('Error in _getValidToken: $e');
      return null;
    }
  }

  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final completer = Completer<void>();
      bool profileLoaded = false;
      bool activitiesLoaded = false;
      String? errorMessage;

      void onStateChange(MasterState state) {
        if (state is UserProfileLoaded || state is UserProfileLoadFailure) {
          profileLoaded = true;
          if (state is UserProfileLoadFailure) {
            errorMessage = state.errorMessage;
          }
        }
        if (state is ActivitiesLoaded || state is ActivitiesLoadFailure) {
          activitiesLoaded = true;
          if (state is ActivitiesLoadFailure) {
            errorMessage = state.error;
          }
        }
        if (profileLoaded && activitiesLoaded) {
          if (errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Refresh failed: $errorMessage')),
            );
          }
          completer.complete();
        }
      }

      final subscription =
          context.read<MasterBloc>().stream.listen(onStateChange);

      context.read<MasterBloc>().add(LoadUserProfile());
      context.read<MasterBloc>().add(RefreshActivities());

      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          subscription.cancel();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Refresh timed out')),
          );
          completer.completeError('Timeout');
        },
      );

      await subscription.cancel();
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          backgroundColor: Colors.white,
          color: const Color(0xff4AAAE6),
          displacement: 20.0,
          onRefresh: _handleRefresh,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (!isConnected) _buildOfflineNotice(),
                  // Header - Depends only on user profile
                  BlocBuilder<MasterBloc, MasterState>(
                    buildWhen: (prev, curr) =>
                        curr is UserProfileLoading || curr is UserProfileLoaded,
                    builder: (context, state) {
                      if (state is UserProfileLoaded) {
                        return _buildUserHeader(state.userProfile);
                      }
                      return _buildHeaderShimmer();
                    },
                  ),

                  SizedBox(height: 30.h),

                  // Balance Card - Depends only on user profile
                  BlocBuilder<MasterBloc, MasterState>(
                    buildWhen: (prev, curr) =>
                        curr is UserProfileLoading || curr is UserProfileLoaded,
                    builder: (context, state) {
                      if (state is UserProfileLoaded) {
                        return _buildUserBalance(state.userProfile);
                      }
                      return _buildBalanceShimmer();
                    },
                  ),

                  SizedBox(height: 30.h),

                  // Quick Actions (static content)
                  _buildQuickActions(),

                  SizedBox(height: 30.h),

                  // Activities - Independent loading
                  _buildRecentActivities(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarImage(String? avatarUrl, String? token) {
    return FutureBuilder<String?>(
      future: _getValidToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircleAvatar(
            radius: 25,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final validToken = snapshot.data;
        if (validToken == null || avatarUrl == null) {
          return CircleAvatar(
            radius: 25,
            child: Image.asset('assets/avatar.png'),
          );
        }

        return CachedNetworkImage(
          imageUrl: avatarUrl,
          httpHeaders: {'Authorization': 'Bearer $validToken'},
          imageBuilder: (context, imageProvider) => CircleAvatar(
            radius: 25,
            backgroundImage: imageProvider,
          ),
          placeholder: (context, url) => CircleAvatar(
            radius: 25,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          errorWidget: (context, url, error) {
            print('Error loading avatar: $error');
            return CircleAvatar(
              radius: 25,
              child: Image.asset('assets/avatar.png'),
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderShimmer() {
    return Row(
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xff6AB7E9),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Container(width: 80, height: 16, color: Colors.grey.shade200),
        const Spacer(),
        Container(width: 30, height: 30, color: Colors.grey.shade200),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return BlocBuilder<MasterBloc, MasterState>(
      buildWhen: (prev, curr) =>
          curr is UserProfileLoading ||
          curr is UserProfileLoaded ||
          curr is UserProfileLoadFailure,
      builder: (context, state) {
        if (state is UserProfileLoaded) {
          return _buildUserBalance(state.userProfile);
        } else if (state is UserProfileLoadFailure) {
          return _buildErrorBalanceCard(state.errorMessage);
        }
        return _buildBalanceShimmer();
      },
    );
  }

  Widget _buildErrorBalanceCard(String errorMessage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          'Error loading balance: $errorMessage',
          style: textStyleVersion2(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
            color: Colors.red,
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader(Map<String, dynamic> userProfile) {
    final firstName = userProfile['first_name'] ?? '';
    final lastName = userProfile['last_name'] ?? '';
    final displayName = (firstName + ' ' + lastName).trim();
    final avatarId = userProfile['avatar'];
    final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final avatarUrl = (avatarId != null && avatarId.isNotEmpty)
        ? '$apiBaseUrl/assets/$avatarId'
        : null;

    return Row(
      children: [
        FutureBuilder<String?>(
          future: _getValidToken(),
          builder: (context, snapshot) {
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreenWrapper()),
              ),
              child: CircleAvatar(
                radius: 25,
                child: _buildAvatarImage(avatarUrl, snapshot.data),
              ),
            );
          },
        ),
        SizedBox(width: 12.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName.isNotEmpty ? displayName : 'User',
              style: textStyleVersion2(
                fontSize: 15.sp,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        const Spacer(),
        _buildNotificationIcon(),
      ],
    );
  }

  Widget _buildNotificationIcon() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _openNotificationList(context),
          child: Image.asset('assets/Notice.png', width: 30, height: 30),
        ),
        if (_showReactivationNotice && !_loadingReactivationFlag)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBalanceShimmer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF176A9F), Color(0xFF6AB7E9)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.symmetric(vertical: 8),
          ),
          SizedBox(height: 8.h),
          Container(
            width: 100,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                width: 80,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              Container(
                width: 80,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserBalance(Map<String, dynamic> userProfile) {
    String balance = userProfile['points_balance']?.toString() ?? '0.00';
    if (balance == 'null' || balance.isEmpty) balance = '0.00';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF176A9F), Color(0xFF6AB7E9)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "$balance ECP",
            style: textStyleVersion2(
              fontSize: 24.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Available Balance',
            style: textStyleVersion2(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _actionButton('assets/charge.png', 'Charge', onTap: () {
                print('Charge tapped');
              }),
              _actionButton('assets/send.png', 'Send', onTap: () async {
                await Navigator.push(
                  context,
                  PageTransition(
                    type: PageTransitionType.rightToLeft,
                    child: TransferScreen(),
                  ),
                );
                context.read<MasterBloc>().add(LoadUserProfile());
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: textStyleVersion2(
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xff0E2A43),
          ),
        ),
        SizedBox(height: 15.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _quickAction('assets/upload1.png', 'Upload File', onTap: () {
              Navigator.push(
                context,
                PageTransition(
                  type: PageTransitionType.rightToLeft,
                  child: PdfUploadAndSignScreen(),
                ),
              );
            }),
            _quickAction('assets/scanQ.png', 'Scan', onTap: () {
              Navigator.push(
                context,
                PageTransition(
                  type: PageTransitionType.rightToLeft,
                  child: PdfUploadAndSignScreen(),
                ),
              );
            }),
            _quickAction('assets/signQ.png', 'Create', onTap: () {
              Navigator.push(
                context,
                PageTransition(
                  type: PageTransitionType.rightToLeft,
                  child: SignaturesListScreen(),
                ),
              );
            }),
            _quickAction('assets/transactionQ.png', 'Transactions', onTap: () {
              Navigator.push(
                context,
                PageTransition(
                  type: PageTransitionType.rightToLeft,
                  child: TransactionScreen(),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: textStyleVersion2(
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xff0E2A43),
              ),
            ),
            BlocBuilder<MasterBloc, MasterState>(
              builder: (context, state) {
                final hasActivities =
                    state is ActivitiesLoaded && state.activities.isNotEmpty;

                return TextButton(
                  onPressed: hasActivities
                      ? () {
                          setState(() {
                            _showAllActivities = !_showAllActivities;
                          });
                        }
                      : null,
                  child: Text(
                    _showAllActivities ? 'Show Less' : 'View All',
                    style: textStyleVersion2(
                      fontSize: 14,
                      color: const Color(0xff4AAAE6),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        SizedBox(height: 10.h),
        BlocBuilder<MasterBloc, MasterState>(
          builder: (context, state) {
            if (state is ActivitiesLoading) {
              return Column(
                children: List.generate(3, (index) => _buildActivityShimmer()),
              );
            } else if (state is ActivitiesLoaded) {
              final activities = state.activities;
              if (activities.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: Center(
                    child: Text(
                      'No recent activity',
                      style: textStyleVersion2(
                        fontSize: 14.sp,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: activities
                    .take(_showAllActivities ? activities.length : 3)
                    .map((activity) => Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: _activityItem(
                            activity.icon,
                            activity.title,
                            activity.timeString,
                            activity.iconColor,
                            activity.iconBackgroundColor,
                          ),
                        ))
                    .toList(),
              );
            } else if (state is ActivitiesLoadFailure) {
              return Center(
                child: Text(
                  'Failed to load activities',
                  style: textStyleVersion2(
                    fontSize: 14.sp,
                    color: Colors.grey,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _activityItem(
    IconData icon,
    String title,
    String subtitle,
    Color iconColor,
    Color iconBackgroundColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: iconBackgroundColor,
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: textStyle(
                        'Inter',
                        14,
                        const Color(0xff0E2A43),
                        FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            thickness: 1,
            color: Color.fromARGB(64, 205, 205, 205), // Example: 25% opacity
          ),
        ],
      ),
    );
  }

  Widget _buildActivityShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 200,
                height: 16,
                color: Colors.grey.shade200,
              ),
              const SizedBox(height: 8),
              Container(
                width: 150,
                height: 14,
                color: Colors.grey.shade200,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String imagePath, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(imagePath, width: 22, height: 22),
            SizedBox(width: 8.w),
            Text(
              label,
              style: textStyle(
                "Inter",
                16,
                const Color(0xff3F90C3),
                FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(String imagePath, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Image.asset(imagePath,
                    width: 30, height: 30, fit: BoxFit.contain),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: textStyleVersion2(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff0E2A43A6).withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openNotificationList(BuildContext context) {
    if (_loadingReactivationFlag) return;

    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final state = context.read<MasterBloc>().state;
        final isReactivation = _showReactivationNotice &&
            state is UserProfileLoaded &&
            state.userProfile['status'] == 'active';

        if (!isReactivation) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No new notifications',
                style: textStyleVersion2(fontWeight: FontWeight.w500),
              ),
            ),
          );
        }

        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
          children: [
            Semantics(
              label:
                  'Account reactivated notification. Tap mark as seen to dismiss.',
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xffE6F8FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xff4AAAE6)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified, color: Color(0xff4AAAE6)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your account has been verified.',
                            style: textStyleVersion2(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff176A9F),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Align(
                            alignment: Alignment.topRight,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(40, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                alignment: Alignment.centerLeft,
                              ),
                              onPressed: () async {
                                Navigator.pop(context);
                                await _markReactivationSeen();
                              },
                              child: Text(
                                'Mark as seen',
                                style: textStyleVersion2(
                                  fontSize: 14.sp,
                                  color: const Color(0xff4AAAE6),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
