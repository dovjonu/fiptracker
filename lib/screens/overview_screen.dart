import 'package:flutter/material.dart';
import 'overview_tab.dart';
import 'history_tab.dart';
import 'settings_tab.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const OverviewTab(),
    const HistoryTab(),
    const SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Pagrindinis"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Istorija"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Nustatymai"),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
