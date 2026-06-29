import 'package:Electrony/networking/api_services.dart';
import 'package:Electrony/screens/chat/chat_logic/chat_list.dart';
import 'package:Electrony/screens/dashboard/transactions/transaction_design.dart';
import 'package:Electrony/screens/docs_history/document.dart';
import 'package:Electrony/screens/sign_flow/upload_document.dart';
import 'package:Electrony/theming/style.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:page_transition/page_transition.dart';

import 'home.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final authApiService =
      AuthApiService(baseUrl: dotenv.env['API_BASE_URL'] ?? '');
  final PageController _pageController = PageController();

  final List<Widget> pages = [
    HomeScreen(), // Home
    DocumentCategory(), // Documents
  ];

  final List<IconData> iconList = [
    Icons.home,
    Icons.document_scanner,
    Icons.receipt_long,
    Icons.chat,
  ];

  final List<String> labelList = ['Home', 'Documents', 'Transactions', 'Chat'];
  int _bottomNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: PageView(
        controller: _pageController,
        physics: NeverScrollableScrollPhysics(),
        children: pages,
        onPageChanged: (index) {
          setState(() => _bottomNavIndex = index);
        },
      ),
      floatingActionButton: Container(
        height: 60.h,
        width: 60.w,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF176A9F),
              Color(0xFF6AB7E9),
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Padding(
            padding: EdgeInsets.all(15.0),
            child: Image.asset(
              'assets/scanIcon.png',
              color: Colors.white,
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.fade,
                child: PdfUploadAndSignScreen(),
              ),
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AnimatedBottomNavigationBar.builder(
        itemCount: iconList.length,
        tabBuilder: (int index, bool isActive) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                index == 0
                    ? 'assets/images/home.png'
                    : index == 1
                        ? 'assets/carbon_document.png'
                        : index == 2
                            ? 'assets/trans0.png'
                            : 'assets/comment.png',
                color: isActive ? Color(0xFF2F80ED) : Color(0xFF8B8B8B),
                width: 22.w,
                height: 22.h,
              ),
              SizedBox(height: 4),
              Text(
                labelList[index],
                style: textStyleVersion2(
                  color: isActive ? Color(0xFF2F80ED) : Color(0xFF8B8B8B),
                  fontSize: 11.sp,
                ),
              ),
            ],
          );
        },
        activeIndex: _bottomNavIndex,
        gapLocation: GapLocation.center,
        notchSmoothness: NotchSmoothness.softEdge,
        leftCornerRadius: 0,
        rightCornerRadius: 0,
        height: 60.h,
        backgroundColor: Color(0xffEDF2F7),
        onTap: (index) async {
          if (index == 2) {
            // Navigate to Chat screen
            await Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.rightToLeft,
                child: TransactionScreen(),
              ),
            );
          } else if (index == 3) {
            // Navigate to Profile screen
            await Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.rightToLeft,
                child: ChatListScreen(),
              ),
            );
          } else {
            setState(() {
              _bottomNavIndex = index;
            });
            _pageController.animateToPage(
              index,
              duration: Duration(milliseconds: 200),
              curve: Curves.easeInOut,
            );
          }
        },
      ),
    );
  }
}
