import 'package:flutter/material.dart';

import '../models/checklist.dart';

class ChecklistTile extends StatelessWidget {
  const ChecklistTile({
    super.key,
    required this.checklist,
    required this.onTap,
    this.trailing,
  });

  final Checklist checklist;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final total = checklist.items.length;
    final done = checklist.completedCount;
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: checklist.isComplete
            ? Colors.green.withValues(alpha: 0.15)
            : theme.colorScheme.primary.withValues(alpha: 0.12),
        child: Icon(
          checklist.isComplete
              ? Icons.check_circle
              : Icons.checklist_rtl_rounded,
          color: checklist.isComplete
              ? Colors.green
              : theme.colorScheme.primary,
        ),
      ),
      title: Text(checklist.name),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : checklist.progress,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              total == 0 ? 'Empty' : '$done/$total',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      trailing: trailing,
    );
  }
}
