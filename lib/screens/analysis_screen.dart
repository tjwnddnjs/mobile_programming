import 'dart:convert';

import 'package:flutter/material.dart';

import '../ui/tiki_theme.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/contact_provider.dart';
import '../providers/auth_provider.dart';
import '../services/openrouter_service.dart';
import '../services/screen_capture_service.dart';
import '../widgets/reply_instructions_field.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _service = OpenRouterService();
  final _instructions = TextEditingController();
  String? _image;

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }
  List<String>? _replies;
  String? _error;
  bool _busy = false;

  Future<void> _selectImage() async {
    setState(() { _busy = true; _error = null; });
    try {
      final image = await ScreenCaptureService.pickImageAsBase64();
      if (!mounted) return;
      if (image != null) {
        setState(() { _image = image; _replies = null; });
      }
    } on PlatformException catch (error) {
      debugPrint('Image selection failed: ${error.code}');
      if (mounted) {
        setState(() => _error =
            error.message ?? 'Could not open the image. Please try again.');
      }
    } on MissingPluginException {
      debugPrint('Image selection channel is unavailable.');
      if (mounted) {
        setState(() => _error =
            'Photo picker is unavailable. Close and reopen the app.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the image. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _analyze() async {
    final target = context.read<ContactProvider>().activeTarget;
    if (target == null) {
      setState(() => _error = 'Select a contact on the Home screen first.');
      return;
    }
    if (_image == null) return;
    setState(() { _busy = true; _error = null; _replies = null; });
    try {
      final replies = await _service.getChatRecommendations(
        base64Screenshot: _image!, targetContact: target,
        user: context.read<AuthProvider>().currentUser,
        additionalInstructions: _instructions.text,
      );
      if (mounted) {
        _instructions.clear();
        setState(() => _replies = replies);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error is StateError ? error.message : 'Analysis failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = context.watch<ContactProvider>().activeTarget;
    return Scaffold(
      appBar: const TikiAppBar(title: 'Reply Suggestions'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TikiPanel(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(
                target == null
                    ? 'No contact selected.'
                    : 'Contact: ${target.name}',
                style: Tiki.label,
              ),
              subtitle: target == null ? null : Text(target.relationship),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Select a conversation image to get three suggested replies.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _selectImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Attach image'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Use the floating assistant to capture the screen of another app.',
            style: TextStyle(fontSize: 12),
          ),
          if (_image != null) ...[
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: Image.memory(base64Decode(_image!), fit: BoxFit.contain),
            ),
            const SizedBox(height: 8),
            const Text(
              'OpenRouter receives the image, selected contact details, relevant profile details and preferences, and any additional instructions.',
              style: TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          ReplyInstructionsField(controller: _instructions, enabled: !_busy),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _busy || _image == null ? null : _analyze,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Get suggested replies'),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_replies != null) ...[
            const SizedBox(height: 20),
            Text(
              'Suggested replies',
              style: Tiki.display.copyWith(fontSize: 27),
            ),
            const SizedBox(height: 10),
            for (final reply in _replies!)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TikiPanel(
                  child: ListTile(
                    title: Text(reply),
                    trailing: const _CopyBadge(),
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: reply));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reply copied.')),
                        );
                      }
                    },
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CopyBadge extends StatelessWidget {
  const _CopyBadge();

  @override
  Widget build(BuildContext context) => const Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(color: Tiki.lilac, borderRadius: Tiki.radius),
        child: Padding(
          padding: EdgeInsets.all(5),
          child: Icon(Icons.copy_outlined, size: 18),
        ),
      ),
      Text('Copy', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
    ],
  );
}
