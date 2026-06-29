import 'dart:convert';

import 'package:Electrony/bloc/master_event.dart';
import 'package:Electrony/bloc/master_logic.dart';
import 'package:Electrony/helper/important_fun.dart';
import 'package:Electrony/screens/transfer/success_screen.dart';
import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:page_transition/page_transition.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;
  double _senderBalance = 0.0;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _amountController.addListener(_updateBalance);
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateBalance);
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _updateBalance() {
    setState(() {});
  }

  Future<void> _showErrorDialogWithRetry(
      String message, Future<void> Function() onRetry) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await onRetry();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF4AAAE6)),
            child: Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
      final token = await authApiService.getValidToken();
      final userProfile = await _getCurrentUserProfile(token, apiBaseUrl);
      if (userProfile != null) {
        setState(() {
          _currentUser = userProfile;
          _senderBalance = (userProfile['points_balance'] ?? 0).toDouble();
          _loading = false;
        });
      } else {
        throw Exception('User not found.');
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load user data: $e';
      });
      await _showErrorDialogWithRetry(
        'Failed to load user data. Please check your connection and try again.',
        _loadUserData,
      );
    }
  }

  Future<Map<String, dynamic>?> _getCurrentUserProfile(
      String token, String apiBaseUrl) async {
    try {
      final resp = await http.get(
        Uri.parse('$apiBaseUrl/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        return data['data'];
      } else if (resp.statusCode == 401) {
        throw Exception('Authentication expired. Please login again.');
      } else {
        throw Exception('Failed to fetch profile: ${resp.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>?> _findRecipientByPhoneWithUI(
      String phone, String token, String apiBaseUrl) async {
    setState(() {
      _loading = true;
    });
    try {
      final recipient = await _findRecipientByPhone(phone, token, apiBaseUrl);
      setState(() {
        _loading = false;
      });
      if (recipient == null) {
        await _showErrorDialogWithRetry(
          'No user found with phone number "$phone". Please check the number and try again.',
          () async {
            await _findRecipientByPhoneWithUI(phone, token, apiBaseUrl);
          },
        );
        return null;
      }
      return recipient;
    } catch (e) {
      setState(() {
        _loading = false;
      });
      await _showErrorDialogWithRetry(
        'Failed to find recipient: $e',
        () async {
          await _findRecipientByPhoneWithUI(phone, token, apiBaseUrl);
        },
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> _findRecipientByPhone(
      String phone, String token, String apiBaseUrl) async {
    try {
      String cleanPhone = phone.trim();
      var userResp = await http.get(
        Uri.parse('$apiBaseUrl/users?filter[phone][_eq]=$cleanPhone'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(Duration(seconds: 30));
      if (userResp.statusCode == 200) {
        final userData = json.decode(userResp.body);
        if (userData['data'] != null && userData['data'].isNotEmpty) {
          return userData['data'][0];
        }
      }
      if (cleanPhone.startsWith('+20')) {
        String phoneWithoutCountryCode = cleanPhone.substring(3);
        userResp = await http.get(
          Uri.parse(
              '$apiBaseUrl/users?filter[phone][_eq]=$phoneWithoutCountryCode'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(Duration(seconds: 30));
        if (userResp.statusCode == 200) {
          final userData = json.decode(userResp.body);
          if (userData['data'] != null && userData['data'].isNotEmpty) {
            return userData['data'][0];
          }
        }
      }
      if (!cleanPhone.startsWith('+20') && !cleanPhone.startsWith('20')) {
        String phoneWithCountryCode = '+20$cleanPhone';
        userResp = await http.get(
          Uri.parse(
              '$apiBaseUrl/users?filter[phone][_eq]=$phoneWithCountryCode'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(Duration(seconds: 30));
        if (userResp.statusCode == 200) {
          final userData = json.decode(userResp.body);
          if (userData['data'] != null && userData['data'].isNotEmpty) {
            return userData['data'][0];
          }
        }
      }
      userResp = await http.get(
        Uri.parse(
            '$apiBaseUrl/users?filter[phone][_contains]=${cleanPhone.replaceAll('+', '')}'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(Duration(seconds: 30));
      if (userResp.statusCode == 200) {
        final userData = json.decode(userResp.body);
        if (userData['data'] != null && userData['data'].isNotEmpty) {
          return userData['data'][0];
        }
      }
      return null;
    } catch (e) {
      throw Exception('Failed to find recipient: $e');
    }
  }

  Future<void> _createTransaction(String senderId, String receiverId,
      double amount, String token, String apiBaseUrl) async {
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/items/point_transactions'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'sender': senderId,
              'receiver': receiverId,
              'amount': amount,
              'type': 'transfer',
              'status': 'success',
            }),
          )
          .timeout(Duration(seconds: 30));
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create transaction: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Transaction creation failed: $e');
    }
  }

  Future<void> _updateUserBalance(
      String userId, double newBalance, String token, String apiBaseUrl) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$apiBaseUrl/users/$userId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({'points_balance': newBalance}),
          )
          .timeout(Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception('Failed to update balance: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Balance update failed: $e');
    }
  }

  Future<bool> _processTransfer({
    required String senderId,
    required String receiverId,
    required double amount,
    required double receiverBalance,
    required String token,
    required String apiBaseUrl,
  }) async {
    try {
      await _createTransaction(senderId, receiverId, amount, token, apiBaseUrl);
      await _updateUserBalance(
          senderId, _senderBalance - amount, token, apiBaseUrl);
      await _updateUserBalance(
          receiverId, receiverBalance + amount, token, apiBaseUrl);
      context
          .read<MasterBloc>()
          .add(UpdateUserBalanceRequested(newBalance: _senderBalance - amount));
      setState(() {
        _senderBalance = _senderBalance - amount;
        _phoneController.clear();
        _amountController.clear();
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _showTransferSuccessScreen(
      double amount, Map<String, dynamic> recipient, double newBalance) async {
    await Navigator.of(context).push(
      PageTransition(
        type: PageTransitionType.fade,
        child: TransferSuccessScreen(
          amount: amount,
          recipient: recipient,
          newBalance: newBalance,
        ),
      ),
    );
  }

  String normalizePhone(String phone) {
    return phone.startsWith('+2') ? phone.substring(2) : phone;
  }

  Future<bool> _transferPoints() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      final phone = _phoneController.text.trim();
      final amountStr = _amountController.text.trim();
      final amount = double.tryParse(amountStr);
      if (phone.isEmpty) {
        throw Exception('Please enter a phone number.');
      }
      if (phone.startsWith('+2')) {
        if (phone.length != 13) {
          throw Exception('Phone number must be 13 digits if starting with +2');
        }
      } else {
        if (phone.length < 11) {
          throw Exception('Phone number must be at least 11 digits');
        }
      }
      if (amount == null || amount <= 0) {
        throw Exception('Amount must be greater than 0');
      }
      if (amount > _senderBalance) {
        throw Exception(
            'Insufficient balance. Your balance is ${_senderBalance.toStringAsFixed(2)} ECP.');
      }
      if (_currentUser == null) {
        throw Exception('User data not loaded. Please try again.');
      }
      if (normalizePhone(phone) == normalizePhone(_currentUser!['phone'])) {
        throw Exception('Cannot transfer to your own account.');
      }
      final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
      final token = await authApiService.getValidToken();
      final recipient =
          await _findRecipientByPhoneWithUI(phone, token, apiBaseUrl);
      if (recipient == null) {
        setState(() {
          _loading = false;
        });
        return false;
      }
      final String senderId = _currentUser!['id'].toString();
      final String receiverId = recipient['id'].toString();
      final receiverBalance = (recipient['points_balance'] ?? 0).toDouble();
      final confirmed = await Navigator.of(context).push<bool>(
            PageTransition(
              type: PageTransitionType.fade,
              child: ConfirmTransferScreen(
                amount: amount,
                recipient: recipient,
                senderBalance: _senderBalance,
                onConfirm: () async {
                  final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
                  final token = await authApiService.getValidToken();
                  final String senderId = _currentUser!['id'].toString();
                  final String receiverId = recipient['id'].toString();
                  final receiverBalance =
                      (recipient['points_balance'] ?? 0).toDouble();
                  return await _processTransfer(
                    senderId: senderId,
                    receiverId: receiverId,
                    amount: amount,
                    receiverBalance: receiverBalance,
                    token: token,
                    apiBaseUrl: apiBaseUrl,
                  );
                },
              ),
            ),
          ) ??
          false;
      if (confirmed) {
        await _showTransferSuccessScreen(amount, recipient, _senderBalance);
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            context.read<MasterBloc>().add(LoadUserProfile());
          }
        });
      }
      return true;
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      await _showErrorDialogWithRetry(
        (_error ?? 'An error occurred.'),
        _transferPoints,
      );
      return false;
    }
  }

  double get _newBalance {
    final amount = double.tryParse(_amountController.text) ?? 0;
    return _senderBalance - amount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.black87),
        centerTitle: true,
        title: Text('Transfer', style: textStyleVersion2()),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
              image: AssetImage('assets/Rectangle.png'), fit: BoxFit.cover),
        ),
        padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xFF4AAAE6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.account_balance_wallet,
                          color: Color(0xFF4AAAE6)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Balance',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                          Text(
                            '${_senderBalance.toStringAsFixed(2)} ECP',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFF4AAAE6)),
                          ),
                        ],
                      ),
                    ),
                    if (_loading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF4AAAE6)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xFF4AAAE6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.phone, color: Color(0xFF4AAAE6)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter recipient\'s phone number',
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xFF4AAAE6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.currency_exchange,
                          color: Color(0xFF4AAAE6)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter amount to transfer',
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Transfer amount',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _amountController.text.isEmpty
                              ? '0'
                              : _amountController.text,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '|  ECP',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your new balance: ${_newBalance.toStringAsFixed(2)} ECP',
                      style: TextStyle(
                        color: _newBalance < 0 ? Colors.red : Color(0xFF4AAAE6),
                        fontSize: 14,
                        fontWeight: _newBalance < 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_success != null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    border: Border.all(color: Colors.green[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _success!,
                          style: TextStyle(color: Colors.green[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 40),
              Container(
                width: 220,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _loading ? Colors.grey : const Color(0xFF4AAAE6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Transferring...',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16)),
                          ],
                        )
                      : Text('Transfer',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18)),
                  onPressed: _loading ? null : _transferPoints,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConfirmTransferScreen extends StatefulWidget {
  final double amount;
  final Map<String, dynamic> recipient;
  final double senderBalance;
  final Future<bool> Function() onConfirm;

  const ConfirmTransferScreen({
    super.key,
    required this.amount,
    required this.recipient,
    required this.senderBalance,
    required this.onConfirm,
  });

  @override
  State<ConfirmTransferScreen> createState() => _ConfirmTransferScreenState();
}

class _ConfirmTransferScreenState extends State<ConfirmTransferScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.onConfirm();
      if (result) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _loading = false;
          _error = 'Transfer failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipient = widget.recipient;
    final newBalance = widget.senderBalance - widget.amount;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF89C7F0), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.amount.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4AAAE6),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'ECP',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person,
                                    color: Color(0xFF4AAAE6), size: 20),
                                SizedBox(width: 10),
                                Text(
                                    'Recipient: ${recipient['first_name'] ?? ''} ${recipient['last_name'] ?? ''}',
                                    style: textStyleVersion2()),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.phone,
                                    color: Color(0xFF4AAAE6), size: 20),
                                SizedBox(width: 10),
                                Text('Phone: ${recipient['phone'] ?? ''}',
                                    style: textStyleVersion2()),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_wallet,
                                color: Color(0xFF4AAAE6), size: 20),
                            SizedBox(width: 10),
                            Text(
                                'Your new balance: ${newBalance.toStringAsFixed(2)} ECP',
                                style: textStyleVersion2(
                                  color: newBalance < 0
                                      ? Colors.red
                                      : Color(0xFF4AAAE6),
                                  fontWeight: newBalance < 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                )),
                          ],
                        ),
                      ),
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            border: Border.all(color: Colors.red[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: Colors.red[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: 40),
                      SizedBox(
                        width: 220,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _handleConfirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _loading ? Colors.grey : Color(0xFF4AAAE6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _loading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Processing...',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 16)),
                                  ],
                                )
                              : Text('Confirm transfer',
                                  style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
