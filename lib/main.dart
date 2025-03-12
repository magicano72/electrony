import 'package:Electrony/Networking/api_services.dart';
import 'package:Electrony/UI/auth/login.dart';
import 'package:Electrony/UI/auth/otp_verification_screen.dart';
import 'package:Electrony/UI/auth/register.dart';
import 'package:Electrony/UI/dashboard.dart';
import 'package:Electrony/bloc/Auth/auth_blok.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

Future<bool> checkInternetConnection() async {
  var connectivityResult = await (Connectivity().checkConnectivity());
  return connectivityResult != ConnectivityResult.none;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final FlutterSecureStorage storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Handle app resume
    }
  }

  @override
  Widget build(BuildContext context) {
    final authApiService =
        AuthApiService(baseUrl: 'http://139.59.134.100:8055');

    return BlocProvider(
      create: (context) => AuthBloc(
        apiService: authApiService,
      ),
      child: ScreenUtilInit(
        designSize: const Size(448, 998),
        minTextAdapt: true,
        splitScreenMode: true,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: OTPVerificationScreen(),
          routes: {
            '/login': (context) => Login(),
            '/register': (context) => RegisterScreen(),
            '/dashboard': (context) => DashboardScreen(),
          },
        ),
      ),
    );
  }
}
