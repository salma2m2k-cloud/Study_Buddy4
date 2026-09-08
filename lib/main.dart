import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/app_state.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppState appState = AppState(
    storage: StorageService(),
    notifications: NotificationService(),
  );

  // Bootstrap loads all local data, sets up timezone-aware notifications,
  // and restores any pending reminders BEFORE the first frame that needs
  // them — but we still show a lightweight loading state in the UI in
  // case a slow device takes a moment (see _RootShell in app.dart).
  unawaited(appState.bootstrap());

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const StudyBuddyApp(),
    ),
  );
}
