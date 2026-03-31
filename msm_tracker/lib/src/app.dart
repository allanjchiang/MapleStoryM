import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

class MsmTrackerApp extends StatelessWidget {
  const MsmTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MSM Daily Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

