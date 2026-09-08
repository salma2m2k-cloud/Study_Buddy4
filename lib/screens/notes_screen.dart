import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/note_form.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final filtered = _query.trim().isEmpty
        ? app.notes
        : app.notes
            .where((n) =>
                n.title.toLowerCase().contains(_query.toLowerCase()) ||
                n.content.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: Column(
        children: [
          if (app.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search notes',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() {
                            _searchCtrl.clear();
                            _query = '';
                          }),
                        ),
                ),
              ),
            ),
          Expanded(
            child: app.notes.isEmpty
                ? EmptyState(
                    emoji: '📝',
                    title: 'No notes yet',
                    message: 'Keep your important thoughts here.',
                    actionLabel: 'Add note',
                    onAction: () => showNoteForm(context, appState: app),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No notes match "$_query"',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final note = filtered[i];
                          return Dismissible(
                            key: ValueKey(note.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(Icons.delete_outline_rounded,
                                  color: Theme.of(context).colorScheme.error),
                            ),
                            onDismissed: (_) => app.deleteNote(note.id),
                            child: Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () =>
                                    showNoteForm(context, appState: app, existing: note),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(note.title,
                                          style: Theme.of(context).textTheme.titleMedium),
                                      if (note.content.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          note.content,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Text(
                                        'Edited ${DateFormat('MMM d, h:mm a').format(note.updatedAt)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showNoteForm(context, appState: app),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add note'),
      ),
    );
  }
}
