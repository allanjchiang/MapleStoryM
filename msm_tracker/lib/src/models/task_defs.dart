enum TaskId {
  chaosDailyDungeon,
  forestOfErdaCharge,
  pharaohsTreasure,
  cra,
}

enum ResetType {
  dailyUtcMidnight,
  weeklyMondayUtcMidnight,
  weeklyThursdayUtcMidnight,
}

class TaskDef {
  final TaskId id;
  final String title;
  final ResetType resetType;
  final bool Function(int level, int starforce) isVisibleFor;

  const TaskDef({
    required this.id,
    required this.title,
    required this.resetType,
    required this.isVisibleFor,
  });
}

class TaskDefs {
  static const List<TaskDef> all = [
    TaskDef(
      id: TaskId.chaosDailyDungeon,
      title: 'Chaos Daily Dungeon',
      resetType: ResetType.dailyUtcMidnight,
      isVisibleFor: _sfAtLeast160,
    ),
    TaskDef(
      id: TaskId.forestOfErdaCharge,
      title: 'Forest of Erda Charge',
      resetType: ResetType.dailyUtcMidnight,
      isVisibleFor: _levelAtLeast220,
    ),
    TaskDef(
      id: TaskId.pharaohsTreasure,
      title: "Pharaoh's Treasure",
      resetType: ResetType.weeklyMondayUtcMidnight,
      isVisibleFor: _sfAtLeast170,
    ),
    TaskDef(
      id: TaskId.cra,
      title: 'Chaos Root Abyss',
      resetType: ResetType.weeklyThursdayUtcMidnight,
      isVisibleFor: _always,
    ),
  ];

  static bool _always(int level, int starforce) => true;
  static bool _levelAtLeast220(int level, int starforce) => level >= 220;
  static bool _sfAtLeast160(int level, int starforce) => starforce >= 160;
  static bool _sfAtLeast170(int level, int starforce) => starforce >= 170;
}

