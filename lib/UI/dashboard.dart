import 'package:Electrony/Theming/colors.dart';
import 'package:Electrony/UI/docs_history/docs_history.dart';
import 'package:Electrony/UI/profil.dart';
import 'package:Electrony/UI/upload_document.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Widget> pages = [
    SignedDocumentsListScreen(),
    PdfUploadAndSignScreen(),
    ProfileScreen(),
  ];
  int swap = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      _pageController.page?.round() == 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrimaryColors.bluegray50,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                swap = index;
              });
            },
            children: pages,
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 12,
            child: Container(
              padding: EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: PrimaryColors.whiteA700,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 5,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavBarItem(
                    imagePath: 'assets/images/contract.png',
                    label: 'Documents',
                    index: 0,
                  ),
                  _buildNavBarItem(
                    imagePath: 'assets/images/create.png',
                    label: 'Create',
                    index: 1,
                  ),
                  _buildNavBarItem(
                    imagePath: 'assets/images/user.png',
                    label: 'Profile',
                    index: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBarItem({
    required String imagePath,
    required String label,
    required int index,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          swap = index;
        });
        _pageController.animateToPage(
          index,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            imagePath,
            color: swap == index ? PrimaryColors.mainColor : Colors.grey,
            width: 30, // Adjust the width to fit your design
            height: 30, // Adjust the height to fit your design
          ),
          Text(
            label,
            style: TextStyle(
              color: swap == index ? PrimaryColors.mainColor : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
