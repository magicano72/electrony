import 'package:Electrony/custom/button.dart';
import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TransferSuccessScreen extends StatefulWidget {
  final double amount;
  final Map<String, dynamic> recipient;
  final double newBalance;
  final String? senderAvatar;

  const TransferSuccessScreen({
    super.key,
    required this.amount,
    required this.recipient,
    required this.newBalance,
    this.senderAvatar,
  });

  @override
  State<TransferSuccessScreen> createState() => _TransferSuccessScreenState();
}

class _TransferSuccessScreenState extends State<TransferSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: EdgeInsets.all(16.sp),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4AAAE6).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/Frame29.png',
                      width: 90.w,
                      height: 90.w,
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  '${widget.amount.toStringAsFixed(2)} ECP has been sent to ${widget.recipient['first_name'] ?? 'recipient'}!',
                  textAlign: TextAlign.center,
                  style: textStyleVersion2(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    // color: const Color(0xFF4AAAE6),
                  ),
                ),
                SizedBox(height: 32.h),
                // FROM CARD
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8.h),
                  padding: EdgeInsets.all(12.sp),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6.r,
                        offset: Offset(0, 3.h),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24.r,
                        backgroundImage: widget.senderAvatar != null
                            ? NetworkImage(
                                '${apiBaseUrl.isNotEmpty ? apiBaseUrl : ''}/assets/${widget.senderAvatar}')
                            : const AssetImage('assets/avatar.png')
                                as ImageProvider,
                      ),
                      SizedBox(width: 12.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "From",
                            style: textStyleVersion2(
                              fontSize: 12.sp,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            "Personal account",
                            style: textStyleVersion2(fontSize: 16.sp),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                Icon(
                  Icons.arrow_downward,
                  color: const Color(0xFF4AAAE6),
                  size: 24.sp,
                ),
                SizedBox(height: 8.h),
                // TO CARD
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8.h),
                  padding: EdgeInsets.all(12.sp),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6.r,
                        offset: Offset(0, 3.h),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24.r,
                        backgroundColor: const Color(0xFF4AAAE6),
                        child:
                            Icon(Icons.phone, color: Colors.white, size: 20.sp),
                      ),
                      SizedBox(width: 12.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.recipient['first_name'] ?? ''} ${widget.recipient['last_name'] ?? ''}',
                            style: textStyleVersion2(fontSize: 16.sp),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            widget.recipient['phone'] ?? '',
                            style: textStyleVersion2(
                              fontSize: 14.sp,
                              color: Colors.grey[600]!,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32.h),
                SizedBox(
                  width: 160.w,
                  height: 48.h,
                  child: CustomButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).maybePop();
                    },
                    text: 'Close',
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
