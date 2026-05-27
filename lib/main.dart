import 'dart:io';
import 'package:flutter/material.dart';

import 'screens/auth/login_screen.dart';
import 'screens/dashboard/home_screen.dart';
import 'services/auth_storage.dart';
import 'theme/app_theme.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  final loggedIn = await AuthStorage.isLoggedIn();
  runApp(CvaiApp(loggedIn: loggedIn));
}


class CvaiApp extends StatelessWidget {
  const CvaiApp({super.key, required this.loggedIn});

  /// Whether a saved session was found — if so, skip the login screen.
  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CVAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: loggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
