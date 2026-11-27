import '../widgets/target_selector.dart';
import 'reply_instructions_field.dart';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../ui/tiki_theme.dart';
import 'thinking_indicator.dart';

import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../services/screen_capture_service.dart';
import '../services/reply_clipboard.dart';
import '../models/contact_model.dart';
import '../models/moonchul_model.dart';
import '../models/user_model.dart';
import '../services/openrouter_service.dart';

class MoonchulDialog extends StatefulWidget {
  final List<ContactModel> contacts;
  final ContactModel? targetContact;
  final OpenRouterService openRouterService;
  final bool isSystemOverlay;
  final bool isPage;
  final JudgmentStyle judgmentStyle;
  const MoonchulDialog(
      {super.key,
      this.targetContact,
      required this.contacts,
      required this.openRouterService,
      this.isSystemOverlay = false,
      this.isPage = false,
      this.judgmentStyle = JudgmentStyle.balanced});
  @override
  State<MoonchulDialog> createState() => _MoonchulDialogState();
}

class _MoonchulDialogState extends State<MoonchulDialog> {
  String? _selectedId;
  ContactModel? get _target => widget.contacts.where((c) => c.id == _selectedId).firstOrNull ?? widget.targetContact;
  bool _validContext = true;
  final _contextNote = TextEditingController();
  static const _maxImages = 5;
  final List<String> _images = [];
  String _mySide = 'Right-side bubbles';
  bool _loading = false;
  bool _showThinking = false;
  String? _error;
  MoonchulResult? _result;
  int? _copiedReplyIndex;
  AnonymousMoonchulResult? _anonymousResult;

  @override
  void dispose() {
    _contextNote.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.isSystemOverlay) {
        FocusManager.instance.primaryFocus?.unfocus();
        await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
        await FlutterOverlayWindow.resizeOverlay(1, 1, false);
      }
      final images = await ScreenCaptureService.pickImagesAsBase64();
      if (!mounted) return;
      if (images != null && images.isNotEmpty) {
        final remaining = _maxImages - _images.length;
        if (images.length > remaining) {
          throw StateError('You can attach up to $_maxImages images in total. '
              'Select up to $remaining more.');
        }
        // 미리보기 불가능한 입력은 분석 전에 알립니다.
        for (final image in images) {
          base64Decode(image);
        }
        setState(() {
          _images.addAll(images);
          _result = null;
          _anonymousResult = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is PlatformException
            ? (error.message ?? 'Could not read the image.')
            : error is StateError
                ? error.message
                : 'Could not read the image. Choose an image saved on this device.');
      }
    } finally {
      try {
        if (widget.isSystemOverlay && mounted) {
          await FlutterOverlayWindow.resizeOverlay(340, 620, false);
          await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
        }
      } catch (_) {
        if (mounted) {
          setState(() => _error = 'Could not restore the floating window. Please reopen it.');
        }
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _showThinking = true;
      _error = null;
      _copiedReplyIndex = null;
    });
    try {
      if (_mySide == 'I cannot tell') {
        final result = await widget.openRouterService.analyzeAnonymousConversation(
          base64Images: _images,
          contextNote: _contextNote.text.trim(),
          judgmentStyle: widget.judgmentStyle,
        );
        if (mounted) setState(() => _anonymousResult = result);
        return;
      }
      final result = await widget.openRouterService.analyzeMoonchulFault(
          base64Images: _images,
          targetContact: _target,
          mySide: _mySide,
          contextNote: _contextNote.text.trim(),
          judgmentStyle: widget.judgmentStyle,
        );
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            e is StateError ? e.message : 'Analysis failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _showThinking = false;
        });
      }
    }
  }

  Widget _section(String title, String body, {Color color = Tiki.white}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, right: 2),
      child: TikiPanel(
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Tiki.display.copyWith(fontSize: 17)),
              const SizedBox(height: 6),
              SelectableText(body),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formBlock(List<Widget> children) => TikiPanel(
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final anonymousResult = _anonymousResult;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.isPage)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
            child: Row(
              children: [
                const Icon(Icons.balance, color: Tiki.ink),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Moonchul: Conflict Analysis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        if (!widget.isPage) const Divider(),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (result == null && anonymousResult == null) ...[
                  TargetSelector(pageLayout: widget.isPage, contacts: widget.contacts, selected: _target, onChanged: _loading ? null : (c) => setState(() => _selectedId = c.id)), 
                  const Text(
                    'See who said what, what caused the conflict, and how you could respond.',
                  ),
                  const SizedBox(height: 12),
                  Text('Analysis style: ${widget.judgmentStyle.label}'),
                  const SizedBox(height: 12),
                  _formBlock([
                    const Text(
                      'Conversation screenshots (up to $_maxImages)',
                      style: Tiki.label,
                    ),
                    const Text(
                      'Add screenshots in chronological order. You can add them one at a time.',
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading || _images.length >= _maxImages
                          ? null
                          : _pickImages,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        _images.isEmpty
                            ? 'Choose images'
                            : 'Add more images',
                      ),
                    ),
                    if (_images.isNotEmpty)
                      SizedBox(
                        height: 140,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, i) => SizedBox(
                            width: 92,
                            child: Column(
                              children: [
                                Text('Image ${i + 1}'),
                                Expanded(
                                  child: Image.memory(
                                    base64Decode(_images[i]),
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, error, stack) =>
                                        const Center(
                                      child: Text('Preview unavailable'),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove image',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: _loading
                                      ? null
                                      : () =>
                                          setState(() => _images.removeAt(i)),
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  _formBlock([
                    const Text(
                      'Where are your messages?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _mySide,
                      items: [
                        'Right-side bubbles',
                        'Left-side bubbles',
                        'I cannot tell',
                      ]
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s == 'I cannot tell'
                                  ? 'Other people / unsure'
                                  : s),
                            ),
                          )
                          .toList(),
                      onChanged:
                          _loading ? null : (v) => setState(() => _mySide = v!),
                    ),
                    if (_mySide == 'I cannot tell')
                      const Text(
                        'For a dispute between other people, add the two names as shown in the chat below.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  ReplyInstructionsField(
                    controller: _contextNote,
                    isContext: true,
                    enabled: !_loading,
                    onValidityChanged: (v) => setState(() => _validContext = v),
                  ),
                  Text(
                    _mySide == 'I cannot tell'
                        ? 'OpenRouter receives the images, context, and analysis style. Cover any private details you do not need to share.'
                        : 'OpenRouter receives the images, message side, context, analysis style, and selected contact name and relationship. Cover any private details you do not need to share.',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: Tiki.filled(Tiki.coral),
                    onPressed: _loading || !_validContext || _images.isEmpty ? null : _analyze,
                    child: Text(
                      _loading
                          ? 'Analyzing the conversation…'
                          : 'Analyze conflict',
                    ),
                  ),
                  if (_showThinking)
                    const ThinkingIndicator(label: 'Reading the conversation…', color: Tiki.coral)
                  else if (_loading)
                    const LinearProgressIndicator(),
                ] else if (anonymousResult != null) ...[
                  _section(
                    anonymousResult.canJudge
                        ? 'Responsibility assessment'
                        : 'Assessment deferred',
                    anonymousResult.summary,
                    color: Tiki.coral,
                  ),
                  Text(
                    'Confidence: ${anonymousResult.confidence}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  if (anonymousResult.participants.isEmpty)
                    _section(
                      'Participants',
                      'The participants could not be confidently identified from the images.',
                    ),
                  for (final person in anonymousResult.participants)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              person.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              'Identifying clue: ${person.identification}',
                            ),
                            const SizedBox(height: 6),
                            SelectableText(person.analysis),
                          ],
                        ),
                      ),
                    ),
                  if (anonymousResult.evidence.isNotEmpty)
                    _section(
                      'Evidence from the conversation',
                      anonymousResult.evidence.map((e) => '• $e').join('\n\n'),
                    ),
                  if (anonymousResult.missingContext.isNotEmpty)
                    _section(
                      'What to clarify',
                      anonymousResult.missingContext
                          .map((e) => '• $e')
                          .join('\n'),
                    ),
                  _section(
                    'How to resolve the conflict',
                    anonymousResult.reconciliationAdvice,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The AI interpretation is based on the visible conversation.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _anonymousResult = null;
                      _error = null;
                    }),
                    child: const Text('Edit inputs and try again'),
                  ),
                ] else if (result != null) ...[
                  _section(
                    result.canJudge
                        ? 'Responsibility assessment'
                        : 'Assessment deferred',
                    result.summary,
                    color: Tiki.coral,
                  ),
                  Text(
                    'Confidence: ${result.confidence}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  if (result.canJudge) ...[
                    _section(
                      'Estimated responsibility',
                      'You: ${result.myRatio}% · Other person: ${result.otherRatio}%',
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: result.myRatio / 100,
                      minHeight: 12,
                      color: Tiki.coral,
                      backgroundColor: Tiki.lilac,
                    ),
                  ],
                  _section(
                    'Evidence from the conversation',
                    result.evidence.isEmpty
                        ? 'There is not enough evidence to assess the conversation.'
                        : result.evidence.map((e) => '• $e').join('\n\n'),
                  ),
                  _section('Your actions', result.myFaultAnalysis),
                  _section(
                    'Other person\'s actions',
                    result.otherFaultAnalysis,
                  ),
                  if (result.missingContext.isNotEmpty)
                    _section(
                      'What to clarify',
                      result.missingContext.map((e) => '• $e').join('\n'),
                    ),
                  _section(
                    'Steps to resolve the conflict',
                    result.reconciliationAdvice,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'What to say next',
                    style: Tiki.display.copyWith(fontSize: 20),
                  ),
                  for (var i = 0; i < result.recommendedReplies.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, right: 2),
                      child: TikiPanel(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                [
                                  'Explain calmly',
                                  'Set a boundary',
                                  'Propose an agreement',
                                ][i],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SelectableText(result.recommendedReplies[i]),
                              TextButton.icon(
                                onPressed: () async {
                                  await copyReply(
                                    result.recommendedReplies[i],
                                    isSystemOverlay: widget.isSystemOverlay,
                                  );
                                  if (mounted) {
                                    setState(() => _copiedReplyIndex = i);
                                  }
                                },
                                icon: Icon(
                                  _copiedReplyIndex == i
                                      ? Icons.check
                                      : Icons.copy,
                                  size: 16,
                                ),
                                label: Text(
                                  _copiedReplyIndex == i
                                      ? 'Reply copied'
                                      : 'Copy reply',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'The AI assessment is limited to the visible conversation and has no legal standing.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _result = null;
                      _error = null;
                    }),
                    child: const Text('Edit inputs and try again'),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Tiki.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    if (widget.isPage) return content;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
        child: content,
      ),
    );
  }
}
