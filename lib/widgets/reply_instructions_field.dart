import 'dart:convert';

import 'package:flutter/material.dart';

class ReplyInstructionsField extends StatelessWidget {
  const ReplyInstructionsField({
    super.key,
    this.controller,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      enabled: enabled,
      maxLength: 500,
      minLines: 2,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Additional instructions (optional)',
        hintText: 'e.g., Politely decline and suggest Friday',
        border: OutlineInputBorder(),
      ),
    );
  }
}

/// Returns the instructions when confirmed, or null when the user cancels.
Future<String?> showReplyPreview(
  BuildContext context, {
  required List<String> images,
  required bool isCapture,
  Color? barrierColor,
}) {
  var instructions = '';
  return showDialog<String>(
    context: context,
    barrierColor: barrierColor,
    builder: (context) => AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(isCapture ? 'Captured screen' : 'Review images'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, image) in images.indexed) ...[
            if (images.length > 1) Text('Image ${index + 1}'),
            Image.memory(base64Decode(image), height: 160, fit: BoxFit.contain),
            const SizedBox(height: 8),
          ],
          ReplyInstructionsField(onChanged: (value) => instructions = value),
          const Text(
            'OpenRouter receives the images, selected contact details, '
            'relevant profile details and preferences, and any additional instructions.',
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, instructions),
          child: const Text('Analyze'),
        ),
      ],
    ),
  );
}
