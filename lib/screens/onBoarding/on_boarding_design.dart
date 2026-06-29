import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OnboardingScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget illustration;
  final VoidCallback onSkip;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final int currentPage;
  final int totalPages;

  const OnboardingScreen({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.illustration,
    required this.onSkip,
    required this.onPrev,
    required this.onNext,
    required this.currentPage,
    required this.totalPages,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onSkip,
                  child: Text(
                    "Skip",
                    style: textStyleVersion2(
                      color: Color(0xff718096),
                    ),
                  ),
                ),
              ),
            ),
            // Title and Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    title,
                    style: textStyleVersion2(
                      color: Color(0xff2D3748),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    subtitle,
                    style: textStyleVersion2(
                      fontSize: 13,
                      color: Color(0xff718096),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            // Illustration
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: illustration,
              ),
            ),
            // Page indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: index == currentPage
                        ? Colors.blue
                        : Colors.blueGrey.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
            SizedBox(height: 24.h),
            // Prev and Next buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: onPrev,
                    child: Text("Prev",
                        style: textStyleVersion2(
                          color: Colors.blueGrey.withOpacity(0.3),
                        )),
                  ),
                  TextButton(
                    onPressed: onNext,
                    child: Text("Next",
                        style: textStyleVersion2(
                          color: Color(0xff3F90C3),
                        )),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
