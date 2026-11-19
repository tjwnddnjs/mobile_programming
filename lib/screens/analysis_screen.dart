import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/contact_provider.dart';
import '../providers/auth_provider.dart';
import '../services/openrouter_service.dart';
import '../services/screen_capture_service.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _service = OpenRouterService();
  String? _image;
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
    } catch (_) {
      if (mounted) setState(() => _error = '사진을 가져오지 못했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _analyze() async {
    final target = context.read<ContactProvider>().activeTarget;
    if (target == null) {
      setState(() => _error = '홈 화면에서 대화 상대를 먼저 선택해주세요.');
      return;
    }
    if (_image == null) return;
    setState(() { _busy = true; _error = null; _replies = null; });
    try {
      final replies = await _service.getChatRecommendations(
        base64Screenshot: _image!, targetContact: target,
        user: context.read<AuthProvider>().currentUser,
      );
      if (mounted) setState(() => _replies = replies);
    } catch (error) {
      if (mounted) setState(() => _error = error is StateError ? error.message : '분석에 실패했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = context.watch<ContactProvider>().activeTarget;
    return Scaffold(
      appBar: AppBar(title: const Text('대화 분석 / 추천')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(target == null ? '선택된 대화 상대가 없습니다.' : '분석 대상: ${target.name} (${target.relationship})',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        const Text('대화 사진을 선택하면 상대방에 맞는 답장 3개를 추천합니다.'),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: _busy ? null : _selectImage,
              icon: const Icon(Icons.photo_library_outlined), label: const Text('사진 첨부')),
        ]),
        const SizedBox(height: 8),
        const Text('다른 앱 화면을 캡처하려면 해당 앱에서 오버레이를 사용해주세요.', style: TextStyle(fontSize: 12)),
        if (_image != null) ...[
          const SizedBox(height: 16),
          ConstrainedBox(constraints: const BoxConstraints(maxHeight: 300),
              child: Image.memory(base64Decode(_image!), fit: BoxFit.contain)),
          const SizedBox(height: 8),
          const Text('분석을 시작하면 사진과 선택한 상대방 정보, 내 프로필 정보가 OpenRouter로 전송됩니다.', style: TextStyle(fontSize: 12)),
        ],
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _busy || _image == null ? null : _analyze,
            icon: const Icon(Icons.auto_awesome), label: const Text('분석하고 답장 추천받기')),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red))),
        if (_replies != null) ...[
          const SizedBox(height: 20),
          Text('추천 답장', style: Theme.of(context).textTheme.titleLarge),
          for (final reply in _replies!)
            Card(child: ListTile(title: Text(reply), trailing: const Icon(Icons.copy),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: reply));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('답장을 복사했습니다.')));
                }
              })),
        ],
      ]),
    );
  }
}
