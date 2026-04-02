import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'storage/storage.dart';
import 'theme/app_themes.dart';

class MsmTrackerApp extends StatefulWidget {
  const MsmTrackerApp({super.key});

  @override
  State<MsmTrackerApp> createState() => _MsmTrackerAppState();
}

class _MsmTrackerAppState extends State<MsmTrackerApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = Storage.loadThemeMode();
  }

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
    Storage.saveThemeMode(_themeMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MSM Daily Tracker',
      themeMode: _themeMode,
      theme: msmLightTheme(),
      darkTheme: msmDarkTheme(),
      home: HomeScreen(
        themeMode: _themeMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
