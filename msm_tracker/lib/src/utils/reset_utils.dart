import 'package:timezone/timezone.dart' as tz;

import '../models/task_defs.dart';
import 'timezone_init.dart';

enum ServerRegion {
  asia,
  europe,
  northAmerica,
}

extension ServerRegionUi on ServerRegion {
  /// Short label for menus and cards.
  String get label => switch (this) {
        ServerRegion.asia => 'Asia (UTC+8)',
        ServerRegion.europe => 'Europe (CET / CEST)',
        ServerRegion.northAmerica => 'North America (UTC)',
      };

  /// One line for picker subtitles — when daily/weekly resets roll over.
  String get resetScheduleHint => switch (this) {
        ServerRegion.asia =>
          'Daily & weekly resets at midnight in UTC+8 (Asia server time).',
        ServerRegion.europe =>
          'Daily & weekly resets at midnight Central European Time '
          '(UTC+1 CET in winter, UTC+2 CEST in summer).',
        ServerRegion.northAmerica =>
          'Daily & weekly resets at midnight UTC (North American server time).',
      };

  String get storageKey => switch (this) {
        ServerRegion.asia => 'asia',
        ServerRegion.europe => 'eu',
        ServerRegion.northAmerica => 'na',
      };

  static ServerRegion fromStorageKey(String key) {
    return switch (key) {
      'na' => ServerRegion.northAmerica,
      'eu' => ServerRegion.europe,
      _ => ServerRegion.asia,
    };
  }
}

Duration _fixedOffsetAsiaOrNa(ServerRegion region) {
  return switch (region) {
    ServerRegion.asia => const Duration(hours: 8),
    ServerRegion.northAmerica => Duration.zero,
    ServerRegion.europe => throw StateError('Europe uses IANA Europe/Berlin'),
  };
}

class ResetInfo {
  final DateTime nowUtc;
  final DateTime nextDailyResetUtc;
  final DateTime nextMondayResetUtc;
  final DateTime nextThursdayResetUtc;

  const ResetInfo({
    required this.nowUtc,
    required this.nextDailyResetUtc,
    required this.nextMondayResetUtc,
    required this.nextThursdayResetUtc,
  });

  static ResetInfo compute({
    required ServerRegion region,
    DateTime? nowUtc,
  }) {
    final now = (nowUtc ?? DateTime.now()).toUtc();
    if (region == ServerRegion.europe) {
      return _computeForEuropeBerlin(now);
    }

    final offset = _fixedOffsetAsiaOrNa(region);
    final nowLocal = now.add(offset);
    final nextDailyLocalMidnight = DateTime.utc(nowLocal.year, nowLocal.month, nowLocal.day)
        .add(const Duration(days: 1));
    final nextDailyResetUtc = nextDailyLocalMidnight.subtract(offset);

    DateTime nextWeekday(int weekday) {
      final todayLocalMidnight =
          DateTime.utc(nowLocal.year, nowLocal.month, nowLocal.day);
      var daysAhead = (weekday - nowLocal.weekday) % 7;
      var candidateLocal = todayLocalMidnight.add(Duration(days: daysAhead));
      var candidateUtc = candidateLocal.subtract(offset);
      if (!candidateUtc.isAfter(now)) {
        candidateLocal = candidateLocal.add(const Duration(days: 7));
        candidateUtc = candidateLocal.subtract(offset);
      }
      return candidateUtc;
    }

    final nextMondayResetUtc = nextWeekday(DateTime.monday);
    final nextThursdayResetUtc = nextWeekday(DateTime.thursday);
    return ResetInfo(
      nowUtc: now,
      nextDailyResetUtc: nextDailyResetUtc,
      nextMondayResetUtc: nextMondayResetUtc,
      nextThursdayResetUtc: nextThursdayResetUtc,
    );
  }

  static ResetInfo _computeForEuropeBerlin(DateTime now) {
    ensureTimezonesInitialized();
    final loc = tz.getLocation('Europe/Berlin');
    final local = tz.TZDateTime.from(now, loc);

    final startTomorrow =
        tz.TZDateTime(loc, local.year, local.month, local.day).add(const Duration(days: 1));
    final nextDailyResetUtc = startTomorrow.toUtc();

    tz.TZDateTime nextWeekdayBerlin(int weekday) {
      final todayStart = tz.TZDateTime(loc, local.year, local.month, local.day);
      var daysAhead = (weekday - local.weekday) % 7;
      var candidate = todayStart.add(Duration(days: daysAhead));
      var candidateUtc = candidate.toUtc();
      if (!candidateUtc.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 7));
        candidateUtc = candidate.toUtc();
      }
      return candidateUtc;
    }

    final nextMondayResetUtc = nextWeekdayBerlin(DateTime.monday);
    final nextThursdayResetUtc = nextWeekdayBerlin(DateTime.thursday);
    return ResetInfo(
      nowUtc: now,
      nextDailyResetUtc: nextDailyResetUtc,
      nextMondayResetUtc: nextMondayResetUtc,
      nextThursdayResetUtc: nextThursdayResetUtc,
    );
  }

  Duration until(DateTime targetUtc) => targetUtc.difference(nowUtc);
}

String resetKeyFor({
  required ResetType resetType,
  required DateTime nowUtc,
  required ServerRegion region,
}) {
  final utc = nowUtc.toUtc();
  final regionPrefix = region.storageKey;

  if (region == ServerRegion.europe) {
    ensureTimezonesInitialized();
    final loc = tz.getLocation('Europe/Berlin');
    final local = tz.TZDateTime.from(utc, loc);
    switch (resetType) {
      case ResetType.dailyUtcMidnight:
        return '$regionPrefix:D:${local.year.toString().padLeft(4, '0')}-'
            '${local.month.toString().padLeft(2, '0')}-'
            '${local.day.toString().padLeft(2, '0')}';
      case ResetType.weeklyMondayUtcMidnight:
        final monday = _startOfWeekBerlin(local, DateTime.monday);
        return '$regionPrefix:WMon:${_fmtYmd(monday)}';
      case ResetType.weeklyThursdayUtcMidnight:
        final thursday = _startOfWeekBerlin(local, DateTime.thursday);
        return '$regionPrefix:WThu:${_fmtYmd(thursday)}';
    }
  }

  final offset = _fixedOffsetAsiaOrNa(region);
  final nowLocal = utc.add(offset);
  switch (resetType) {
    case ResetType.dailyUtcMidnight:
      return '$regionPrefix:D:${nowLocal.year.toString().padLeft(4, '0')}-'
          '${nowLocal.month.toString().padLeft(2, '0')}-'
          '${nowLocal.day.toString().padLeft(2, '0')}';
    case ResetType.weeklyMondayUtcMidnight:
      final monday = _startOfWeekLocal(nowLocal, DateTime.monday);
      return '$regionPrefix:WMon:${_fmtYmd(monday)}';
    case ResetType.weeklyThursdayUtcMidnight:
      final thursday = _startOfWeekLocal(nowLocal, DateTime.thursday);
      return '$regionPrefix:WThu:${_fmtYmd(thursday)}';
  }
}

tz.TZDateTime _startOfWeekBerlin(tz.TZDateTime nowBerlin, int anchorWeekday) {
  final loc = nowBerlin.location;
  final todayStart = tz.TZDateTime(loc, nowBerlin.year, nowBerlin.month, nowBerlin.day);
  final delta = (nowBerlin.weekday - anchorWeekday) % 7;
  return todayStart.subtract(Duration(days: delta));
}

DateTime _startOfWeekLocal(DateTime nowLocal, int anchorWeekday) {
  final todayLocalMidnight =
      DateTime.utc(nowLocal.year, nowLocal.month, nowLocal.day);
  final delta = (nowLocal.weekday - anchorWeekday) % 7;
  return todayLocalMidnight.subtract(Duration(days: delta));
}

String _fmtYmd(DateTime utcMidnight) {
  return '${utcMidnight.year.toString().padLeft(4, '0')}-'
      '${utcMidnight.month.toString().padLeft(2, '0')}-'
      '${utcMidnight.day.toString().padLeft(2, '0')}';
}

String formatDuration(Duration d) {
  final totalSeconds = d.inSeconds;
  if (totalSeconds <= 0) return '00:00:00';
  final hours = (totalSeconds ~/ 3600);
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours >= 100) {
    return '${hours}h '
        '${minutes.toString().padLeft(2, '0')}m '
        '${seconds.toString().padLeft(2, '0')}s';
  }
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
