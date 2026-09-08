import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/date_utils.dart';
import '../utils/weekday.dart';
import '../widgets/class_card.dart';
import '../widgets/class_form.dart';
import '../widgets/empty_state.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final int todayIdx =
        Weekday.fromDateTimeWeekday(DateTime.now().weekday).index;
    _tabController =
        TabController(length: 7, vsync: this, initialIndex: todayIdx);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// The real calendar date of the given weekday within the CURRENT
  /// week (Sunday-start), so completion is tied to an actual date
  /// rather than an abstract weekday (spec #15, #28).
  DateTime _dateForWeekdayThisWeek(Weekday weekday) {
    final DateTime weekStart = AppDateUtils.startOfWeek(DateTime.now());
    return weekStart.add(Duration(days: weekday.index));
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: Weekday.values.map((w) => Tab(text: w.short)).toList(),
        ),
      ),
      body: app.classes.isEmpty
          ? EmptyState(
              emoji: '📚',
              title: 'No classes yet',
              message: 'Build your weekly schedule.',
              actionLabel: 'Add class',
              onAction: () => showClassForm(context, appState: app),
            )
          : TabBarView(
              controller: _tabController,
              children: Weekday.values.map((weekday) {
                final classesForDay = app.classesFor(weekday);
                final DateTime occurrenceDate = _dateForWeekdayThisWeek(weekday);

                if (classesForDay.isEmpty) {
                  return EmptyState(
                    emoji: '🗓️',
                    title: 'No classes on ${weekday.label}',
                    message: 'Enjoy the free day, or add one.',
                    actionLabel: 'Add class',
                    onAction: () => showClassForm(context, appState: app),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: classesForDay.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final classModel = classesForDay[i];
                    final bool completed = app.isClassOccurrenceCompleted(
                        classModel.id, occurrenceDate);
                    return ClassCard(
                      classModel: classModel,
                      isCompleted: completed,
                      onToggleCompleted: () => app.toggleClassOccurrenceCompleted(
                          classModel.id, occurrenceDate),
                      onTap: () =>
                          showClassForm(context, appState: app, existing: classModel),
                      onDelete: () => app.deleteClass(classModel.id),
                    );
                  },
                );
              }).toList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showClassForm(context, appState: app),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add class'),
      ),
    );
  }
}
