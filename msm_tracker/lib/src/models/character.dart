import 'task_defs.dart';

class MsmCharacter {
  final String id;
  final String name;
  final int level;
  final int starforce;

  /// Key: TaskId.name, Value: last completed reset key string.
  final Map<String, String> taskCompletions;

  /// TaskId.name values the user has hidden for this character.
  final Set<String> hiddenTasks;

  /// Optional TaskId.name values enabled for this character.
  final Set<String> enabledOptionalTasks;

  const MsmCharacter({
    required this.id,
    required this.name,
    required this.level,
    required this.starforce,
    required this.taskCompletions,
    required this.hiddenTasks,
    required this.enabledOptionalTasks,
  });

  MsmCharacter copyWith({
    String? id,
    String? name,
    int? level,
    int? starforce,
    Map<String, String>? taskCompletions,
    Set<String>? hiddenTasks,
    Set<String>? enabledOptionalTasks,
  }) {
    return MsmCharacter(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      starforce: starforce ?? this.starforce,
      taskCompletions: taskCompletions ?? this.taskCompletions,
      hiddenTasks: hiddenTasks ?? this.hiddenTasks,
      enabledOptionalTasks: enabledOptionalTasks ?? this.enabledOptionalTasks,
    );
  }

  bool isTaskDoneForCurrentReset(TaskDef def, String currentResetKey) {
    return taskCompletions[def.id.name] == currentResetKey;
  }

  MsmCharacter withTaskCompletion(TaskDef def, {required String resetKey}) {
    final next = Map<String, String>.from(taskCompletions);
    next[def.id.name] = resetKey;
    return copyWith(taskCompletions: next);
  }

  MsmCharacter withTaskUnchecked(TaskDef def) {
    final next = Map<String, String>.from(taskCompletions);
    next.remove(def.id.name);
    return copyWith(taskCompletions: next);
  }

  bool isTaskHidden(TaskDef def) => hiddenTasks.contains(def.id.name);

  MsmCharacter withTaskHidden(TaskDef def) {
    final nextHidden = Set<String>.from(hiddenTasks)..add(def.id.name);
    final nextCompletions = Map<String, String>.from(taskCompletions)
      ..remove(def.id.name);
    return copyWith(hiddenTasks: nextHidden, taskCompletions: nextCompletions);
  }

  MsmCharacter withTaskUnhidden(TaskDef def) {
    final nextHidden = Set<String>.from(hiddenTasks)..remove(def.id.name);
    return copyWith(hiddenTasks: nextHidden);
  }

  bool isOptionalTaskEnabled(TaskDef def) {
    return enabledOptionalTasks.contains(def.id.name);
  }

  MsmCharacter withOptionalTaskEnabled(TaskDef def) {
    final next = Set<String>.from(enabledOptionalTasks)..add(def.id.name);
    return copyWith(enabledOptionalTasks: next);
  }

  MsmCharacter withOptionalTaskDisabled(TaskDef def) {
    final nextEnabled = Set<String>.from(enabledOptionalTasks)..remove(def.id.name);
    final nextCompletions = Map<String, String>.from(taskCompletions)
      ..remove(def.id.name);
    return copyWith(enabledOptionalTasks: nextEnabled, taskCompletions: nextCompletions);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'level': level,
        'starforce': starforce,
        'taskCompletions': taskCompletions,
        'hiddenTasks': hiddenTasks.toList(growable: false),
        'enabledOptionalTasks': enabledOptionalTasks.toList(growable: false),
      };

  static MsmCharacter fromJson(Map<String, dynamic> json) {
    final rawCompletions = json['taskCompletions'];
    final rawHidden = json['hiddenTasks'];
    final rawEnabledOptional = json['enabledOptionalTasks'];
    return MsmCharacter(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Character',
      level: (json['level'] as num?)?.toInt() ?? 1,
      starforce: (json['starforce'] as num?)?.toInt() ?? 0,
      taskCompletions: rawCompletions is Map
          ? rawCompletions.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            )
          : const {},
      hiddenTasks: rawHidden is List
          ? rawHidden.map((e) => e.toString()).toSet()
          : const {},
      enabledOptionalTasks: rawEnabledOptional is List
          ? rawEnabledOptional.map((e) => e.toString()).toSet()
          : const {},
    );
  }
}

