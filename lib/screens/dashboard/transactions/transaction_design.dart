import 'dart:async';

import 'package:Electrony/custom/error_widget.dart';
import 'package:Electrony/custom/shimmer_loading.dart';
import 'package:Electrony/models/sign_model.dart';
import 'package:Electrony/screens/dashboard/transactions/transactions_logic.dart';
import 'package:Electrony/theming/style.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({Key? key}) : super(key: key);

  @override
  _TransactionScreenState createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final TransactionService _transactionService = TransactionService();
  late Future<List<Transaction>> _transactionsFuture;
  final TextEditingController _searchController = TextEditingController();

  bool isConnected = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  String? currentUserId;
  String? currentUserFirstName;
  String? currentUserLastName;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = _transactionService.fetchUserTransactions();
    _checkConnectivityAndLoadData();
    _transactionService.authApiService.getUserProfile().then((profile) {
      setState(() {
        currentUserId = profile['id']?.toString();
        currentUserFirstName = profile['first_name']?.toString();
        currentUserLastName = profile['last_name']?.toString();
        print('Current User: ' +
            (currentUserFirstName ?? '') +
            ' ' +
            (currentUserLastName ?? ''));
      });
    });
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final hasConnection = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.mobile);
      if (mounted) {
        if (!isConnected && hasConnection) {
          setState(() {
            isConnected = true;
            _transactionsFuture = _transactionService.fetchUserTransactions();
          });
        } else if (isConnected && !hasConnection) {
          setState(() {
            isConnected = false;
          });
        }
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
        _transactionsFuture = _transactionService.fetchUserTransactions();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
        title: Text('Transactions', style: textStyleVersion2()),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isConnected) _buildOfflineNotice(),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('Recent transactions',
                style:
                    textStyleVersion2(color: Color(0xff718096), fontSize: 16)),
          ),
          Expanded(
            child: FutureBuilder<List<Transaction>>(
              future: _transactionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ShimmerLoading();
                } else if (snapshot.hasError) {
                  return CustomErrorWidget(
                    message:
                        'Something went wrong while fetching transactions.',
                    onRetry: () {
                      setState(() {
                        _transactionsFuture =
                            _transactionService.fetchUserTransactions();
                      });
                    },
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/trans0.png',
                            width: 90.w, height: 90.h, fit: BoxFit.cover),
                        SizedBox(height: 16),
                        Text('No transactions found.',
                            style: textStyleVersion2(fontSize: 18)),
                      ],
                    ),
                  );
                }

                final transactions = snapshot.data!.take(10).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final isSignature =
                        transaction.type == TransactionType.signature.name;
                    final isTransfer =
                        transaction.type == TransactionType.transfer.name;
                    final hasReceiver = transaction.receiverName != null ||
                        transaction.receiver != null;

                    // Robust receiver ID extraction
                    String? receiverId;
                    if (transaction.receiver is String) {
                      receiverId = transaction.receiver;
                    } else if (transaction.receiver is Map &&
                        transaction.receiverId != null) {
                      receiverId = transaction.receiverId.toString();
                    }

                    final isReceiver =
                        (currentUserId != null && receiverId == currentUserId);
                    final isDebit = isSignature || (isTransfer && !isReceiver);

                    // Determine display name based on transaction type and user role
                    String displayName;
                    if (isSignature) {
                      displayName = 'Signature Fee';
                    } else if (isTransfer) {
                      if (isReceiver) {
                        // User is receiving - show sender's name
                        displayName = transaction.senderName ??
                            transaction.sender?.toString() ??
                            'Unknown Sender';
                      } else {
                        // User is sending - show receiver's name
                        displayName = hasReceiver
                            ? (transaction.receiverName ??
                                transaction.receiver?.toString() ??
                                'Unknown')
                            : 'Unknown';
                      }
                    } else {
                      displayName = 'Unknown';
                    }

                    print("receiverId: $receiverId, "
                        "currentUserId: $currentUserId, "
                        "isReceiver: $isReceiver, "
                        "isDebit: $isDebit, "
                        "displayName: $displayName");

                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 400 + index * 50),
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * 20),
                          child: child,
                        ),
                      ),
                      child: TransactionItem(
                        name: displayName,
                        time: DateFormat('HH:mm')
                            .format(DateTime.parse(transaction.createdAt)),
                        date: DateFormat('MMM d, yyyy')
                            .format(DateTime.parse(transaction.createdAt)),
                        amount: (isDebit ? '-€' : '+€') +
                            transaction.amount.toStringAsFixed(2),
                        isDebit: isDebit,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionItem extends StatelessWidget {
  final String name;
  final String time;
  final String date;
  final String amount;
  final bool isDebit;

  const TransactionItem({
    Key? key,
    required this.name,
    required this.time,
    required this.date,
    required this.amount,
    required this.isDebit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              // Icon container

// Option 2: Using Padding
              Container(
                width: 50.w,
                height: 50.h,
                decoration: BoxDecoration(
                  color: isDebit
                      ? const Color(0xFFFFE8E8)
                      : const Color(0xFFE8F5E8),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Padding(
                  padding: EdgeInsets.all(8.w), // Adjust padding as needed
                  child: Image.asset(
                    isDebit
                        ? ('assets/money-send.png')
                        : ('assets/money-recive.png'),
                    color: isDebit
                        ? const Color(0xFFE53E3E)
                        : const Color(0xFF38A169),
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.money_off,
                      color: isDebit
                          ? const Color(0xFFE53E3E)
                          : const Color(0xFF38A169),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              // Transaction details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: textStyleVersion2(
                        fontSize: 16,
                        color: Color(0xff2D3748),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$time | $date',
                      style: textStyleVersion2(
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        color: Color(0xff718096),
                      ),
                    ),
                  ],
                ),
              ),
              // Amount
              Text(
                amount,
                style: textStyleVersion2(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDebit
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0.w, vertical: 2.h),
          child: Divider(
            color: Color(0xffE2E8F0),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}
