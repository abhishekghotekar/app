import 'package:flutter/material.dart';

import '../../widgets/app_app_bar.dart';
import '../../widgets/app_bottom_nav.dart';
import '../attendance/attendance_list_screen.dart';
import '../cameras/camera_list_screen.dart';
import '../rules/alert_history_screen.dart';
import '../settings/settings_screen.dart';
import '../users/user_list_screen.dart';
import 'dashboard_tab.dart';

/// Main app shell: an [IndexedStack] of the five primary tabs with a
/// persistent bottom navigation bar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  late final List<Widget> _tabs = const [
    DashboardTab(),
    AttendanceListScreen(),
    CameraListScreen(),
    UserListScreen(),
    SettingsScreen(),
  ];

  void _openAlerts() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AlertHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: kBottomNavItems[_index].label,
        showBell: true,
        onBellTap: _openAlerts,
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: _tabs),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
