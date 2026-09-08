import 'package:flutter/material.dart';

import '../models/class_model.dart';
import '../theme/app_theme.dart';

class ClassCard extends StatelessWidget {
  final ClassModel classModel;
  final bool isCompleted;
  final VoidCallback onToggleCompleted;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ClassCard({
    super.key,
    required this.classModel,
    required this.isCompleted,
    required this.onToggleCompleted,
    required this.onTap,
    required this.onDelete,
  });

  String _time(int h, int m) {
    final int hour12 = h % 12 == 0 ? 12 : h % 12;
    final String suffix = h < 12 ? 'AM' : 'PM';
    final String minute = m.toString().padLeft(2, '0');
    return '$hour12:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(classModel.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: AppTheme.accentCoral.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentCoral),
      ),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(classModel.name,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${_time(classModel.startHour, classModel.startMinute)} – '
                        '${_time(classModel.endHour, classModel.endMinute)}'
                        '${classModel.location.isNotEmpty ? ' · ${classModel.location}' : ''}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      if (classModel.reminderEnabled) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.notifications_active_rounded,
                                size: 13, color: AppTheme.accentAmber),
                            const SizedBox(width: 4),
                            Text(
                              '${classModel.reminderLeadMinutes}m alarm',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.accentAmber,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Semantics(
                  label: isCompleted
                      ? 'Class completed, tap to undo'
                      : 'Mark class complete',
                  button: true,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onToggleCompleted,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_off_rounded,
                        color: isCompleted ? AppTheme.accentGreen : scheme.outline,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
