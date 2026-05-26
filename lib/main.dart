import 'package:flutter/material.dart';

import 'screens/auth/login_screen.dart';
import 'screens/dashboard/home_screen.dart';
import 'services/auth_storage.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
