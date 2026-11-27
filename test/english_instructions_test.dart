import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/widgets/reply_instructions_field.dart';

void main() {
  for (final isContext in [false, true]) {
    testWidgets('English input and paste validation: context=$isContext',
        (tester) async {
      var valid = true;
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ReplyInstructionsField(
        controller: controller,
        isContext: isContext,
        onValidityChanged: (v) => valid = v,
      ))));
      final field = find.byType(TextField);
      await tester.enterText(field, 'Friday, afternoon!');
      await tester.enterText(field, 'Friday 안녕');
      await tester.pump();
      expect(controller.text, 'Friday, afternoon!');
      expect(valid, isFalse);
      expect(find.text('Use English letters and common punctuation only.'),
          findsOneWidget);
      await tester.enterText(field, 'Thanks');
      await tester.pump();
      expect(valid, isTrue);
      expect(controller.text, 'Thanks');
    });
  }
}
