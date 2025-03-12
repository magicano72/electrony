import 'package:Electrony/Theming/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class Style {
  static final TextStyle font27maincolor = TextStyle(
      fontSize: 27.sp,
      color: PrimaryColors.mainColor,
      fontWeight: FontWeight.bold);
  static final TextStyle font17secondcolor = TextStyle(
      fontSize: 17.sp,
      color: PrimaryColors.secondColor,
      fontWeight: FontWeight.bold);
  static final TextStyle font17maincolor = TextStyle(
      fontSize: 17.sp,
      color: PrimaryColors.mainColor,
      fontWeight: FontWeight.bold);
  static final TextStyle font20Weight = TextStyle(
    fontSize: 20.sp,
  );
  static final TextStyle font23bold =
      TextStyle(fontSize: 23.sp, fontWeight: FontWeight.bold);

  static final TextStyle font20bold =
      TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold);
  static final TextStyle signUp = TextStyle(
      fontSize: 30.sp, fontWeight: FontWeight.bold, color: Colors.white);

  static final TextStyle signIn = TextStyle(
      fontSize: 32.sp, color: Colors.white, fontWeight: FontWeight.bold);
  static final TextStyle signDetail = GoogleFonts.getFont(
    'Inter',
    color: Colors.white,
    fontSize: 17.sp,
  );
  static final TextStyle dontHaveAccount = TextStyle(
      fontSize: 18.sp, color: Colors.grey, fontWeight: FontWeight.bold);
  static final TextStyle signUpNow = GoogleFonts.getFont('Inter',
      color: Color(0xff1D61E7), fontSize: 18.sp, fontWeight: FontWeight.bold);
  static final TextStyle forget =
      TextStyle(fontSize: 16.sp, color: Color(0xff1D61E7));
  static final TextStyle getOtp = GoogleFonts.getFont('Montserrat',
      color: Color(0xffB9B9B9), fontSize: 16.sp, fontWeight: FontWeight.bold);
  static final TextStyle getOtpDetail = GoogleFonts.getFont('Montserrat',
      color: Color(0xff3A3A3A), fontSize: 18.sp, fontWeight: FontWeight.bold);
  static final TextStyle resendOtp = GoogleFonts.getFont('Montserrat',
      color: Color(0xff2743FD), fontSize: 18.sp, fontWeight: FontWeight.bold);
}
