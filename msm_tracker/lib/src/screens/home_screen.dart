import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/task_defs.dart';
import '../storage/storage.dart';
import '../utils/export_import.dart';
import '../utils/reset_utils.dart';

class HomeScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<MsmCharacter> _characters;
  late ServerRegion _region;
  late Map<String, String> _generalTaskCompletions;
  Timer? _ticker;
  DateTime _nowUtc = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    _characters = Storage.loadCharacters();
    _region = ServerRegionUi.fromStorageKey(Storage.loadServerRegion());
    _generalTaskCompletions = Storage.loadGeneralTaskCompletions();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initOptionalDefaultsIfNeeded();
      await _repairFreeChargeOnHighestIfNeeded();
      await _migrateOptionalCraIfNeeded();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _nowUtc = DateTime.now().toUtc());
    });
  }

  Future<void> _initOptionalDefaultsIfNeeded() async {
    if (Storage.loadOptionalDefaultsDone()) return;
    // Do not mark migration "done" while there are no characters — otherwise
    // adding the first character later skips enabling Free Charge on highest.
    if (_characters.isEmpty) return;

    // Enable optional tasks by default only for the highest-level character.
    final highest = _characters.reduce((a, b) => a.level >= b.level ? a : b);
    final idName = TaskId.freeChargeAutoBattle.name;
    final next = _characters.map((c) {
      if (c.id != highest.id) return c;
      final enabled = Set<String>.from(c.enabledOptionalTasks)..add(idName);
      return c.copyWith(enabledOptionalTasks: enabled);
    }).toList();

    setState(() => _characters = next);
    await _persist();
    await Storage.saveOptionalDefaultsDone(true);
  }

  /// One-time fix: older versions marked optional defaults "done" with an empty roster,
  /// so Free Charge never got enabled on highest. Add it if still missing.
  Future<void> _repairFreeChargeOnHighestIfNeeded() async {
    if (Storage.loadFreeChargeHighestRepairDone()) return;
    if (_characters.isEmpty) return;

    final fb = TaskId.freeChargeAutoBattle.name;
    final highest = _characters.reduce((a, b) => a.level >= b.level ? a : b);
    if (highest.enabledOptionalTasks.contains(fb)) {
      await Storage.saveFreeChargeHighestRepairDone(true);
      return;
    }

    final next = _characters.map((c) {
      if (c.id != highest.id) return c;
      final enabled = Set<String>.from(c.enabledOptionalTasks)..add(fb);
      return c.copyWith(enabledOptionalTasks: enabled);
    }).toList();

    setState(() => _characters = next);
    await _persist();
    await Storage.saveFreeChargeHighestRepairDone(true);
  }

  /// Chaos Root Abyss is optional: on by default only for the highest-level character.
  /// Others can enable it in the per-character task list (tune icon).
  Future<void> _migrateOptionalCraIfNeeded() async {
    if (Storage.loadOptionalCraDefaultsDone()) return;
    if (_characters.isEmpty) return;

    final craName = TaskId.cra.name;
    final highest = _characters.reduce((a, b) => a.level >= b.level ? a : b);
    final next = _characters.map((c) {
      if (c.id != highest.id) return c;
      final enabled = Set<String>.from(c.enabledOptionalTasks)..add(craName);
      return c.copyWith(enabledOptionalTasks: enabled);
    }).toList();

    setState(() => _characters = next);
    await _persist();
    await Storage.saveOptionalCraDefaultsDone(true);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _persist() async {
    await Storage.saveCharacters(_characters);
  }

  Future<MsmCharacter?> _openCharacterEditor({
    required String title,
    required MsmCharacter initial,
  }) async {
    // Flutter Web + CanvasKit often paints only the modal barrier for showDialog;
    // a full-screen route reliably shows the form.
    if (kIsWeb) {
      return Navigator.of(context).push<MsmCharacter>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) =>
              CharacterEditorPage(title: title, initial: initial),
        ),
      );
    }
    return showDialog<MsmCharacter>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (context) => CharacterDialog(title: title, initial: initial),
    );
  }

  Future<void> _addCharacter() async {
    final created = await _openCharacterEditor(
      title: 'Add character',
      initial: MsmCharacter(
        id: Storage.newId(),
        name: 'New character',
        level: 1,
        starforce: 0,
        taskCompletions: const {},
        hiddenTasks: const {},
        enabledOptionalTasks: const {},
      ),
    );
    if (created == null) return;
    setState(() => _characters = [..._characters, created]);
    await _persist();
    await _initOptionalDefaultsIfNeeded();
    await _repairFreeChargeOnHighestIfNeeded();
    await _migrateOptionalCraIfNeeded();
  }

  Future<void> _editCharacter(MsmCharacter c) async {
    final edited = await _openCharacterEditor(
      title: 'Edit character',
      initial: c,
    );
    if (edited == null) return;
    setState(() {
      _characters = _characters.map((x) => x.id == edited.id ? edited : x).toList();
    });
    await _persist();
  }

  Future<void> _deleteCharacter(MsmCharacter c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete character?'),
        content: Text('Delete "${c.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _characters = _characters.where((x) => x.id != c.id).toList());
    await _persist();
  }

  Future<void> _export() async {
    final jsonMap = Storage.exportJson(
      _characters,
      serverRegion: _region.storageKey,
      generalTaskCompletions: _generalTaskCompletions,
    );
    final filename = 'msm-tracker-export-${DateTime.now().toUtc().toIso8601String()}';
    await saveJsonFile(filename: filename, jsonMap: jsonMap);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export saved.')));
  }

  Future<void> _import() async {
    final jsonText = await pickJsonFileText();
    if (jsonText == null) return;
    try {
      final imported = Storage.importJson(jsonText);
      setState(() {
        _characters = imported.characters;
        if (imported.serverRegion != null) {
          _region = ServerRegionUi.fromStorageKey(imported.serverRegion!);
        }
        if (imported.generalTaskCompletions != null) {
          _generalTaskCompletions = imported.generalTaskCompletions!;
        }
      });
      await _persist();
      await Storage.saveServerRegion(_region.storageKey);
      await Storage.saveGeneralTaskCompletions(_generalTaskCompletions);
      await _initOptionalDefaultsIfNeeded();
      await _repairFreeChargeOnHighestIfNeeded();
      await _migrateOptionalCraIfNeeded();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import complete.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _chooseRegion() async {
    final theme = Theme.of(context);
    final picked = await showDialog<ServerRegion>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Game server'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose the region you play on. The app aligns daily and weekly '
                  "checklist resets with midnight in that server's time zone.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ...ServerRegion.values.map((r) {
                  final selected = r == _region;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: selected
                          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
                          : theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(ctx, r),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.label,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      r.resetScheduleHint,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
    if (picked == null) return;
    setState(() => _region = picked);
    await Storage.saveServerRegion(_region.storageKey);
  }

  @override
  Widget build(BuildContext context) {
    final resets = ResetInfo.compute(region: _region, nowUtc: _nowUtc);
    final untilDaily = formatDuration(resets.until(resets.nextDailyResetUtc));
    final untilMon = formatDuration(resets.until(resets.nextMondayResetUtc));
    final untilThu = formatDuration(resets.until(resets.nextThursdayResetUtc));

    return Scaffold(
      appBar: AppBar(
        title: const Text('MSM Tracker'),
        actions: [
          IconButton(
            tooltip: widget.themeMode == ThemeMode.dark
                ? 'Switch to light mode'
                : 'Switch to dark mode',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'region') await _chooseRegion();
              if (v == 'export') await _export();
              if (v == 'import') await _import();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'region',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Game server',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _region.label,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              PopupMenuItem(value: 'export', child: Text('Export JSON')),
              PopupMenuItem(value: 'import', child: Text('Import JSON')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCharacter,
        label: const Text('Add'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ResetCard(
            untilDaily: untilDaily,
            untilMon: untilMon,
            untilThu: untilThu,
            region: _region,
          ),
          const SizedBox(height: 12),
          _GeneralChecklistCard(
            nowUtc: _nowUtc,
            region: _region,
            completions: _generalTaskCompletions,
            onChanged: (next) async {
              setState(() => _generalTaskCompletions = next);
              await Storage.saveGeneralTaskCompletions(_generalTaskCompletions);
            },
          ),
          const SizedBox(height: 12),
          if (_characters.isEmpty)
            const _EmptyState()
          else
            ..._characters.map(
              (c) => CharacterCard(
                character: c,
                nowUtc: _nowUtc,
                region: _region,
                onChanged: (next) async {
                  setState(() {
                    _characters =
                        _characters.map((x) => x.id == next.id ? next : x).toList();
                  });
                  await _persist();
                },
                onEdit: () => _editCharacter(c),
                onDelete: () => _deleteCharacter(c),
              ),
            ),
        ],
      ),
    );
  }
}

class _GeneralChecklistCard extends StatelessWidget {
  final DateTime nowUtc;
  final ServerRegion region;
  final Map<String, String> completions;
  final ValueChanged<Map<String, String>> onChanged;

  const _GeneralChecklistCard({
    required this.nowUtc,
    required this.region,
    required this.completions,
    required this.onChanged,
  });

  static const String _eventMinigamesId = 'eventMinigames';

  @override
  Widget build(BuildContext context) {
    final resetKey = resetKeyFor(
      resetType: ResetType.dailyUtcMidnight,
      nowUtc: nowUtc,
      region: region,
    );
    final done = completions[_eventMinigamesId] == resetKey;

    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'General checklist',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
              title: Text(
                'Event minigames',
                style: theme.textTheme.bodyLarge,
              ),
              subtitle: Text(
                'Daily',
                style: theme.textTheme.bodySmall,
              ),
              value: done,
              onChanged: (v) {
                final next = Map<String, String>.from(completions);
                if (v == true) {
                  next[_eventMinigamesId] = resetKey;
                } else {
                  next.remove(_eventMinigamesId);
                }
                onChanged(next);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetCard extends StatelessWidget {
  final String untilDaily;
  final String untilMon;
  final String untilThu;
  final ServerRegion region;

  const _ResetCard({
    required this.untilDaily,
    required this.untilMon,
    required this.untilThu,
    required this.region,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resets (${region.label})',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _kv(context, 'Next daily reset', untilDaily),
            _kv(context, "Next Monday reset (Pharaoh's Treasure)", untilMon),
            _kv(context, 'Next Thursday reset (Chaos Root Abyss)', untilThu),
          ],
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              k,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            v,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('No characters yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              'Tap "Add" to create your first character.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class CharacterCard extends StatelessWidget {
  final MsmCharacter character;
  final DateTime nowUtc;
  final ServerRegion region;
  final ValueChanged<MsmCharacter> onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CharacterCard({
    super.key,
    required this.character,
    required this.nowUtc,
    required this.region,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eligibleTasks = TaskDefs.all
        .where((t) => t.isVisibleFor(character.level, character.starforce))
        .toList();
    final visibleTasks = eligibleTasks
        .where((t) => !t.isOptional || character.isOptionalTaskEnabled(t))
        .where((t) => !character.isTaskHidden(t))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    character.name,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final next = await showDialog<MsmCharacter>(
                      context: context,
                      builder: (context) => ManageTasksDialog(
                        character: character,
                        eligibleTasks: eligibleTasks,
                      ),
                    );
                    if (next != null) onChanged(next);
                  },
                  tooltip: 'Hide/unhide tasks',
                  icon: const Icon(Icons.tune),
                ),
                IconButton(onPressed: onEdit, icon: const Icon(Icons.edit)),
                IconButton(onPressed: onDelete, icon: const Icon(Icons.delete)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Level: ${character.level}   Starforce: ${character.starforce}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const Divider(height: 28),
            if (visibleTasks.isEmpty)
              Text(
                'No tasks to show for this character.',
                style: theme.textTheme.bodyMedium,
              )
            else
              ...visibleTasks.map((def) {
                final key = resetKeyFor(
                  resetType: def.resetType,
                  nowUtc: nowUtc,
                  region: region,
                );
                final done = character.isTaskDoneForCurrentReset(def, key);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                  leading: Checkbox(
                    value: done,
                    onChanged: (v) {
                      if (v == true) {
                        onChanged(character.withTaskCompletion(def, resetKey: key));
                      } else {
                        onChanged(character.withTaskUnchecked(def));
                      }
                    },
                  ),
                  title: Text(
                    def.title,
                    style: theme.textTheme.bodyLarge,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'hide') onChanged(character.withTaskHidden(def));
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'hide', child: Text('Hide for this character')),
                    ],
                  ),
                  onTap: () {
                    onChanged(
                      done
                          ? character.withTaskUnchecked(def)
                          : character.withTaskCompletion(def, resetKey: key),
                    );
                  },
                );
              }),
          ],
        ),
      ),
    );
  }
}

class ManageTasksDialog extends StatefulWidget {
  final MsmCharacter character;
  final List<TaskDef> eligibleTasks;

  const ManageTasksDialog({
    super.key,
    required this.character,
    required this.eligibleTasks,
  });

  @override
  State<ManageTasksDialog> createState() => _ManageTasksDialogState();
}

class _ManageTasksDialogState extends State<ManageTasksDialog> {
  late Set<String> _hidden;
  late Set<String> _enabledOptional;

  @override
  void initState() {
    super.initState();
    _hidden = Set<String>.from(widget.character.hiddenTasks);
    _enabledOptional = Set<String>.from(widget.character.enabledOptionalTasks);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = TaskDefs.all;
    return AlertDialog(
      title: Text(
        'Tasks for ${widget.character.name}',
        style: theme.textTheme.titleLarge,
      ),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Toggle tasks you want to hide for this character.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ...tasks.map((t) {
              final isEligible =
                  t.isVisibleFor(widget.character.level, widget.character.starforce);
              final isHidden = _hidden.contains(t.id.name);
              final isOptionalEnabled = _enabledOptional.contains(t.id.name);
              return SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                title: Text(
                  t.title,
                  style: theme.textTheme.bodyLarge,
                ),
                subtitle: Text(
                  !isEligible
                      ? 'Not eligible'
                      : t.isOptional
                          ? (isOptionalEnabled ? 'Optional: enabled' : 'Optional: disabled')
                          : (isHidden ? 'Hidden' : 'Shown'),
                  style: theme.textTheme.bodySmall,
                ),
                value: t.isOptional ? isOptionalEnabled : !isHidden,
                onChanged: isEligible
                    ? (v) {
                        setState(() {
                          if (t.isOptional) {
                            if (v) {
                              _enabledOptional.add(t.id.name);
                            } else {
                              _enabledOptional.remove(t.id.name);
                            }
                          } else {
                            if (v) {
                              _hidden.remove(t.id.name);
                            } else {
                              _hidden.add(t.id.name);
                            }
                          }
                        });
                      }
                    : null,
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            var next = widget.character.copyWith(
              hiddenTasks: _hidden,
              enabledOptionalTasks: _enabledOptional,
            );
            // If a task is hidden/disabled, also clear completion state so it doesn't reappear checked later.
            final completions = Map<String, String>.from(next.taskCompletions);
            for (final taskIdName in _hidden) {
              completions.remove(taskIdName);
            }
            for (final t in tasks.where((t) => t.isOptional)) {
              if (!_enabledOptional.contains(t.id.name)) {
                completions.remove(t.id.name);
              }
            }
            next = next.copyWith(taskCompletions: completions);
            Navigator.pop(context, next);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Full-screen character editor for **web** — avoids blank `showDialog` on Flutter Web.
class CharacterEditorPage extends StatefulWidget {
  final String title;
  final MsmCharacter initial;

  const CharacterEditorPage({
    super.key,
    required this.title,
    required this.initial,
  });

  @override
  State<CharacterEditorPage> createState() => _CharacterEditorPageState();
}

class _CharacterEditorPageState extends State<CharacterEditorPage> {
  late final TextEditingController _name;
  late final TextEditingController _level;
  late final TextEditingController _sf;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name);
    _level = TextEditingController(text: widget.initial.level.toString());
    _sf = TextEditingController(text: widget.initial.starforce.toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _level.dispose();
    _sf.dispose();
    super.dispose();
  }

  int _parseInt(TextEditingController c, {required int fallback, int min = 0}) {
    final v = int.tryParse(c.text.trim());
    if (v == null) return fallback;
    if (v < min) return min;
    return v;
  }

  void _save() {
    final next = widget.initial.copyWith(
      name: _name.text.trim().isEmpty ? widget.initial.name : _name.text.trim(),
      level: _parseInt(_level, fallback: widget.initial.level, min: 1),
      starforce: _parseInt(_sf, fallback: widget.initial.starforce, min: 0),
    );
    Navigator.pop(context, next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Close',
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    textInputAction: TextInputAction.next,
                    autofocus: true,
                  ),
                  TextField(
                    controller: _level,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Level'),
                    textInputAction: TextInputAction.next,
                  ),
                  TextField(
                    controller: _sf,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Starforce'),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _save,
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CharacterDialog extends StatefulWidget {
  final String title;
  final MsmCharacter initial;

  const CharacterDialog({super.key, required this.title, required this.initial});

  @override
  State<CharacterDialog> createState() => _CharacterDialogState();
}

class _CharacterDialogState extends State<CharacterDialog> {
  late final TextEditingController _name;
  late final TextEditingController _level;
  late final TextEditingController _sf;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name);
    _level = TextEditingController(text: widget.initial.level.toString());
    _sf = TextEditingController(text: widget.initial.starforce.toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _level.dispose();
    _sf.dispose();
    super.dispose();
  }

  int _parseInt(TextEditingController c, {required int fallback, int min = 0}) {
    final v = int.tryParse(c.text.trim());
    if (v == null) return fallback;
    if (v < min) return min;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxW = MediaQuery.sizeOf(context).width - 48;

    // Use Dialog + Material instead of AlertDialog alone — on Flutter Web,
    // AlertDialog + TextField can paint as an empty/transparent sheet.
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW < 400 ? maxW : 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            color: theme.colorScheme.surface,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    textInputAction: TextInputAction.next,
                  ),
                  TextField(
                    controller: _level,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Level'),
                    textInputAction: TextInputAction.next,
                  ),
                  TextField(
                    controller: _sf,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Starforce'),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final next = widget.initial.copyWith(
                            name: _name.text.trim().isEmpty
                                ? widget.initial.name
                                : _name.text.trim(),
                            level: _parseInt(_level,
                                fallback: widget.initial.level, min: 1),
                            starforce: _parseInt(_sf,
                                fallback: widget.initial.starforce, min: 0),
                          );
                          Navigator.pop(context, next);
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

