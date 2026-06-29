import 'package:Electrony/bloc/master_logic.dart';
import 'package:Electrony/networking/api_services.dart';
import 'package:Electrony/screens/authentication/login.dart';
import 'package:Electrony/screens/authentication/register.dart';
import 'package:audio_session/audio_session.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';

import 'screens/dashboard/dashboard.dart';

// Initialize required permissions (Microphone and Storage)
Future<bool> initializePermissions() async {
  try {
    final micStatus = await Permission.microphone.request();
    final storageStatus = await Permission.storage.request();

    if (!micStatus.isGranted || !storageStatus.isGranted) {
      return false;
    }

    final audioSession = await AudioSession.instance;
    await audioSession.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
    ));

    return true;
  } catch (e) {
    debugPrint('Error initializing permissions: $e');
    return false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  // Initialize permissions but don't block app launch on failure
  await initializePermissions();

  runApp(
    DevicePreview(
      enabled: false,
      builder: (context) => MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
    return FutureBuilder(
      future: Future.delayed(Duration(milliseconds: 100)), // Simulate font load
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return BlocProvider(
            create: (context) =>
                MasterBloc(apiService: AuthApiService(baseUrl: apiBaseUrl)),
            child: ScreenUtilInit(
              designSize: const Size(412, 732),
              minTextAdapt: true,
              splitScreenMode: true,
              child: MaterialApp(
                useInheritedMediaQuery: true,
                debugShowCheckedModeBanner: false,
                builder: DevicePreview.appBuilder,
                theme: ThemeData(
                  primarySwatch: Colors.blue,
                  visualDensity: VisualDensity.adaptivePlatformDensity,
                ),
                home: Login(),
                routes: {
                  '/login': (context) => const Login(),
                  '/register': (context) => const RegisterScreen(),
                  '/dashboard': (context) => const DashboardScreen(),
                },
              ),
            ),
          );
        } else {
          return Container(); // Placeholder while loading
        }
      },
    );
  }
}
