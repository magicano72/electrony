import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';

Widget customCard({
  required String title,
  required String imagePath,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(15),
    child: Card(
      color: Color(0xFFF5F5F5),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 4,
      shadowColor: Colors.grey.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(10.0),
        child: ListTile(
          leading: Image.asset(
            imagePath,
            width: 45,
            height: 45,
          ),
          title: Text(
            title,
            style: textStyle(
              "Poppins",
              17,
              Color(0xff1B1B1B),
              FontWeight.bold,
            ),
          ),
          trailing: Icon(Icons.arrow_forward_ios_outlined, color: Colors.grey),
        ),
      ),
    ),
  );
}
