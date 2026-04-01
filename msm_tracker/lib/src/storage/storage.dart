import 'dart:convert';
import 'dart:math';

import 'package:hive/hive.dart';

import '../models/character.dart';

class Storage {
  static const _boxName = 'msm_tracker';
  static const _keyCharacters = 'characters';
  static const _keyServerRegion = 'serverRegion';
  static const _keyGeneralTaskCompletions = 'generalTaskCompletions';
  static const _keyOptionalDefaultsDone = 'optionalDefaultsDone';
  static const _keyOptionalCraDefaultsDone = 'optionalCraDefaultsDone';
  static const _keyFreeChargeHighestRepairDone = 'freeChargeHighestRepairDone';

  static late final Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    if (!_box.containsKey(_keyCharacters)) {
      await _box.put(_keyCharacters, <dynamic>[]);
    }
    if (!_box.containsKey(_keyServerRegion)) {
      await _box.put(_keyServerRegion, 'asia');
    }
    if (!_box.containsKey(_keyGeneralTaskCompletions)) {
      await _box.put(_keyGeneralTaskCompletions, <String, String>{});
    }
    if (!_box.containsKey(_keyOptionalDefaultsDone)) {
      await _box.put(_keyOptionalDefaultsDone, false);
    }
    if (!_box.containsKey(_keyOptionalCraDefaultsDone)) {
      await _box.put(_keyOptionalCraDefaultsDone, false);
    }
    if (!_box.containsKey(_keyFreeChargeHighestRepairDone)) {
      await _box.put(_keyFreeChargeHighestRepairDone, false);
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

  static Map<String, String> loadGeneralTaskCompletions() {
    final raw = _box.get(_keyGeneralTaskCompletions);
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return const {};
  }

  static Future<void> saveGeneralTaskCompletions(
    Map<String, String> completions,
  ) async {
    await _box.put(_keyGeneralTaskCompletions, completions);
  }

  static bool loadOptionalDefaultsDone() {
    final v = _box.get(_keyOptionalDefaultsDone);
    return v is bool ? v : false;
  }

  static Future<void> saveOptionalDefaultsDone(bool done) async {
    await _box.put(_keyOptionalDefaultsDone, done);
  }

  static bool loadOptionalCraDefaultsDone() {
    final v = _box.get(_keyOptionalCraDefaultsDone);
    return v is bool ? v : false;
  }

  static Future<void> saveOptionalCraDefaultsDone(bool done) async {
    await _box.put(_keyOptionalCraDefaultsDone, done);
  }

  static bool loadFreeChargeHighestRepairDone() {
    final v = _box.get(_keyFreeChargeHighestRepairDone);
    return v is bool ? v : false;
  }

  static Future<void> saveFreeChargeHighestRepairDone(bool done) async {
    await _box.put(_keyFreeChargeHighestRepairDone, done);
  }

  static String newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final r = Random.secure();
    // dart2js: avoid any `1 << n` in `nextInt(...)` — shifts can compile to 0 and
    // cause RangeError (max must be > 0). Use literals + arithmetic only.
    const base = 65536;
    final hi = r.nextInt(base);
    final lo = r.nextInt(base);
    final rand = hi * base + lo;
    return '$now-$rand';
  }

  static Map<String, dynamic> exportJson(
    List<MsmCharacter> characters, {
    required String serverRegion,
    required Map<String, String> generalTaskCompletions,
  }) {
    return {
      'schemaVersion': 1,
      'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'serverRegion': serverRegion,
      'generalTaskCompletions': generalTaskCompletions,
      'characters': characters.map((c) => c.toJson()).toList(),
    };
  }

  static ({
    List<MsmCharacter> characters,
    String? serverRegion,
    Map<String, String>? generalTaskCompletions
  }) importJson(
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
    final general = decoded['generalTaskCompletions'];
    final parsedGeneral = general is Map
        ? general.map((k, v) => MapEntry(k.toString(), v.toString()))
        : null;
    return (
      characters: characters
        .whereType<Map>()
        .map((m) => MsmCharacter.fromJson(m.cast<String, dynamic>()))
        .toList(),
      serverRegion: parsedRegion,
      generalTaskCompletions: parsedGeneral,
    );
  }
}

