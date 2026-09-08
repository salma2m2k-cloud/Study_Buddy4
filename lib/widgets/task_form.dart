import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../providers/app_state.dart';

Future<void> showTaskForm(
  BuildContext context, {
  required AppState appState,
  Task? existing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TaskFormSheet(
      appState: appState,
      existing: existing,
    ),
  );
}

class _TaskFormSheet extends StatefulWidget {
  final AppState appState;
  final Task? existing;

  const _TaskFormSheet({
    required this.appState,
    this.existing,
  });

  @override
  State<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<_TaskFormSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;

  DateTime? _dueAt;
  late bool _reminderEnabled;
  late int _leadMinutes;

  String? _error;
  bool _saving = false;

  static const List<int> _leadOptions = [5, 10, 15, 30, 60];

  @override
  void initState() {
    super.initState();

    final Task? task = widget.existing;

    _titleCtrl = TextEditingController(
      text: task?.title ?? '',
    );

    _descCtrl = TextEditingController(
      text: task?.description ?? '',
    );

    _dueAt = task?.dueAt;

    _reminderEnabled = task?.reminderEnabled ?? false;

    _leadMinutes = task?.reminderLeadMinutes ??
        widget.appState.settings.defaultReminderLeadMinutes;

    if (!_leadOptions.contains(_leadMinutes)) {
      _leadMinutes = 15;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    if (_saving) return;

    final DateTime now = DateTime.now();
    final DateTime initialDate = _dueAt ?? now;

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(now) ? now : initialDate,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );

    if (date == null || !mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (time == null || !mounted) return;

    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    final String title = _titleCtrl.text.trim();

    if (title.isEmpty) {
      setState(() {
        _error = 'Give this task a title.';
      });
      return;
    }

    if (_reminderEnabled && _dueAt == null) {
      setState(() {
        _error =
            'Pick a due date and time for the reminder.';
      });
      return;
    }

    final DateTime? dueAt = _dueAt;

    if (_reminderEnabled &&
        dueAt != null &&
        dueAt
            .subtract(
              Duration(minutes: _leadMinutes),
            )
            .isBefore(DateTime.now())) {
      setState(() {
        _error =
            'That reminder time has already passed — pick a later time.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (widget.existing == null) {
        await widget.appState.addTask(
          title: title,
          description: _descCtrl.text.trim(),
          dueAt: dueAt,
          reminderEnabled: _reminderEnabled,
          reminderLeadMinutes: _leadMinutes,
        );
      } else {
        await widget.appState.updateTask(
          widget.existing!.id,
          (task) => task.copyWith(
            title: title,
            description: _descCtrl.text.trim(),
            dueAt: dueAt,
            clearDueAt: dueAt == null,
            reminderEnabled: _reminderEnabled,
            reminderLeadMinutes: _leadMinutes,
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Could not save this task. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                isEditing ? 'Edit task' : 'New task',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                autofocus: !isEditing,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'What do you need to do?',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Add details (optional)',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickDateTime,
                icon: const Icon(Icons.event_rounded),
                label: Text(
                  _dueAt == null
                      ? 'Set due date & time'
                      : DateFormat(
                          'EEE, MMM d · h:mm a',
                        ).format(_dueAt!),
                ),
              ),
              if (_dueAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Remind me'),
                    value: _reminderEnabled,
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _reminderEnabled = value;
                            });
                          },
                  ),
                ),
              if (_dueAt != null && _reminderEnabled) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: _leadOptions.map((minutes) {
                    final bool selected =
                        minutes == _leadMinutes;

                    return ChoiceChip(
                      label: Text('$minutes min before'),
                      selected: selected,
                      onSelected: _saving
                          ? null
                          : (_) {
                              setState(() {
                                _leadMinutes = minutes;
                              });
                            },
                    );
                  }).toList(),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEditing
                              ? 'Save changes'
                              : 'Add task',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
