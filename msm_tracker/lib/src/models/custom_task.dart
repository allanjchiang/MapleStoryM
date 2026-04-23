enum CustomResetEvery {
  daily,
  weekly,
}

class CustomResetRule {
  final CustomResetEvery every;

  /// Minutes since midnight in server-local time, [0..1439].
  final int minutesSinceMidnight;

  /// ISO weekday [1..7] (Mon..Sun) when [every] is weekly.
  final int? weekday;

  const CustomResetRule({
    required this.every,
    required this.minutesSinceMidnight,
    this.weekday,
  });

  Map<String, dynamic> toJson() => {
        'every': every.name,
        'minutesSinceMidnight': minutesSinceMidnight,
        if (weekday != null) 'weekday': weekday,
      };

  static CustomResetRule fromJson(Map<String, dynamic> json) {
    final everyRaw = (json['every'] as String?) ?? CustomResetEvery.daily.name;
    final every = CustomResetEvery.values.firstWhere(
      (e) => e.name == everyRaw,
      orElse: () => CustomResetEvery.daily,
    );

    final minutes = (json['minutesSinceMidnight'] as num?)?.toInt() ?? 0;
    final weekday = (json['weekday'] as num?)?.toInt();

    return CustomResetRule(
      every: every,
      minutesSinceMidnight: minutes.clamp(0, 1439),
      weekday: weekday?.clamp(1, 7),
    );
  }
}

class CustomTask {
  final String id;
  final String title;
  final CustomResetRule resetRule;

  /// If true, shows in the General checklist.
  final bool inGeneralChecklist;

  /// Character IDs that should show this task.
  final Set<String> characterIds;

  const CustomTask({
    required this.id,
    required this.title,
    required this.resetRule,
    required this.inGeneralChecklist,
    required this.characterIds,
  });

  CustomTask copyWith({
    String? id,
    String? title,
    CustomResetRule? resetRule,
    bool? inGeneralChecklist,
    Set<String>? characterIds,
  }) {
    return CustomTask(
      id: id ?? this.id,
      title: title ?? this.title,
      resetRule: resetRule ?? this.resetRule,
      inGeneralChecklist: inGeneralChecklist ?? this.inGeneralChecklist,
      characterIds: characterIds ?? this.characterIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'resetRule': resetRule.toJson(),
        'inGeneralChecklist': inGeneralChecklist,
        'characterIds': characterIds.toList(growable: false),
      };

  static CustomTask fromJson(Map<String, dynamic> json) {
    final rawRule = json['resetRule'];
    final rule = rawRule is Map
        ? CustomResetRule.fromJson(rawRule.cast<String, dynamic>())
        : const CustomResetRule(
            every: CustomResetEvery.daily,
            minutesSinceMidnight: 0,
          );

    final rawChars = json['characterIds'];
    final chars = rawChars is List
        ? rawChars.map((e) => e.toString()).toSet()
        : <String>{};

    return CustomTask(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Task',
      resetRule: rule,
      inGeneralChecklist: (json['inGeneralChecklist'] as bool?) ?? false,
      characterIds: chars,
    );
  }
}

