# Study Buddy

A local-first Flutter student productivity app: classes, tasks, study
sessions, notes, weekly progress, and **real scheduled OS notifications**
for task reminders and recurring class alarms. No backend, no login,
no cloud — everything lives on the device.

This project was written by hand (no `flutter` SDK was available in the
environment that generated it), so **one setup step is required before
your first build**: generating the Gradle wrapper jar and default app
icons, which are binary files that can't be authored as text.

---

## 1. One-time setup

You need a working Flutter install (stable channel, Flutter 3.22+ /
Dart 3.4+) and Android Studio's SDK + a device or emulator on API 23+.

```bash
cd study_buddy
flutter pub get
```

Then generate the two binary pieces Gradle needs (safe — it will not
overwrite the custom `AndroidManifest.xml`, Kotlin, or Gradle files
already in this project, only fill in what's missing):

```bash
# From the study_buddy/ directory:
flutter build apk --debug
```

If this is the very first build on your machine and Gradle complains
about a missing wrapper jar, run:

```bash
cd android
gradle wrapper --gradle-version 8.6
cd ..
```

Also copy `android/local.properties.example` to `android/local.properties`
and fill in your real SDK paths (this file is machine-specific and is
already gitignored):

```bash
cp android/local.properties.example android/local.properties
# then edit sdk.dir and flutter.sdk inside it
```

Launcher icons: the project ships a minimal launch background, but
Android needs `mipmap` launcher icons. Easiest path — install
`flutter_launcher_icons` as a dev dependency and point it at any square
PNG you like, or just let Android Studio's "Image Asset" wizard
generate `android/app/src/main/res/mipmap-*/ic_launcher.png` for you.
The app builds and runs fine with the platform's default icon in the
meantime.

## 2. Run it

```bash
flutter pub get
flutter run
```

## 3. Build a release-ish APK

```bash
flutter build apk --release
```

The build is currently signed with the debug key (see
`android/app/build.gradle`) so it installs immediately on a test
device. Before publishing anywhere, replace `signingConfigs.debug`
with your own keystore.

---

## What's implemented

- **Local persistence** (`lib/services/storage_service.dart`) — all
  tasks, classes, class-completion records, study sessions, notes, and
  settings are saved as JSON via `shared_preferences`, which is backed
  by durable platform storage. Survives app close, force-close, and
  phone restart.
- **Real scheduled notifications**
  (`lib/services/notification_service.dart`) — built on
  `flutter_local_notifications` + `timezone` + `flutter_timezone`.
  - Task reminders are one-shot `zonedSchedule` calls at
    `dueAt - leadMinutes`, cancelled if the task is completed, deleted,
    or edited, and never scheduled in the past.
  - Class alarms use `matchDateTimeComponents:
    DateTimeComponents.dayOfWeekAndTime`, so the OS itself repeats the
    alarm every week — no manual re-scheduling loop, no drift.
  - Every notification uses a **stable id** derived from the entity's
    UUID, so edits/restores always cancel-then-reschedule under the
    same id instead of creating duplicates.
  - Verbose `dev.log` calls throughout scheduling so you can watch
    exactly what's being scheduled, for what real date/time, in which
    timezone (see `flutter logs` while testing).
- **Weekday handling** (`lib/utils/weekday.dart`) — a single explicit
  `Weekday` enum (Sunday-first) used everywhere, converted at the
  boundary from/to `DateTime.weekday` in exactly one place, so the UI,
  storage, and notification scheduling can never disagree about which
  day something is on.
- **Recurring classes vs. occurrence completion** — a `ClassModel` is
  the recurring weekly definition; `ClassCompletion` records are keyed
  to `(classId, real calendar date)`, so completing this Monday's
  Math class never touches the recurring class or next Monday's
  occurrence.
- **Calendar-week boundaries** (`lib/utils/date_utils.dart`) — one
  `startOfWeek`/`endOfWeek` definition (Sunday-start) used by every
  weekly-progress calculation.
- **Real, non-fake progress numbers** — Home and the weekly progress
  card compute completion fractions directly from stored tasks,
  class-completion records, and study-session durations. Nothing is
  hardcoded.
- **Settings** — theme (system/light/dark), default reminder lead
  time, notification permission status + test button + pending-count,
  and a confirm-before-delete "clear all data" action that preserves
  settings.
- **Empty states, quick actions, motivational microcopy, accessible
  progress bars** (never color-only) across every screen.

## Manual testing checklist (do this before calling it done — see spec)

1. **Tasks**: create with a due time 2 minutes out + reminder → close
   the app fully → confirm the notification still fires. Complete a
   task before its reminder → confirm it's cancelled (check Settings →
   "Pending reminders" count). Edit a task's time → confirm only one
   reminder remains scheduled. Delete → confirm it's gone.
2. **Classes**: create a class for tomorrow's weekday with a 1-minute
   lead time → confirm the alarm fires at the right real local time,
   even with the phone locked. Edit the class time → confirm the old
   alarm is replaced (not duplicated). Delete → confirm cancellation.
   Restart the phone → confirm the class alarm is still scheduled
   (Settings → Pending reminders).
3. **Completion**: mark today's class occurrence complete → confirm
   weekly progress updates, the class still appears next week, and
   it's not marked complete for next week.
4. **Study**: start a session, wait a bit, finish → confirm the exact
   elapsed duration is saved and reflected in Today/This week totals
   after an app restart.
5. **Notes**: create, edit, delete, restart the app → confirm
   persistence.

## Project layout

```
lib/
  models/        Task, ClassModel, ClassCompletion, StudySession, Note, AppSettings
  services/      StorageService (persistence), NotificationService (OS alarms)
  providers/     AppState — single ChangeNotifier tying storage+notifications+logic together
  screens/       Home, Tasks, Classes, Study, Notes, Settings
  widgets/       Cards, forms (bottom sheets), empty states, progress bars
  theme/         AppTheme — one consistent light/dark design language
  utils/         Weekday enum, calendar-week helpers
```
