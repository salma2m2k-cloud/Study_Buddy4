import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/app_settings.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/classes_screen.dart';
import 'screens/study_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

class StudyBuddyApp extends StatelessWidget {
  const StudyBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppState>().settings;
    final ThemeMode themeMode = switch (settings.themeMode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };

    return MaterialApp(
      title: 'Study Buddy',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const _RootShell(),
    );
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell();

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  int _index = 0;

  void _goToTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();

    if (app.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> pages = [
      HomeScreen(onNavigateToTab: _goToTab),
      const TasksScreen(),
      const ClassesScreen(),
      const StudyScreen(),
      const NotesScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline_rounded), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Classes'),
          NavigationDestination(icon: Icon(Icons.timer_outlined), label: 'Study'),
          NavigationDestination(icon: Icon(Icons.note_outlined), label: 'Notes'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
