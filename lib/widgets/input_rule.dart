import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 입력란의 용도에 따라 허용 문자와 영문 오류 안내를 함께 관리합니다.
enum InputRule {
  words(r"""[^A-Za-z .,!"'?:;()‘’“”…—–\-\n\r]""", 'Use English letters and common punctuation only.'),
  account(r'[^\x20-\x7E]', 'Use English letters, numbers or ASCII symbols only.'),
  phone(r'[^0-9 +()\-]', 'Use digits and phone symbols only: + ( ) -'),
  age(r'[^0-9]', 'Use digits only.');

  const InputRule(this.pattern, this.message);
  final String pattern;
  final String message;

  /// 입력 또는 붙여넣기 전체를 거절해 일부만 저장되는 일을 방지합니다.
  TextInputFormatter formatter(ValueChanged<bool> reportInvalid) {
    final unsupported = RegExp(pattern);
    return TextInputFormatter.withFunction((oldValue, newValue) {
      final invalid = unsupported.hasMatch(newValue.text);
      reportInvalid(invalid);
      return invalid ? oldValue : newValue;
    });
  }

  List<TextInputFormatter> forField(BuildContext context) => [
    formatter((invalid) {
      if (!invalid) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }),
  ];
}
