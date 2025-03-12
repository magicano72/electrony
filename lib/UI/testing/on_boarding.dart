import 'package:Electrony/Theming/style.dart';
import 'package:flutter/material.dart';

class OnBoarding extends StatefulWidget {
  const OnBoarding({super.key});

  @override
  State<OnBoarding> createState() => _OnBoardingState();
}

class _OnBoardingState extends State<OnBoarding> {
  List images = [
    'assets/register.jpg',
    'assets/login.jpg',
    'assets/otp.jpg',
  ];
  List titles = [
    'Register',
    'Login',
    'OTP',
  ];
  List descriptions = [
    'Register to create an account',
    'Login to your account',
    'Enter the OTP sent to your email',
  ];
  List style = [
    Style.font17secondcolor,
    Style.font23bold,
    Style.font27maincolor,
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
          itemCount: images.length,
          itemBuilder: (_, index) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(images[index]),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                  margin: EdgeInsets.only(top: 100, left: 20, right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titles[index], style: style[index]),
                      SizedBox(
                        height: 20,
                      ),
                      Text(
                        descriptions[index],
                        style: style[index],
                      ),
                      Spacer(),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (generator) {
                            return Container(
                              margin: EdgeInsets.only(right: 5),
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: index == generator
                                    ? Colors.black
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        ),
                      ),
                      SizedBox(height: 20), // Add some space at the bottom
                      if (index == images.length - 1)
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(
                                  context, '/dashboard');
                            },
                            child: Text('Go to Home'),
                          ),
                        ),
                    ],
                  )),
            );
          }),
    );
  }
}
