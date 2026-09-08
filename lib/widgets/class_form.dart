import 'package:flutter/material.dart';

import '../models/class_model.dart';
import '../providers/app_state.dart';
import '../utils/weekday.dart';

Future<void> showClassForm(
  BuildContext context, {
  required AppState appState,
  ClassModel? existing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ClassFormSheet(
      appState: appState,
      existing: existing,
    ),
  );
}

class _ClassFormSheet extends StatefulWidget {
  final AppState appState;
  final ClassModel? existing;

  const _ClassFormSheet({
    required this.appState,
    this.existing,
  });

  @override
  State<_ClassFormSheet> createState() => _ClassFormSheetState();
}

class _ClassFormSheetState extends State<_ClassFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _teacherCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _notesCtrl;

  late Weekday _weekday;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late bool _reminderEnabled;
  late int _leadMinutes;

  String? _error;
  bool _saving = false;

  static const List<int> _leadOptions = [5, 10, 15, 30, 60];

  @override
  void initState() {
    super.initState();

    final ClassModel? c = widget.existing;

    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _subjectCtrl = TextEditingController(text: c?.subject ?? '');
    _teacherCtrl = TextEditingController(text: c?.teacher ?? '');
    _locationCtrl = TextEditingController(text: c?.location ?? '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');

    _weekday =
        c?.weekday ?? Weekday.fromDateTimeWeekday(DateTime.now().weekday);

    _start = c != null
        ? TimeOfDay(
            hour: c.startHour,
            minute: c.startMinute,
          )
        : const TimeOfDay(
            hour: 9,
            minute: 0,
          );

    _end = c != null
        ? TimeOfDay(
            hour: c.endHour,
            minute: c.endMinute,
          )
        : const TimeOfDay(
            hour: 10,
            minute: 0,
          );

    _reminderEnabled = c?.reminderEnabled ?? true;

    _leadMinutes = c?.reminderLeadMinutes ??
        widget.appState.settings.defaultReminderLeadMinutes;

    if (!_leadOptions.contains(_leadMinutes)) {
      _leadMinutes = 15;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subjectCtrl.dispose();
    _teacherCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  int _toMinutes(TimeOfDay t) {
    return t.hour * 60 + t.minute;
  }

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }

      _error = null;
    });
  }

  Future<void> _save() async {
    // Prevent multiple taps from starting multiple save operations.
    if (_saving) return;

    final String name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      setState(() {
        _error = 'Give this class a name.';
      });
      return;
    }

    if (_toMinutes(_end) <= _toMinutes(_start)) {
      setState(() {
        _error = 'End time must be after the start time.';
      });
      return;
    }

    // Lock the button immediately so repeated taps cannot create duplicates.
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (widget.existing == null) {
        await widget.appState.addClass(
          name: name,
          subject: _subjectCtrl.text.trim(),
          teacher: _teacherCtrl.text.trim(),
          weekday: _weekday,
          startMinutes: _toMinutes(_start),
          endMinutes: _toMinutes(_end),
          location: _locationCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          reminderEnabled: _reminderEnabled,
          reminderLeadMinutes: _leadMinutes,
        );
      } else {
        await widget.appState.updateClass(
          widget.existing!.id,
          (c) => c.copyWith(
            name: name,
            subject: _subjectCtrl.text.trim(),
            teacher: _teacherCtrl.text.trim(),
            weekday: _weekday,
            startMinutes: _toMinutes(_start),
            endMinutes: _toMinutes(_end),
            location: _locationCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
            reminderEnabled: _reminderEnabled,
            reminderLeadMinutes: _leadMinutes,
          ),
        );
      }

      // Close the sheet after the save has completed.
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // If saving fails, unlock the button so the user can try again.
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save this class. Please try again.';
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
                isEditing ? 'Edit class' : 'New class',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 20),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _nameCtrl,
                autofocus: !isEditing,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Class name, e.g. Calculus II',
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subjectCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Subject',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _teacherCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Teacher',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  hintText: 'Location or link',
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Day of week',
                style: Theme.of(context).textTheme.titleMedium,
              ),

              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: Weekday.values.map((w) {
                  final bool selected = w == _weekday;

                  return ChoiceChip(
                    label: Text(w.short),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _weekday = w;
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : () => _pickTime(true),
                      icon: const Icon(
                        Icons.schedule_rounded,
                      ),
                      label: Text(
                        _start.format(context),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : () => _pickTime(false),
                      icon: const Icon(
                        Icons.schedule_rounded,
                      ),
                      label: Text(
                        _end.format(context),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Class alarm'),
                subtitle: const Text(
                  'Real notification before class starts',
                ),
                value: _reminderEnabled,
                onChanged: _saving
                    ? null
                    : (v) {
                        setState(() {
                          _reminderEnabled = v;
                        });
                      },
              ),

              if (_reminderEnabled) ...[
                Wrap(
                  spacing: 8,
                  children: _leadOptions.map((m) {
                    final bool selected = m == _leadMinutes;

                    return ChoiceChip(
                      label: Text('$m min before'),
                      selected: selected,
                      onSelected: _saving
                          ? null
                          : (_) {
                              setState(() {
                                _leadMinutes = m;
                              });
                            },
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 12),

              TextField(
                controller: _notesCtrl,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Notes (optional)',
                ),
              ),

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
                          isEditing ? 'Save changes' : 'Add class',
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
