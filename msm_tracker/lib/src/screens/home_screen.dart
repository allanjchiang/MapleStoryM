import 'dart:async';

import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/task_defs.dart';
import '../storage/storage.dart';
import '../utils/export_import.dart';
import '../utils/reset_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
    _initOptionalDefaultsIfNeeded();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _nowUtc = DateTime.now().toUtc());
    });
  }

  Future<void> _initOptionalDefaultsIfNeeded() async {
    if (Storage.loadOptionalDefaultsDone()) return;
    if (_characters.isEmpty) {
      await Storage.saveOptionalDefaultsDone(true);
      return;
    }

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

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _persist() async {
    await Storage.saveCharacters(_characters);
  }

  Future<void> _addCharacter() async {
    final created = await showDialog<MsmCharacter>(
      context: context,
      builder: (context) => CharacterDialog(
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
      ),
    );
    if (created == null) return;
    setState(() => _characters = [..._characters, created]);
    await _persist();
  }

  Future<void> _editCharacter(MsmCharacter c) async {
    final edited = await showDialog<MsmCharacter>(
      context: context,
      builder: (context) => CharacterDialog(
        title: 'Edit character',
        initial: c,
      ),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import complete.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _chooseRegion() async {
    final picked = await showDialog<ServerRegion>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Server region'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ServerRegion.asia),
            child: Text(ServerRegion.asia.label),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ServerRegion.northAmerica),
            child: Text(ServerRegion.northAmerica.label),
          ),
        ],
      ),
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
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'region') await _chooseRegion();
              if (v == 'export') await _export();
              if (v == 'import') await _import();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'region',
                child: Text('Server: ${_region.label}'),
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
        padding: const EdgeInsets.all(12),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('General checklist', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Event minigames'),
              subtitle: const Text('Daily'),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resets (${region.label})',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _kv('Next daily reset', untilDaily),
            _kv('Next Monday reset', untilMon),
            _kv('Next Thursday reset', untilThu),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(k)),
          Text(v, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('No characters yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Tap "Add" to create your first character.'),
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
    final eligibleTasks = TaskDefs.all
        .where((t) => t.isVisibleFor(character.level, character.starforce))
        .toList();
    final visibleTasks = eligibleTasks
        .where((t) => !t.isOptional || character.isOptionalTaskEnabled(t))
        .where((t) => !character.isTaskHidden(t))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    character.name,
                    style: Theme.of(context).textTheme.titleMedium,
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
            const SizedBox(height: 4),
            Text('Level: ${character.level}   Starforce: ${character.starforce}'),
            const Divider(height: 20),
            if (visibleTasks.isEmpty)
              const Text('No tasks to show for this character.')
            else
              ...visibleTasks.map((def) {
                final key = resetKeyFor(
                  resetType: def.resetType,
                  nowUtc: nowUtc,
                  region: region,
                );
                final done = character.isTaskDoneForCurrentReset(def, key);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
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
                  title: Text(def.title),
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
    final tasks = TaskDefs.all;
    return AlertDialog(
      title: Text('Tasks for ${widget.character.name}'),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text('Toggle tasks you want to hide for this character.'),
            const SizedBox(height: 12),
            ...tasks.map((t) {
              final isEligible =
                  t.isVisibleFor(widget.character.level, widget.character.starforce);
              final isHidden = _hidden.contains(t.id.name);
              final isOptionalEnabled = _enabledOptional.contains(t.id.name);
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.title),
                subtitle: Text(
                  !isEligible
                      ? 'Not eligible'
                      : t.isOptional
                          ? (isOptionalEnabled ? 'Optional: enabled' : 'Optional: disabled')
                          : (isHidden ? 'Hidden' : 'Shown'),
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
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: _level,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Level'),
          ),
          TextField(
            controller: _sf,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Starforce'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final next = widget.initial.copyWith(
              name: _name.text.trim().isEmpty ? widget.initial.name : _name.text.trim(),
              level: _parseInt(_level, fallback: widget.initial.level, min: 1),
              starforce: _parseInt(_sf, fallback: widget.initial.starforce, min: 0),
            );
            Navigator.pop(context, next);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

