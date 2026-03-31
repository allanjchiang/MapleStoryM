import 'task_defs.dart';

class MsmCharacter {
  final String id;
  final String name;
  final int level;
  final int starforce;

  /// Key: TaskId.name, Value: last completed reset key string.
  final Map<String, String> taskCompletions;

  const MsmCharacter({
    required this.id,
    required this.name,
    required this.level,
    required this.starforce,
    required this.taskCompletions,
  });

  MsmCharacter copyWith({
    String? id,
    String? name,
    int? level,
    int? starforce,
    Map<String, String>? taskCompletions,
  }) {
    return MsmCharacter(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      starforce: starforce ?? this.starforce,
      taskCompletions: taskCompletions ?? this.taskCompletions,
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'level': level,
        'starforce': starforce,
        'taskCompletions': taskCompletions,
      };

  static MsmCharacter fromJson(Map<String, dynamic> json) {
    final rawCompletions = json['taskCompletions'];
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
    );
  }
}

