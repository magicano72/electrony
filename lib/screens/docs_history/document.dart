import 'package:Electrony/custom/custom_card.dart';
import 'package:Electrony/screens/dashboard/dashboard.dart';
import 'package:Electrony/screens/docs_history/my_docs.dart';
import 'package:Electrony/screens/docs_history/my_shared_docs.dart';
import 'package:Electrony/screens/docs_history/receved_docs.dart';
import 'package:Electrony/screens/docs_history/signture_history.dart';
import 'package:Electrony/theming/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:page_transition/page_transition.dart';

class DocumentCategory extends StatefulWidget {
  const DocumentCategory({super.key});

  @override
  State<DocumentCategory> createState() => _DocumentCategoryState();
}

class _DocumentCategoryState extends State<DocumentCategory> {
  List containerDetails = [
    {
      'title': 'My Signature',
      'image': 'assets/english.png',
      'distaination': Material(child: SignaturesListScreen()),
    },
    {
      'title': 'My Docs',
      'image': 'assets/contr2.png',
      'distaination': Material(child: MyDocs()),
    },
    {
      'title': 'Received Docs',
      'image': 'assets/agreement.png',
      'distaination': Material(child: ReceivedDocs()),
    },
    {
      'title': 'Shared Docs',
      'image': 'assets/contr.png',
      'distaination': Material(child: MySharedDocs()),
    },
  ];
  List filteredContainerDetails = [];

  @override
  void initState() {
    super.initState();
    filteredContainerDetails = containerDetails;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.fade,
                child: DashboardScreen(),
              )),
        ),
        title: Text(
          'Documents',
          style: textStyleVersion2(),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                itemCount: filteredContainerDetails.length,
                itemBuilder: (context, index) {
                  var detail = filteredContainerDetails[index];
                  return Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: customCard(
                      title: detail['title'],
                      imagePath: detail['image'],
                      onTap: () {
                        if (detail['distaination'] != null) {
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.fade,
                              child: detail['distaination'],
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
