import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_chat_ai/models/contact_model.dart';
import 'package:smart_chat_ai/widgets/target_selector.dart';

void main() {
  testWidgets('Page selector wraps long text and selects another contact', (tester) async {
    final first = ContactModel(id: '1', name: 'Long contact name repeated twice', relationship: 'Very long relationship description');
    final next = ContactModel(id: '2', name: 'Jane', relationship: 'Friend');
    ContactModel? picked;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: SizedBox(
      width: 225, child: MediaQuery(data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
      child: TargetSelector(pageLayout: true, contacts: [first, next], selected: first,
        onChanged: (value) => picked = value)))))));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(OutlinedButton)).height, greaterThan(48));
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jane · Friend'));
    await tester.pumpAndSettle();
    expect(picked?.id, '2');
  });
}
