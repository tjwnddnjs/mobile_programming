import '../widgets/target_selector.dart';
import '../models/contact_model.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'input_rule.dart';

class ReplyInstructionsField extends StatefulWidget {
  const ReplyInstructionsField({
    super.key,
    this.controller,
    this.onChanged,
    this.enabled = true,
    this.isContext = false,
    required this.onValidityChanged,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  final bool isContext;
  final ValueChanged<bool> onValidityChanged;

  @override
  State<ReplyInstructionsField> createState() => _ReplyInstructionsFieldState();
}

class _ReplyInstructionsFieldState extends State<ReplyInstructionsField> {
  bool _invalid = false;

  void _markInvalid(bool invalid) {
    if (_invalid == invalid) return;
    setState(() => _invalid = invalid);
    widget.onValidityChanged(!invalid);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      inputFormatters: [InputRule.words.formatter(_markInvalid)],
      maxLength: widget.isContext ? 1500 : 500,
      minLines: 2,
      maxLines: widget.isContext ? 4 : 3,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        errorText:
            _invalid ? InputRule.words.message : null,
        suffixIcon: _invalid
            ? IconButton(
                tooltip: 'Keep accepted text',
                icon: const Icon(Icons.check),
                onPressed: () => _markInvalid(false))
            : null,
        labelText: widget.isContext
            ? 'Additional context (optional)'
            : 'Additional instructions (optional)',
        hintText: widget.isContext
            ? 'Describe the dispute in English.'
            : 'e.g., Politely decline and suggest Friday',
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// Returns the instructions when confirmed, or null when the user cancels.
Future<String?> showReplyPreview(
  BuildContext context, {
  required List<String> images,
  required bool isCapture,
  required List<ContactModel> contacts,
  required ContactModel? initialTarget,
  required ValueChanged<ContactModel> onTargetChanged,
  Color? barrierColor,
}) {
  var selected = initialTarget;
  var instructions = '';
  var valid = true;
  return showDialog<String>(
    context: context,
    barrierColor: barrierColor,
    builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
              scrollable: true,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(isCapture ? 'Captured screen' : 'Review images'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TargetSelector(contacts: contacts, selected: selected, onChanged: (c) { update(() => selected = c); onTargetChanged(c); }),
                  for (final (index, image) in images.indexed) ...[
                    if (images.length > 1) Text('Image ${index + 1}'),
                    Image.memory(base64Decode(image),
                        height: 160, fit: BoxFit.contain),
                    const SizedBox(height: 8),
                  ],
                  ReplyInstructionsField(
                      onValidityChanged: (value) => update(() => valid = value),
                      onChanged: (value) => instructions = value),
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
                  onPressed:
                      valid ? () => Navigator.pop(context, instructions) : null,
                  child: const Text('Analyze'),
                ),
              ],
            )),
  );
}
