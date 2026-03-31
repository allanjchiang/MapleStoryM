import 'dart:convert';
import 'dart:math';

import 'package:hive/hive.dart';

import '../models/character.dart';

class Storage {
  static const _boxName = 'msm_tracker';
  static const _keyCharacters = 'characters';
  static const _keyServerRegion = 'serverRegion';

  static late final Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    if (!_box.containsKey(_keyCharacters)) {
      await _box.put(_keyCharacters, <dynamic>[]);
    }
    if (!_box.containsKey(_keyServerRegion)) {
      await _box.put(_keyServerRegion, 'asia');
    }
  }

  static List<MsmCharacter> loadCharacters() {
    final raw = _box.get(_keyCharacters);
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => MsmCharacter.fromJson(m.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  static Future<void> saveCharacters(List<MsmCharacter> characters) async {
    final encoded = characters.map((c) => c.toJson()).toList(growable: false);
    await _box.put(_keyCharacters, encoded);
  }

  static String loadServerRegion() {
    final v = _box.get(_keyServerRegion);
    if (v is String && (v == 'asia' || v == 'na')) return v;
    return 'asia';
  }

  static Future<void> saveServerRegion(String region) async {
    await _box.put(_keyServerRegion, region == 'na' ? 'na' : 'asia');
  }

  static String newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random.secure().nextInt(1 << 32);
    return '$now-$rand';
  }

  static Map<String, dynamic> exportJson(
    List<MsmCharacter> characters, {
    required String serverRegion,
  }) {
    return {
      'schemaVersion': 1,
      'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'serverRegion': serverRegion,
      'characters': characters.map((c) => c.toJson()).toList(),
    };
  }

  static ({List<MsmCharacter> characters, String? serverRegion}) importJson(
    String jsonText,
  ) {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map) {
      throw const FormatException('Invalid JSON (expected object).');
    }
    final characters = decoded['characters'];
    if (characters is! List) {
      throw const FormatException('Invalid JSON (expected characters list).');
    }
    final region = decoded['serverRegion'];
    final parsedRegion = region is String && (region == 'asia' || region == 'na')
        ? region
        : null;
    return (
      characters: characters
        .whereType<Map>()
        .map((m) => MsmCharacter.fromJson(m.cast<String, dynamic>()))
        .toList(),
      serverRegion: parsedRegion,
    );
  }
}

