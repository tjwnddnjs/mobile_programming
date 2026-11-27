import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_chat_ai/providers/auth_provider.dart';
import 'package:smart_chat_ai/screens/login_screen.dart';
import 'package:smart_chat_ai/widgets/reply_instructions_field.dart';
import 'package:smart_chat_ai/widgets/recommendation_dialog.dart';

void main() {
  testWidgets('login screen opens registration', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const MaterialApp(home: LoginScreen()),
    ));
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets(
      'the floating preview accepts instructions and clears them after closing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(340, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final image = await tester.runAsync(() async {
      final picture = ui.PictureRecorder();
      ui.Canvas(picture);
      final frame = picture.endRecording();
      final pixels = await frame.toImage(2, 2);
      final bytes = (await pixels.toByteData(format: ui.ImageByteFormat.png))!;
      pixels.dispose();
      frame.dispose();
      return base64Encode(bytes.buffer.asUint8List());
    });
    final submitted = <String?>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        onPressed: () async => submitted.add(await showReplyPreview(
          context,
          contacts: const [], initialTarget: null, onTargetChanged: (_) {},
          images: [image!, image],
          isCapture: false,
        )),
        child: const Text('Preview'),
      ),
    ))));

    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Please keep it brief.');
    await tester.tap(find.text('Analyze'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analyze'));
    await tester.pumpAndSettle();

    expect(submitted, ['Please keep it brief.', '']);
  });

  testWidgets(
      'copying a reply closes the Android overlay result without a Scaffold',
      (tester) async {
    String? clipboardText;
    final messenger = tester.binding.defaultBinaryMessenger;
    const channel = MethodChannel('com.smartchat.ai/overlay_clipboard');
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'copyReply') {
        clipboardText = call.arguments as String;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(MaterialApp(
        home: Material(
            child: Builder(
      builder: (context) => TextButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const RecommendationDialog(
            targetName: 'A',
            recommendations: ['Suggested response'],
            isSystemOverlay: true,
          ),
        ),
        child: const Text('Show result'),
      ),
    ))));
    await tester.tap(find.text('Show result'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suggested response'));
    await tester.pumpAndSettle();
    expect(clipboardText, 'Suggested response');
    expect(find.byType(RecommendationDialog), findsNothing);
  });
}
