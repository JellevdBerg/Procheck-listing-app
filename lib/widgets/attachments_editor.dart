import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/attachment.dart';
import 'nocturne/nocturne_widgets.dart';

/// A list of [Attachment] chips plus an "Add attachment" button that opens
/// the native file picker — shared between [TaskTile]'s expanded detail and
/// the template editor, so a template's attachments use the same UI/picker
/// behavior as a task's.
class AttachmentsEditor extends StatelessWidget {
  const AttachmentsEditor({
    super.key,
    required this.attachments,
    required this.onAdd,
    required this.onRemoveAt,
  });

  final List<Attachment> attachments;
  final ValueChanged<List<Attachment>> onAdd;
  final ValueChanged<int> onRemoveAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ATTACHMENTS',
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 0.04,
            color: theme.hintColor,
          ),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < attachments.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AttachmentChip(
              attachment: attachments[i],
              onRemove: () => onRemoveAt(i),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: NocturneButton(
            label: 'Add attachment',
            icon: Icons.attach_file,
            dense: true,
            onPressed: _pickAttachments,
          ),
        ),
      ],
    );
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;

    onAdd(
      result.files
          .map(
            (f) => Attachment(
              name: f.name,
              size: f.size,
              path: kIsWeb ? null : f.path,
            ),
          )
          .toList(),
    );
  }
}

class AttachmentChip extends StatelessWidget {
  const AttachmentChip({
    super.key,
    required this.attachment,
    required this.onRemove,
  });

  final Attachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 15,
            color: theme.hintColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              attachment.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            attachment.sizeLabel,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            child: Icon(Icons.close, size: 13, color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}
