import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/contact_provider.dart';
import '../services/openrouter_service.dart';
import '../widgets/moonchul_dialog.dart';

class MoonchulScreen extends StatefulWidget {
  const MoonchulScreen({super.key});

  @override
  State<MoonchulScreen> createState() => _MoonchulScreenState();
}

class _MoonchulScreenState extends State<MoonchulScreen> {
  final _service = OpenRouterService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('문철 · 대화 분쟁 분석')),
      body: SafeArea(child: MoonchulDialog(
        isPage: true,
        targetContact: context.watch<ContactProvider>().activeTarget,
        openRouterService: _service,
      )),
    );
  }
}
