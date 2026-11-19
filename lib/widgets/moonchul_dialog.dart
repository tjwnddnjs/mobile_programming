import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../services/screen_capture_service.dart';
import '../models/contact_model.dart';
import '../models/moonchul_model.dart';
import '../services/openrouter_service.dart';

class MoonchulDialog extends StatefulWidget {
  final ContactModel? targetContact;
  final OpenRouterService openRouterService;
  final bool isSystemOverlay;
  final bool isPage;
  const MoonchulDialog(
      {super.key,
      this.targetContact,
      required this.openRouterService,
      this.isSystemOverlay = false,
      this.isPage = false});
  @override
  State<MoonchulDialog> createState() => _MoonchulDialogState();
}

class _MoonchulDialogState extends State<MoonchulDialog> {
  final _contextNote = TextEditingController();
  List<String> _images = [];
  String _mySide = '오른쪽 말풍선';
  bool _loading = false;
  String? _error;
  MoonchulResult? _result;
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
      if (widget.isSystemOverlay)
        await FlutterOverlayWindow.resizeOverlay(1, 1, false);
      final images = await ScreenCaptureService.pickImagesAsBase64();
      if (!mounted) return;
      if (images != null && images.isNotEmpty) {
        if (images.length > 5) throw StateError('사진은 최대 5장까지 선택해주세요.');
        // 미리보기 불가능한 입력은 분석 전에 알립니다.
        for (final image in images) {
          base64Decode(image);
        }
        setState(() {
          _images = images;
          _result = null;
          _anonymousResult = null;
        });
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = '사진을 불러오지 못했습니다. 최대 5장의 대화 사진을 선택해주세요.');
    } finally {
      try {
        if (widget.isSystemOverlay)
          await FlutterOverlayWindow.resizeOverlay(340, 620, false);
      } catch (_) {
        if (mounted)
          setState(() => _error = '오버레이 크기를 복원하지 못했습니다. 창을 다시 열어주세요.');
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_mySide == '구분하기 어려움') {
        final result = await widget.openRouterService.analyzeAnonymousConversation(
          base64Images: _images, contextNote: _contextNote.text.trim());
        if (mounted) setState(() => _anonymousResult = result);
        return;
      }
      final result = await widget.openRouterService.analyzeMoonchulFault(
          base64Images: _images,
          targetContact: widget.targetContact,
          mySide: _mySide,
          contextNote: _contextNote.text.trim());
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted)
        setState(() => _error =
            e is StateError ? '${e.message}' : '분석하지 못했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _section(String title, String body) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 6),
        SelectableText(body),
      ]));

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final anonymousResult = _anonymousResult;
    final content = Column(mainAxisSize: MainAxisSize.min, children: [
      if (!widget.isPage)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
          child: Row(children: [
            const Icon(Icons.balance, color: Colors.deepOrange),
            const SizedBox(width: 8),
            const Expanded(child: Text('문철 · 대화 분쟁 분석',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            IconButton(tooltip: '닫기', onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
          ]),
        ),
      if (!widget.isPage) const Divider(),
          Flexible(
              child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (result == null && anonymousResult == null) ...[
                    const Text('누가 어떤 말을 했는지 살펴보고, 갈등의 원인과 다음 답장을 함께 정리해요.'),
                    const SizedBox(height: 12),
                    const Text('1. 대화 사진 첨부 (최대 5장)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text('시간순으로 선택하고 아래 미리보기 순서를 확인해주세요.'),
                    OutlinedButton.icon(
                        onPressed: _loading ? null : _pickImages,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(_images.isEmpty ? '사진 선택' : '사진 다시 선택')),
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
                                child: Column(children: [
                                  Text('${i + 1}번'),
                                  Expanded(
                                      child: Image.memory(
                                          base64Decode(_images[i]),
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, error, stack) =>
                                              const Center(
                                                  child: Text('미리보기 불가')))),
                                  IconButton(
                                      tooltip: '사진 삭제',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: _loading
                                          ? null
                                          : () => setState(
                                              () => _images.removeAt(i)),
                                      icon: const Icon(
                                          Icons.remove_circle_outline,
                                          size: 18)),
                                ])),
                          )),
                    const SizedBox(height: 12),
                    const Text('2. 내 메시지 위치',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                        isExpanded: true,
                        value: _mySide,
                        items: ['오른쪽 말풍선', '왼쪽 말풍선', '구분하기 어려움']
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: _loading
                            ? null
                            : (v) => setState(() => _mySide = v!)),
                    if (_mySide == '구분하기 어려움')
                      const Text('인물 A, B 등으로 구분해 분석합니다. 이름이나 역할을 알고 있다면 아래 추가 상황에 적어주세요.',
                          style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _contextNote,
                        enabled: !_loading,
                        maxLength: 1500,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                            labelText: '3. 추가 상황 (선택)',
                            hintText: '다툰 이유, 이전 약속, 원하는 해결 방향을 알려주세요.',
                            border: OutlineInputBorder())),
                    Text(
                        _mySide == '구분하기 어려움'
                          ? '분석 시작 시 선택한 사진과 추가 상황을 OpenRouter로 전송합니다. 불필요한 개인정보는 가려주세요.'
                          : '분석 시작 시 선택한 사진과 추가 상황, 선택된 상대방의 이름·관계를 OpenRouter로 전송합니다. 불필요한 개인정보는 가려주세요.',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                        onPressed:
                            _loading || _images.isEmpty ? null : _analyze,
                        child:
                            Text(_loading ? '대화와 근거를 분석하고 있어요…' : '분쟁 분석 시작')),
                    if (_loading) const LinearProgressIndicator(),
                  ] else if (anonymousResult != null) ...[
                    _section(anonymousResult.canJudge ? '잠정 판단' : '판단 보류', anonymousResult.summary),
                    Text('판단 확신도: ${anonymousResult.confidence}',
                        style: const TextStyle(color: Colors.black54)),
                    if (anonymousResult.participants.isEmpty)
                      _section('대화 인물', '이미지에서 인물을 확실하게 구분하지 못했습니다.'),
                    for (final person in anonymousResult.participants)
                      Card(child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(person.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          SelectableText('식별 단서: ${person.identification}'),
                          const SizedBox(height: 6),
                          SelectableText(person.analysis),
                        ]),
                      )),
                    if (anonymousResult.evidence.isNotEmpty)
                      _section('대화에서 확인한 근거', anonymousResult.evidence.map((e) => '• $e').join('\n\n')),
                    if (anonymousResult.missingContext.isNotEmpty)
                      _section('더 확인할 내용', anonymousResult.missingContext.map((e) => '• $e').join('\n')),
                    _section('갈등 해결 방향', anonymousResult.reconciliationAdvice),
                    const SizedBox(height: 12),
                    const Text('식별과 판단은 보이는 대화를 바탕으로 한 AI의 잠정 의견입니다.',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                    OutlinedButton(onPressed: () => setState(() {
                      _anonymousResult = null;
                      _error = null;
                    }), child: const Text('사진·상황 수정 후 다시 분석')),
                  ] else if (result != null) ...[
                    _section(
                        result.canJudge ? '잠정 판단' : '판단 보류', result.summary),
                    Text('판단 확신도: ${result.confidence}',
                        style: const TextStyle(color: Colors.black54)),
                    if (result.canJudge) ...[
                      _section('소통 책임 추정',
                          '나 ${result.myRatio}%  :  상대방 ${result.otherRatio}%'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                          value: result.myRatio / 100,
                          minHeight: 12,
                          color: Colors.blue,
                          backgroundColor: Colors.deepOrange.shade200),
                    ],
                    _section(
                        '대화에서 확인한 근거',
                        result.evidence.isEmpty
                            ? '판단할 수 있는 발언이 부족합니다.'
                            : result.evidence.map((e) => '• $e').join('\n\n')),
                    _section('내 행동 분석', result.myFaultAnalysis),
                    _section('상대방 행동 분석', result.otherFaultAnalysis),
                    if (result.missingContext.isNotEmpty)
                      _section('더 확인할 내용',
                          result.missingContext.map((e) => '• $e').join('\n')),
                    _section('갈등 해결 순서', result.reconciliationAdvice),
                    const SizedBox(height: 16),
                    const Text('바로 보낼 수 있는 답장',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    for (var i = 0; i < result.recommendedReplies.length; i++)
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(['차분한 설명', '경계 설정', '합의 제안'][i],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    SelectableText(
                                        result.recommendedReplies[i]),
                                    TextButton.icon(
                                        onPressed: () async {
                                          await Clipboard.setData(ClipboardData(
                                              text: result
                                                  .recommendedReplies[i]));
                                          if (context.mounted)
                                            ScaffoldMessenger.maybeOf(context)
                                                ?.showSnackBar(const SnackBar(
                                                    content:
                                                        Text('답장을 복사했습니다.')));
                                        },
                                        icon: const Icon(Icons.copy, size: 16),
                                        label: const Text('답장 복사')),
                                  ]))),
                    const SizedBox(height: 12),
                    const Text(
                        '캡처에 보이는 내용만 바탕으로 한 AI의 잠정 의견이며, 법적 과실이나 사실 확정이 아닙니다.',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                    OutlinedButton(
                        onPressed: () => setState(() {
                              _result = null;
                              _error = null;
                            }),
                        child: const Text('사진·상황 수정 후 다시 분석')),
                  ],
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red))),
                ]),
          )),
    ]);
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
