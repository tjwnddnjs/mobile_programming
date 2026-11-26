import 'package:flutter/material.dart';

import '../ui/tiki_theme.dart';

import 'package:provider/provider.dart';

import '../providers/contact_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
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
      appBar: const TikiAppBar(title: 'Moonchul', accent: Tiki.coral),
      body: SafeArea(
        child: MoonchulDialog(
          isPage: true,
          targetContact: context.watch<ContactProvider>().activeTarget,
          openRouterService: _service,
          judgmentStyle:
              context.watch<AuthProvider>().currentUser?.judgmentStyle ??
              JudgmentStyle.balanced,
        ),
      ),
    );
  }
}
