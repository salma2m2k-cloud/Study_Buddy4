import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/study_session.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();

    final sessions = [...app.studySessions]
      ..sort(
        (a, b) => b.startTime.compareTo(a.startTime),
      );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Today',
                      value: app.studyTimeToday.compact,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'This week',
                      value: app.studyTimeThisWeek.compact,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StudyTimerScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start studying'),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'History',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          if (sessions.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                emoji: '⏱️',
                title: 'No study sessions yet',
                message: 'Ready when you are.',
                actionLabel: 'Start studying',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StudyTimerScreen(),
                  ),
                ),
              ),
            )
          else
            SliverList.separated(
              itemCount: sessions.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final StudySession session = sessions[i];

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  child: Dismissible(
                    key: ValueKey(session.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCoral.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppTheme.accentCoral,
                      ),
                    ),
                    onDismissed: (_) =>
                        app.deleteStudySession(session.id),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGreen
                                    .withOpacity(0.14),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.menu_book_rounded,
                                color: AppTheme.accentGreen,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.subject,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  Text(
                                    '${DateFormat('EEE, MMM d · h:mm a').format(session.startTime)} · ${session.duration.compact}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  if (session.notes.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      session.notes,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ],
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
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                    color: color,
                    fontSize: 24,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudyTimerScreen extends StatefulWidget {
  const StudyTimerScreen({super.key});

  @override
  State<StudyTimerScreen> createState() => _StudyTimerScreenState();
}

class _StudyTimerScreenState extends State<StudyTimerScreen> {
  final TextEditingController _subjectCtrl =
      TextEditingController();

  final TextEditingController _notesCtrl =
      TextEditingController();

  DateTime? _startTime;
  Duration _elapsed = Duration.zero;
  bool _running = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _start() {
    final DateTime now = DateTime.now();

    setState(() {
      _startTime = now;
      _running = true;
      _elapsed = Duration.zero;
    });

    _tick();
  }

  Future<void> _tick() async {
    while (_running && mounted) {
      await Future.delayed(
        const Duration(seconds: 1),
      );

      if (!_running || !mounted) {
        return;
      }

      final DateTime? start = _startTime;

      if (start == null) {
        return;
      }

      setState(() {
        _elapsed = DateTime.now().difference(start);
      });
    }
  }

  Future<void> _finish() async {
    final DateTime? start = _startTime;

    setState(() {
      _running = false;
    });

    if (start == null || _elapsed.inSeconds < 1) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    final AppState app = context.read<AppState>();

    final DateTime end = DateTime.now();

    await app.addStudySession(
      startedAt: start,
      endedAt: end,
      subject: _subjectCtrl.text.trim().isEmpty
          ? 'Study session'
          : _subjectCtrl.text.trim(),
      note: _notesCtrl.text.trim(),
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatElapsed() {
    final int hours = _elapsed.inHours;
    final int minutes = _elapsed.inMinutes.remainder(60);
    final int seconds = _elapsed.inSeconds.remainder(60);

    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$mm:$ss';
    }

    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study session'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Spacer(),
            Text(
              _formatElapsed(),
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _running
                  ? 'Focus time running…'
                  : 'Ready when you are.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
            ),
            const Spacer(),
            TextField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(
                hintText: 'What are you studying?',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Notes (optional)',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: _running
                  ? FilledButton.icon(
                      onPressed: _finish,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Finish & save'),
                    )
                  : FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
