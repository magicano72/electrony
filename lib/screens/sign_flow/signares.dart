// ignore_for_file: unused_local_variable

import 'package:Electrony/screens/sign_flow/me_and_other/add_signers_emails.dart';
import 'package:Electrony/screens/sign_flow/me_and_other/mark_signers_places.dart';
import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

class SignerCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget icon;
  final VoidCallback onTap;

  const SignerCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: icon,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textStyle(
                        "Poppins",
                        18,
                        Colors.black,
                        FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: textStyle(
                        "Poppins",
                        13,
                        Colors.grey.shade600,
                        FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Signers extends StatefulWidget {
  final VoidCallback? onReturnToPreview;
  const Signers({super.key, this.onReturnToPreview});

  @override
  State<Signers> createState() => _SignersState();
}

class _SignersState extends State<Signers> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Upload Document',
          style: textStyle(
            "Poppins",
            20,
            Colors.black,
            FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            SignerCard(
              title: 'Personal document',
              subtitle: 'You are the only signer',
              icon: Icon(Icons.person, color: Colors.blue, size: 24),
              onTap: widget.onReturnToPreview ?? () {},
            ),
            SignerCard(
              title: 'Shared document',
              subtitle: 'Send the document to others for multiple signatures',
              icon: Icon(Icons.send, color: Colors.blue, size: 24),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReusableEmailCollectorScreen(
                      title: "Who needs to sign?",
                      hintText: "Enter recipient email",
                      onEmailsCollected: (emails, pdfFile, isImage) {
                        Navigator.push(
                          context,
                          PageTransition(
                            type: PageTransitionType.fade,
                            child: MarkSignersPlaces(
                              pdfFile: pdfFile,
                              signers: emails,
                              isImage: isImage,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
