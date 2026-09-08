enum AppThemeMode { system, light, dark }

class AppSettings {
  AppThemeMode themeMode;
  int defaultReminderLeadMinutes;
  bool remindersGloballyEnabled;

  AppSettings({
    this.themeMode = AppThemeMode.system,
    this.defaultReminderLeadMinutes = 15,
    this.remindersGloballyEnabled = true,
  });

  AppSettings copyWith({
    AppThemeMode? themeMode,
    int? defaultReminderLeadMinutes,
    bool? remindersGloballyEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      defaultReminderLeadMinutes:
          defaultReminderLeadMinutes ?? this.defaultReminderLeadMinutes,
      remindersGloballyEnabled:
          remindersGloballyEnabled ?? this.remindersGloballyEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.index,
        'defaultReminderLeadMinutes': defaultReminderLeadMinutes,
        'remindersGloballyEnabled': remindersGloballyEnabled,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    try {
      final int themeIdx = (json['themeMode'] as int?) ?? 0;
      final AppThemeMode theme =
          (themeIdx >= 0 && themeIdx < AppThemeMode.values.length)
              ? AppThemeMode.values[themeIdx]
              : AppThemeMode.system;
      return AppSettings(
        themeMode: theme,
        defaultReminderLeadMinutes:
            (json['defaultReminderLeadMinutes'] as int?) ?? 15,
        remindersGloballyEnabled:
            (json['remindersGloballyEnabled'] as bool?) ?? true,
      );
    } catch (_) {
      return AppSettings();
    }
  }
}
