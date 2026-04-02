import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'src/app.dart';
import 'src/storage/storage.dart';
import 'src/utils/timezone_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ensureTimezonesInitialized();
  await Hive.initFlutter();
  await Storage.init();
  runApp(const MsmTrackerApp());
}
