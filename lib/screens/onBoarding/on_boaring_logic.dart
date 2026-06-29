import 'package:Electrony/screens/authentication/login.dart';
import 'package:Electrony/screens/onBoarding/on_boarding_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:page_transition/page_transition.dart';

class OnboardingPage extends StatefulWidget {
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  final FlutterSecureStorage storage = FlutterSecureStorage();

  final List<Map<String, String>> onboardingData = [
    {
      "title": "Welcome to Electrony",
      "subtitle":
          "Keep files organized, signed, and shared securely in one app",
      "image": "assets/4751965.png",
    },
    {
      "title": "your all-in-one digital office",
      "subtitle": "Sign , share , chat - all in one place",
      "image": "assets/documentation1.png",
    },
    {
      "title": "Sign in Seconds, Not Days",
      "subtitle":
          "Create or upload a document, add your signature and send it securely, no printers, scanners waiting.",
      "image": "assets/agreement1.png",
    },
    {
      "title": "Easy communication ",
      "subtitle":
          "Chat with teammates directly in your documents. Need a signature? Just @mention them!",
      "image": "assets/chatcontainer.png",
    },
    {
      "title": "Safe as Vaults, Simple as ABC",
      "subtitle":
          "Authenticate the access of your account and your digital signature with biometric verification or OTP",
      "image": "assets/shield1.png",
    },
  ];

  void _skip() {
    _finishOnboarding();
  }

  void _next() {
    if (_currentPage < onboardingData.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _prev() {
    if (_currentPage > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishOnboarding() async {
    // Save that user has seen onboarding
    await storage.write(key: 'hasSeenOnboarding', value: 'true');

    Navigator.pushReplacement(
      context,
      PageTransition(
        type: PageTransitionType.fade,
        child: Login(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _controller,
        itemCount: onboardingData.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          final item = onboardingData[index];
          return OnboardingScreen(
            title: item["title"]!,
            subtitle: item["subtitle"]!,
            illustration: Image.asset(
              item["image"]!,
            ),
            onSkip: _skip,
            onPrev: _prev,
            onNext: _next,
            currentPage: _currentPage,
            totalPages: onboardingData.length,
          );
        },
      ),
    );
  }
}
