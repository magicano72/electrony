import 'package:Electrony/screens/docs_history/my_docs.dart'; // Add this import
import 'package:Electrony/screens/docs_history/my_shared_docs.dart';
import 'package:Electrony/screens/docs_history/receved_docs.dart';
import 'package:Electrony/theming/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SignedDocumentsListScreen extends StatefulWidget {
  @override
  _SignedDocumentsListScreenState createState() =>
      _SignedDocumentsListScreenState();
}

class _SignedDocumentsListScreenState extends State<SignedDocumentsListScreen>
    with TickerProviderStateMixin {
  bool hasInternet = true;
  String searchQuery = "";

  late TabController _tabController;

  bool _isFetchingData = true;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);

    // Listen for tab changes & remove badge when "Received" tab is selected
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
          backgroundColor: PrimaryColors.bluegray50,
          body: DefaultTabController(
            length: 3, // Number of tabs
            child: Stack(
              children: [
                Column(
                  children: [
                    SizedBox(height: 10.h),
                    Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Column(
                        children: [
                          TabBar(
                            controller: _tabController,
                            labelColor: Colors.blue,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: Colors.blue,
                            labelStyle: TextStyle(fontWeight: FontWeight.bold),
                            tabs: [
                              Tab(text: "My Docs"),
                              Tab(text: "Received"),
                              Tab(text: "Shared"),
                            ],
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // My Docs Tab
                          MyDocs(),
                          // Received Tab
                          ReceivedDocs(),
                          MySharedDocs(),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 90,
                    )
                  ],
                ),
              ],
            ),
          )),
    );
  }
}
