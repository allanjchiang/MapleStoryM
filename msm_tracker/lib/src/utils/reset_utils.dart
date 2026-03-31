import '../models/task_defs.dart';

enum ServerRegion {
  asia,
  northAmerica,
}

extension ServerRegionUi on ServerRegion {
  String get label => switch (this) {
        ServerRegion.asia => 'Asia (UTC+8)',
        ServerRegion.northAmerica => 'North America (UTC)',
      };

  String get storageKey => switch (this) {
        ServerRegion.asia => 'asia',
        ServerRegion.northAmerica => 'na',
      };

  static ServerRegion fromStorageKey(String key) {
    return key == 'na' ? ServerRegion.northAmerica : ServerRegion.asia;
  }
}

Duration serverUtcOffset(ServerRegion region) {
  return switch (region) {
    ServerRegion.asia => const Duration(hours: 8),
    ServerRegion.northAmerica => Duration.zero,
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
    final offset = serverUtcOffset(region);
    final nowLocal = now.add(offset);
    final nextDailyLocalMidnight = DateTime.utc(nowLocal.year, nowLocal.month, nowLocal.day)
        .add(const Duration(days: 1));
    final nextDailyResetUtc = nextDailyLocalMidnight.subtract(offset);

    DateTime nextWeekday(int weekday) {
      // Weekday computed in server-local time, but returned as a UTC instant.
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

  Duration until(DateTime targetUtc) => targetUtc.difference(nowUtc);
}

String resetKeyFor({
  required ResetType resetType,
  required DateTime nowUtc,
  required ServerRegion region,
}) {
  final offset = serverUtcOffset(region);
  final nowLocal = nowUtc.toUtc().add(offset);
  final regionPrefix = region.storageKey;
  switch (resetType) {
    case ResetType.dailyUtcMidnight:
      // Key for the current daily window: YYYY-MM-DD (server-local date)
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

DateTime _startOfWeekLocal(DateTime nowLocal, int anchorWeekday) {
  // Returns server-local midnight (represented as UTC date parts).
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

