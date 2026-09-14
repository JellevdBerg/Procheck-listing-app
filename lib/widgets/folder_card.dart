import 'package:flutter/material.dart';

import '../models/checklist.dart';
import '../models/folder.dart';
import 'text_prompt_dialog.dart';

/// A folder tile for the home screen grid. [featured] gives the tall card
/// with a preview of up to 4 checklists; otherwise it's a compact,
/// name-only chip. Both reveal a delete button on hover.
class FolderCard extends StatefulWidget {
  const FolderCard({
    super.key,
    required this.folder,
    required this.checklists,
    required this.onTap,
    required this.onDelete,
    this.featured = false,
  });

  final Folder folder;
  final List<Checklist> checklists;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool featured;

  @override
  State<FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<FolderCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: widget.featured ? _buildFeatured(context) : _buildCompact(context),
    );
  }

  Widget _buildFeatured(BuildContext context) {
    final theme = Theme.of(context);
    final preview = widget.checklists.take(4).toList();
    final extra = widget.checklists.length - preview.length;

    return SizedBox(
      width: 240,
      height: 280,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.folder.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_hovering)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: 'Delete folder',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _confirmDelete(context),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Expanded(
                  child: preview.isEmpty
                      ? Center(
                          child: Text(
                            'No checklists yet',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final checklist in preview)
                              _ChecklistPreviewRow(checklist: checklist),
                            if (extra > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '+$extra more',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.hintColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_outlined, size: 18, color: theme.hintColor),
              const SizedBox(width: 8),
              Text(widget.folder.name),
              if (_hovering) ...[
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Delete folder',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmDelete(context),
                ),
              ] else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete folder?',
      message:
          'Checklists inside "${widget.folder.name}" will move to Unfiled. This cannot be undone.',
    );
    if (confirmed) widget.onDelete();
  }
}

class _ChecklistPreviewRow extends StatelessWidget {
  const _ChecklistPreviewRow({required this.checklist});

  final Checklist checklist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = checklist.items.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            checklist.isComplete
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            size: 14,
            color: checklist.isComplete
                ? Colors.green
                : theme.colorScheme.outline,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              checklist.name,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            total == 0 ? '—' : '${checklist.completedCount}/$total',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}
