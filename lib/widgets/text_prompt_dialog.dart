import 'package:flutter/material.dart';

import '../providers/settings_provider.dart';
import 'blurred_dialog.dart';

/// A simple dialog that prompts for a single line of text.
/// Returns the trimmed text, or null if cancelled / left empty.
Future<String?> showTextPromptDialog(
  BuildContext context, {
  required String title,
  String? initialValue,
  String confirmLabel = 'Save',
}) {
  final controller = TextEditingController(text: initialValue);
  return showBlurredDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        onSubmitted: (value) {
          final trimmed = value.trim();
          if (trimmed.isNotEmpty) Navigator.of(context).pop(trimmed);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final trimmed = controller.text.trim();
            if (trimmed.isNotEmpty) Navigator.of(context).pop(trimmed);
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

/// A dialog that prompts for a project name and an accent color together.
/// Returns the trimmed name and chosen [accentPalette] index, or null if
/// cancelled / left empty.
Future<(String, int)?> showProjectPromptDialog(
  BuildContext context, {
  required String title,
  String? initialValue,
  int initialColorIndex = 0,
  String confirmLabel = 'Save',
}) {
  final controller = TextEditingController(text: initialValue);
  var selectedColor = initialColorIndex;
  return showBlurredDialog<(String, int)>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < accentPalette.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => selectedColor = i),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: accentPalette[i],
                      child: selectedColor == i
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                Navigator.of(context).pop((trimmed, selectedColor));
              }
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showBlurredDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
