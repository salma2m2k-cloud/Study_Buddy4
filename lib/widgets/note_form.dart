import 'package:flutter/material.dart';

import '../models/note.dart';
import '../providers/app_state.dart';

Future<void> showNoteForm(
  BuildContext context, {
  required AppState appState,
  Note? existing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _NoteFormSheet(appState: appState, existing: existing),
  );
}

class _NoteFormSheet extends StatefulWidget {
  final AppState appState;
  final Note? existing;

  const _NoteFormSheet({required this.appState, this.existing});

  @override
  State<_NoteFormSheet> createState() => _NoteFormSheetState();
}

class _NoteFormSheetState extends State<_NoteFormSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.existing?.content ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give this note a title.');
      return;
    }
    if (widget.existing == null) {
      await widget.appState.addNote(title: title, content: _contentCtrl.text.trim());
    } else {
      await widget.appState.updateNote(widget.existing!.id, (n) {
        n.title = title;
        n.content = _contentCtrl.text.trim();
        return n;
      });
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                isEditing ? 'Edit note' : 'New note',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                autofocus: !isEditing,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentCtrl,
                textCapitalization: TextCapitalization.sentences,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(hintText: 'Write your note...'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(isEditing ? 'Save changes' : 'Add note'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
