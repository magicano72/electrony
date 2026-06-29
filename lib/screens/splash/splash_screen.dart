import 'package:Electrony/screens/authentication/login.dart';
import 'package:Electrony/screens/onBoarding/on_boaring_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreenWithLogic extends StatefulWidget {
  const SplashScreenWithLogic({Key? key}) : super(key: key);

  @override
  _SplashScreenWithLogicState createState() => _SplashScreenWithLogicState();
}

class _SplashScreenWithLogicState extends State<SplashScreenWithLogic>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  Animation<double>? _opacityAnimation;
  Animation<Gradient?>? _gradientAnimation;
  Animation<Color?>? _colorAnimation;
  Animation<Offset>? _imageSlideAnimation;
  Animation<Offset>? _textSlideAnimation;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool? _isFirstTime;
  bool _initialized = false;

  late final Future<void> _initFuture;

  Future<void> _initializeApp() async {
    try {
      final hasSeenOnboarding = await _storage.read(key: 'hasSeenOnboarding');
      _isFirstTime = hasSeenOnboarding != 'true';
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Initialization error: $e');
      _isFirstTime = true;
    }
  }

// Add this method inside the _SplashScreenWithLogicState class, before the @override build method
  void _navigateToNextScreen() {
    if (!mounted) return;

    Widget nextScreen;
    if (_isFirstTime == true) {
      nextScreen = OnboardingPage();
    } else {
      nextScreen = const Login();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  void _setupAnimations() {
    if (_initialized) return;
    _initialized = true;

    // Image slide from top animation
    _imageSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.04, 0.4, curve: Curves.easeOut),
      ),
    );

    // Text slide from left animation
    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(-2, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.04, 0.4, curve: Curves.easeOut),
      ),
    );

    // Opacity animation starts after white screen (100ms)
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.04, 0.4, curve: Curves.easeIn), // Earlier start
      ),
    );

    // Color animation for content - faster transition
    _colorAnimation = ColorTween(
      begin: const Color(0xFF176A9F),
      end: Colors.white,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.6,
            curve: Curves.easeInOut), // Shorter interval
      ),
    );

    // Gradient animation - faster transition
    _gradientAnimation = TweenSequence<Gradient?>([
      TweenSequenceItem(
        weight: 1.0,
        tween: GradientTween(
          begin: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white],
          ),
          end: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.topLeft,
            colors: [Color(0xFF6AB7E9), Color(0xFF176A9F)],
          ),
        ),
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve:
            const Interval(0.4, 0.6, curve: Curves.easeIn), // Shorter interval
      ),
    );

    _controller.forward();

    Future.wait([
      _initFuture,
      Future.delayed(
          const Duration(milliseconds: 2000)), // Reduced total duration
    ]).then((_) => _navigateToNextScreen());
  }

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeApp();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000), // Reduced total duration
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose of the animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _setupAnimations();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final isGradient = _controller.value > 0.6;
        final contentColor =
            isGradient ? Colors.white : const Color(0xFF176A9F);

        return Container(
          decoration: BoxDecoration(
            gradient: _gradientAnimation?.value ??
                const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white],
                ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 60.0),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SlideTransition(
                        position: _imageSlideAnimation!,
                        child: Opacity(
                          opacity: _opacityAnimation?.value ?? 0.0,
                          child: Image.asset(
                            'assets/images/Logocontainer.png',
                            width: 200.w, // Increased from 120
                            height: 200.h, // Increased from 120
                            color: _colorAnimation?.value ??
                                const Color(0xFF176A9F),
                          ),
                        ),
                      ),
                      SlideTransition(
                        position: _textSlideAnimation!,
                        child: Opacity(
                          opacity: _opacityAnimation?.value ?? 0.0,
                          child: Text('Electrony',
                              style: GoogleFonts.getFont('Protest Riot',
                                  color: _colorAnimation?.value ??
                                      const Color(0xff3F90C3),
                                  letterSpacing: 1.2,
                                  fontSize: 40.sp,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class GradientTween extends Tween<Gradient?> {
  GradientTween({
    Gradient? begin,
    Gradient? end,
  }) : super(begin: begin, end: end);

  @override
  Gradient? lerp(double t) {
    return Gradient.lerp(begin, end, t);
  }
}
