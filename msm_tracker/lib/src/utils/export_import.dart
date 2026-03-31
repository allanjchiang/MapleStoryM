import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';

Future<void> saveJsonFile({
  required String filename,
  required Map<String, dynamic> jsonMap,
}) async {
  final jsonText = const JsonEncoder.withIndent('  ').convert(jsonMap);
  final bytes = Uint8List.fromList(utf8.encode(jsonText));

  await FileSaver.instance.saveFile(
    name: filename,
    bytes: bytes,
    fileExtension: 'json',
    mimeType: MimeType.json,
  );
}

Future<String?> pickJsonFileText() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['json'],
    withData: kIsWeb, // On web we need bytes.
  );
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.first;
  if (file.bytes != null) {
    return utf8.decode(file.bytes!);
  }
  if (!kIsWeb && file.path != null) {
    final bytes = await File(file.path!).readAsBytes();
    return utf8.decode(bytes);
  }
  return null;
}

