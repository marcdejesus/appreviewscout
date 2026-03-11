import 'package:flutter/material.dart';

import '../../config/theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final normalized = status.toLowerCase();
    final (label, color) = switch (normalized) {
      'pending' => ('Pending', tokens.warning),
      'running' => ('Running', tokens.accent),
      'done' => ('Done', tokens.success),
      'failed' => ('Failed', tokens.error),
      _ => ('Idle', tokens.textTertiary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
            ),
      ),
    );
  }
}
