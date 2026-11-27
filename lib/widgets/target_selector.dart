import 'package:flutter/material.dart';
import '../models/contact_model.dart';

/// 같은 이름을 가진 연락처도 ID로 구분해 실제 분석에 사용할 모델을 반환합니다.
class TargetSelector extends StatelessWidget {
  const TargetSelector(
      {super.key,
      required this.contacts,
      required this.selected,
      required this.onChanged,
      this.pageLayout = false});
  final bool pageLayout;
  final List<ContactModel> contacts;
  final ContactModel? selected;
  final ValueChanged<ContactModel>? onChanged;

  @override
  Widget build(BuildContext context) {
    final choices = {for (final contact in contacts) contact.id: contact};
    if (pageLayout) {
      // 페이지에서는 라벨과 선택값이 테두리 밖으로 나가지 않게 높이를 내용에 맞춥니다.
      return Padding(
        padding: const EdgeInsets.all(12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Analysis target'),
          const SizedBox(height: 6),
          OutlinedButton(
            onPressed: choices.isEmpty || onChanged == null
                ? null
                : () async {
                    final contact = await showDialog<ContactModel>(
                      context: context,
                      builder: (dialogContext) => SimpleDialog(
                        title: const Text('Select a contact'),
                        children: [
                          for (final contact in choices.values)
                            SimpleDialogOption(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, contact),
                              child: Text(
                                  '${contact.name} · ${contact.relationship}'),
                            )
                        ],
                      ),
                    );
                    if (context.mounted && contact != null) onChanged!(contact);
                  },
            child: Row(children: [
              Expanded(
                  child: Text(selected == null
                      ? (choices.isEmpty
                          ? 'Add a contact in Contacts.'
                          : 'Select a contact')
                      : '${selected!.name} · ${selected!.relationship}')),
              const Icon(Icons.arrow_drop_down),
            ]),
          ),
        ]),
      );
    }
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Analysis target'),
      child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
        isExpanded: true,
        value: choices.containsKey(selected?.id) ? selected?.id : null,
        hint: Text(choices.isEmpty
            ? 'Add a contact in Contacts.'
            : 'Select a contact'),
        items: [
          for (final entry in choices.entries)
            DropdownMenuItem(
                value: entry.key,
                child: Text('${entry.value.name} · ${entry.value.relationship}',
                    overflow: TextOverflow.ellipsis))
        ],
        onChanged: onChanged == null
            ? null
            : (id) {
                if (id != null) onChanged!(choices[id]!);
              },
      )),
    );
  }
}
