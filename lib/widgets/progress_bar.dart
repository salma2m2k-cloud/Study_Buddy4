import 'package:flutter/material.dart';

/// A labeled progress bar. Always paired with a text fraction (e.g.
/// "4 / 6") so completion is never communicated by color alone
/// (spec #36).
class AppProgressBar extends StatelessWidget {
  final String label;
  final int done;
  final int total;
  final Color color;

  const AppProgressBar({
    super.key,
    required this.label,
    required this.done,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final double fraction = total == 0 ? 0 : (done / total).clamp(0, 1);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label progress: $done of $total complete',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              Text(
                total == 0 ? '—' : '$done / $total',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : fraction.toDouble(),
              minHeight: 10,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
