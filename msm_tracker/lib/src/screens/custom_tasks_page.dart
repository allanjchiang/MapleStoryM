import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/custom_task.dart';
import '../storage/storage.dart';

class CustomTasksPage extends StatefulWidget {
  final List<MsmCharacter> characters;
  final List<CustomTask> tasks;

  const CustomTasksPage({
    super.key,
    required this.characters,
    required this.tasks,
  });

  @override
  State<CustomTasksPage> createState() => _CustomTasksPageState();
}

class _CustomTasksPageState extends State<CustomTasksPage> {
  late List<CustomTask> _tasks;

  @override
  void initState() {
    super.initState();
    _tasks = List<CustomTask>.from(widget.tasks);
  }

  Future<void> _add() async {
    final created = await Navigator.of(context).push<CustomTask>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => CustomTaskEditorPage(
          characters: widget.characters,
          initial: CustomTask(
            id: Storage.newId(),
            title: '',
            resetRule: const CustomResetRule(
              every: CustomResetEvery.daily,
              minutesSinceMidnight: 0,
            ),
            inGeneralChecklist: true,
            characterIds: const {},
          ),
          isNew: true,
        ),
      ),
    );
    if (created == null) return;
    setState(() => _tasks = [..._tasks, created]);
  }

  Future<void> _edit(CustomTask t) async {
    final edited = await Navigator.of(context).push<CustomTask>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => CustomTaskEditorPage(
          characters: widget.characters,
          initial: t,
          isNew: false,
        ),
      ),
    );
    if (edited == null) return;
    setState(() {
      _tasks = _tasks.map((x) => x.id == edited.id ? edited : x).toList();
    });
  }

  Future<void> _delete(CustomTask t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete custom task?'),
        content: Text('Delete "${t.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _tasks = _tasks.where((x) => x.id != t.id).toList());
  }

  void _done() {
    Navigator.pop(context, _tasks);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom checklist'),
        actions: [
          TextButton(
            onPressed: _add,
            child: const Text('Add'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _done,
            child: const Text('Done'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Create your own tasks and choose where they appear.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (_tasks.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No custom tasks yet. Tap “Add” to create one.',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            )
          else
            ..._tasks.map((t) => Card(
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      t.title.trim().isEmpty ? '(Untitled task)' : t.title.trim(),
                      style: theme.textTheme.bodyLarge,
                    ),
                    subtitle: Text(
                      _whereLabel(t, widget.characters),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') await _edit(t);
                        if (v == 'delete') await _delete(t);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                    onTap: () => _edit(t),
                  ),
                )),
        ],
      ),
    );
  }
}

String _whereLabel(CustomTask t, List<MsmCharacter> characters) {
  final parts = <String>[];
  if (t.inGeneralChecklist) parts.add('General');
  if (t.characterIds.isNotEmpty) {
    final byId = {for (final c in characters) c.id: c.name};
    final names = t.characterIds
        .map((id) => byId[id] ?? 'Character')
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    parts.add(names.join(', '));
  }
  if (parts.isEmpty) return 'Not shown anywhere';
  return 'Shows in: ${parts.join(' • ')}';
}

class CustomTaskEditorPage extends StatefulWidget {
  final List<MsmCharacter> characters;
  final CustomTask initial;
  final bool isNew;

  const CustomTaskEditorPage({
    super.key,
    required this.characters,
    required this.initial,
    required this.isNew,
  });

  @override
  State<CustomTaskEditorPage> createState() => _CustomTaskEditorPageState();
}

class _CustomTaskEditorPageState extends State<CustomTaskEditorPage> {
  late final TextEditingController _title;
  late CustomResetEvery _every;
  late int _minutes;
  late int _weekday;
  late bool _inGeneral;
  late Set<String> _characterIds;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial.title);
    _every = widget.initial.resetRule.every;
    _minutes = widget.initial.resetRule.minutesSinceMidnight;
    _weekday = widget.initial.resetRule.weekday ?? DateTime.monday;
    _inGeneral = widget.initial.inGeneralChecklist;
    _characterIds = Set<String>.from(widget.initial.characterIds);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay(hour: _minutes ~/ 60, minute: _minutes % 60);
    final picked = await showTimePicker(context: context, initialTime: now);
    if (picked == null) return;
    setState(() => _minutes = picked.hour * 60 + picked.minute);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task name.')),
      );
      return;
    }

    final rule = CustomResetRule(
      every: _every,
      minutesSinceMidnight: _minutes,
      weekday: _every == CustomResetEvery.weekly ? _weekday : null,
    );

    final next = widget.initial.copyWith(
      title: title,
      resetRule: rule,
      inGeneralChecklist: _inGeneral,
      characterIds: _characterIds,
    );
    Navigator.pop(context, next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeLabel =
        '${(_minutes ~/ 60).toString().padLeft(2, '0')}:${(_minutes % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New custom task' : 'Edit custom task'),
        actions: [
          FilledButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Task', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Task name',
                      hintText: 'e.g. Guild check-in',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reset', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CustomResetEvery>(
                    key: ValueKey('every-$_every'),
                    initialValue: _every,
                    decoration: const InputDecoration(labelText: 'How often'),
                    items: const [
                      DropdownMenuItem(
                        value: CustomResetEvery.daily,
                        child: Text('Daily'),
                      ),
                      DropdownMenuItem(
                        value: CustomResetEvery.weekly,
                        child: Text('Weekly'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _every = v);
                    },
                  ),
                  if (_every == CustomResetEvery.weekly) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      key: ValueKey('weekday-$_weekday'),
                      initialValue: _weekday,
                      decoration: const InputDecoration(labelText: 'Day of week'),
                      items: const [
                        DropdownMenuItem(value: DateTime.monday, child: Text('Monday')),
                        DropdownMenuItem(value: DateTime.tuesday, child: Text('Tuesday')),
                        DropdownMenuItem(value: DateTime.wednesday, child: Text('Wednesday')),
                        DropdownMenuItem(value: DateTime.thursday, child: Text('Thursday')),
                        DropdownMenuItem(value: DateTime.friday, child: Text('Friday')),
                        DropdownMenuItem(value: DateTime.saturday, child: Text('Saturday')),
                        DropdownMenuItem(value: DateTime.sunday, child: Text('Sunday')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _weekday = v);
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reset time (server time)'),
                    subtitle: Text(timeLabel),
                    trailing: TextButton(
                      onPressed: _pickTime,
                      child: const Text('Change'),
                    ),
                    onTap: _pickTime,
                  ),
                  Text(
                    'Resets follow your selected game server region (Asia / EU / NA).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Where to show it', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('General checklist'),
                    value: _inGeneral,
                    onChanged: (v) => setState(() => _inGeneral = v),
                  ),
                  const Divider(height: 24),
                  Text('Characters', style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  if (widget.characters.isEmpty)
                    Text(
                      'No characters yet. Add a character first to assign character-specific tasks.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    ...widget.characters.map((c) {
                      final checked = _characterIds.contains(c.id);
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.name),
                        subtitle: Text('Level ${c.level} • SF ${c.starforce}'),
                        value: checked,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _characterIds.add(c.id);
                            } else {
                              _characterIds.remove(c.id);
                            }
                          });
                        },
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

