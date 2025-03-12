import 'package:flutter/material.dart';

void showCustomSnackBar(BuildContext context, String message,
    {bool isError = false, bool isSign = false // New parameter
    }) {
  final snackBar = SnackBar(
    content: Row(
      children: [
        Icon(
          (isError ? Icons.error : Icons.check_circle),
          color: Colors.white,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
                fontSize: 17, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
    backgroundColor:
        (isError ? Colors.blueAccent : Colors.green), // Blue for hint
    behavior: isSign
        ? SnackBarBehavior.fixed
        : SnackBarBehavior.floating, // Floating behavior for better
    action: SnackBarAction(
      label: 'DISMISS',
      textColor: Colors.white,
      onPressed: () {
        ScaffoldMessenger.of(context)
            .hideCurrentSnackBar(); // Close the SnackBar
      },
    ),
    duration: Duration(seconds: 2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(
        color: Colors.white, // Border color
        width: 2, // Border width
      ),
    ),
  );

  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
