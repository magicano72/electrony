import 'package:Electrony/Helper/utils.dart';
import 'package:Electrony/Theming/colors.dart';
import 'package:flutter/material.dart';

// ignore: must_be_immutable
class CustomSearchView extends StatelessWidget {
  CustomSearchView(
      {this.shape,
      this.padding,
      this.variant,
      this.fontStyle,
      this.alignment,
      this.width,
      this.margin,
      this.controller,
      this.onTap,
      this.focusNode,
      this.hintText,
      this.readOnly = false,
      required this.isDark,
      this.prefix,
      this.prefixConstraints,
      this.suffix,
      this.suffixConstraints,
      this.onChanged});

  SearchViewShape? shape;
  bool isDark;
  SearchViewPadding? padding;

  SearchViewVariant? variant;

  SearchViewFontStyle? fontStyle;
  void Function(String)? onChanged;
  Alignment? alignment;
  bool readOnly;
  VoidCallback? onTap;

  double? width;

  EdgeInsetsGeometry? margin;

  TextEditingController? controller;

  FocusNode? focusNode;

  String? hintText;

  Widget? prefix;

  BoxConstraints? prefixConstraints;

  Widget? suffix;

  BoxConstraints? suffixConstraints;

  @override
  Widget build(BuildContext context) {
    return alignment != null
        ? Align(
            alignment: alignment ?? Alignment.center,
            child: _buildSearchViewWidget(),
          )
        : _buildSearchViewWidget();
  }

  _buildSearchViewWidget() {
    return Container(
      width: (width ?? 0),
      margin: margin,
      child: TextFormField(
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        controller: controller,
        focusNode: focusNode,
        style: _setFontStyle(),
        decoration: _buildDecoration(),
      ),
    );
  }

  _buildDecoration() {
    return InputDecoration(
      hintText: hintText ?? "",
      hintStyle: _setFontStyle(),
      border: _setBorderStyle(),
      enabledBorder: _setBorderStyle(),
      focusedBorder: _setBorderStyle(),
      disabledBorder: _setBorderStyle(),
      prefixIcon: prefix,
      prefixIconConstraints: prefixConstraints,
      suffixIcon: suffix,
      suffixIconConstraints: suffixConstraints,
      fillColor: _setFillColor(),
      filled: _setFilled(),
      isDense: true,
      contentPadding: _setPadding(),
    );
  }

  _setFontStyle() {
    switch (fontStyle) {
      case SearchViewFontStyle.SourceSansProSemiBold16:
        return TextStyle(
          color: PrimaryColors.gray300,
          fontSize: 16,
          fontFamily: 'Source Sans Pro',
          fontWeight: FontWeight.w600,
        );
      case SearchViewFontStyle.SourceSansProSemiBold16Gray900a2:
        return TextStyle(
          fontSize: 16,
          fontFamily: 'Source Sans Pro',
          fontWeight: FontWeight.w600,
        );
      default:
        return TextStyle(
          fontSize: 14,
          fontFamily: 'Source Sans Pro',
          fontWeight: FontWeight.w400,
        );
    }
  }

  _setOutlineBorderRadius() {
    switch (shape) {
      default:
        return BorderRadius.circular(20);
    }
  }

  _setBorderStyle() {
    switch (variant) {
      case SearchViewVariant.OutlineBluegray50:
        return OutlineInputBorder(
          borderRadius: _setOutlineBorderRadius(),
          borderSide: BorderSide(
            color: PrimaryColors.blueA40019,
            width: 1,
          ),
        );
      case SearchViewVariant.OutlineBlueA400:
        return OutlineInputBorder(
          borderRadius: _setOutlineBorderRadius(),
          borderSide: BorderSide(
            style: BorderStyle.solid,
            color: PrimaryColors.blueA40019,
            width: 2,
          ),
        );
      default:
        return OutlineInputBorder(
          borderRadius: _setOutlineBorderRadius(),
          borderSide: BorderSide.none,
        );
    }
  }

  _setFillColor() {
    switch (variant) {
      case SearchViewVariant.OutlineBluegray50:
        return isDark ? PrimaryColors.darkTextField : PrimaryColors.whiteA700;
      case SearchViewVariant.OutlineBlueA400:
        return isDark ? PrimaryColors.darkTextField : PrimaryColors.whiteA700;
      default:
        return isDark ? PrimaryColors.darkTextField : PrimaryColors.gray100;
    }
  }

  _setFilled() {
    switch (variant) {
      case SearchViewVariant.FillGray100:
        return true;
      default:
        return true;
    }
  }

  _setPadding() {
    switch (padding) {
      default:
        return getPadding(
          all: 15,
        );
    }
  }
}

enum SearchViewShape {
  CircleBorder24,
}

enum SearchViewPadding {
  PaddingAll15,
}

enum SearchViewVariant {
  FillGray100,
  OutlineBluegray50,
  OutlineBlueA400,
}

enum SearchViewFontStyle {
  SourceSansProRegular14,
  SourceSansProSemiBold16,
  SourceSansProSemiBold16Gray900a2,
}
