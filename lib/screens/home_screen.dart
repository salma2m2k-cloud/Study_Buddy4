import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/study_session.dart'; // for Duration.compact extension
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/progress_bar.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/task_card.dart';
import '../widgets/task_form.dart';
import '../widgets/class_form.dart';
import '../widgets/note_form.dart';
import 'study_screen.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int tabIndex) onNavigateToTab;

  const HomeScreen({super.key, required this.onNavigateToTab});

  String _greeting() {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning ☀️';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final int doneToday = app.relevantTasksToday.where((t) => t.isCompleted).length;
    final int totalToday = app.relevantTasksToday.length;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_greeting(), style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMMM d').format(DateTime.now()),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),

          // Quick actions
          SliverToBoxAdapter(
            child: SizedBox(
              height: 108,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  QuickActionButton(
                    icon: Icons.add_task_rounded,
                    label: 'Add task',
                    color: Theme.of(context).colorScheme.primary,
                    onTap: () => showTaskForm(context, appState: app),
                  ),
                  const SizedBox(width: 10),
                  QuickActionButton(
                    icon: Icons.school_rounded,
                    label: 'Add class',
                    color: AppTheme.accentAmber,
                    onTap: () => showClassForm(context, appState: app),
                  ),
                  const SizedBox(width: 10),
                  QuickActionButton(
                    icon: Icons.timer_rounded,
                    label: 'Start studying',
                    color: AppTheme.accentGreen,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StudyTimerScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  QuickActionButton(
                    icon: Icons.note_add_rounded,
                    label: 'Add note',
                    color: AppTheme.accentCoral,
                    onTap: () => showNoteForm(context, appState: app),
                  ),
                ],
              ),
            ),
          ),

          // Today's progress
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppProgressBar(
                        label: "Today's Progress",
                        done: doneToday,
                        total: totalToday,
                        color: AppTheme.accentGreen,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.emoji_objects_rounded,
                              size: 16, color: AppTheme.accentAmber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              app.motivationalMessage,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic,
                                  ),
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

          // Overview row: classes today / study time
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.school_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      label: 'Classes today',
                      value: '${app.todayClasses.length}',
                      onTap: () => onNavigateToTab(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.timer_rounded,
                      color: AppTheme.accentGreen,
                      label: 'Studied today',
                      value: app.studyTimeToday.compact,
                      onTap: () => onNavigateToTab(3),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (app.nextUpcomingClass != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _NextUpBanner(),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weekly Progress', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      AppProgressBar(
                        label: 'Tasks',
                        done: app.weeklyTaskProgress.tasksDone,
                        total: app.weeklyTaskProgress.tasksTotal,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      AppProgressBar(
                        label: 'Classes',
                        done: app.weeklyClassProgress.classesDone,
                        total: app.weeklyClassProgress.classesTotal,
                        color: AppTheme.accentAmber,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Study time', style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            app.studyTimeThisWeek.compact,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.accentGreen,
                                  fontWeight: FontWeight.w700,
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

          // Today's tasks header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Today's tasks", style: Theme.of(context).textTheme.titleLarge),
                  TextButton(
                    onPressed: () => onNavigateToTab(1),
                    child: const Text('See all'),
                  ),
                ],
              ),
            ),
          ),

          if (app.todayTasks.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  'Nothing due today. Enjoy the breathing room 🎉',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            )
          else
            SliverList.separated(
              itemCount: app.todayTasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final task = app.todayTasks[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TaskCard(
                    task: task,
                    onToggleComplete: () => app.toggleTaskCompleted(task.id),
                    onTap: () => showTaskForm(context, appState: app, existing: task),
                    onDelete: () => app.deleteTask(task.id),
                  ),
                );
              },
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.14), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: Theme.of(context).textTheme.titleLarge),
                    Text(label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextUpBanner extends StatelessWidget {
  const _NextUpBanner();

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final next = app.nextUpcomingClass!;
    final DateTime occurrence = next.nextOccurrenceStart(DateTime.now());
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.notifications_active_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Up next: ${next.name}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          )),
                  Text(
                    DateFormat('EEEE · h:mm a').format(occurrence),
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer
                          .withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
