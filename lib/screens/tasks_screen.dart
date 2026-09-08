import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/task_card.dart';
import '../widgets/task_form.dart';

enum _TaskFilter { all, upcoming, overdue, completed }

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  _TaskFilter _filter = _TaskFilter.all;

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final allTasks = [...app.tasks]
      ..sort((a, b) {
        if (a.dueAt == null && b.dueAt == null) return 0;
        if (a.dueAt == null) return 1;
        if (b.dueAt == null) return -1;
        return a.dueAt!.compareTo(b.dueAt!);
      });

    final tasks = switch (_filter) {
      _TaskFilter.all => allTasks.where((t) => !t.isCompleted).toList(),
      _TaskFilter.upcoming => app.upcomingTasks,
      _TaskFilter.overdue => app.overdueTasks,
      _TaskFilter.completed => allTasks.where((t) => t.isCompleted).toList(),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Active',
                    selected: _filter == _TaskFilter.all,
                    onTap: () => setState(() => _filter = _TaskFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Upcoming',
                    selected: _filter == _TaskFilter.upcoming,
                    onTap: () => setState(() => _filter = _TaskFilter.upcoming),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Overdue',
                    selected: _filter == _TaskFilter.overdue,
                    onTap: () => setState(() => _filter = _TaskFilter.overdue),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Completed',
                    selected: _filter == _TaskFilter.completed,
                    onTap: () => setState(() => _filter = _TaskFilter.completed),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: tasks.isEmpty
                ? EmptyState(
                    emoji: '✅',
                    title: 'No tasks yet',
                    message: app.tasks.isEmpty
                        ? 'Add your first task and get your day organized.'
                        : 'Nothing here for this filter.',
                    actionLabel: 'Add task',
                    onAction: () => showTaskForm(context, appState: app),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final task = tasks[i];
                      return TaskCard(
                        task: task,
                        onToggleComplete: () => app.toggleTaskCompleted(task.id),
                        onTap: () => showTaskForm(context, appState: app, existing: task),
                        onDelete: () => app.deleteTask(task.id),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTaskForm(context, appState: app),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add task'),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
