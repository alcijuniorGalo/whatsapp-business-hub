import 'package:flutter/material.dart';

/// Parser mínimo de markdown para as bolhas: **negrito** e *itálico*.
///
/// Propositalmente simples (sem dependências): cobre o que operadores
/// realmente usam em respostas rápidas.
class SimpleMarkdown {
  static final _bold = RegExp(r'\*\*(.+?)\*\*');
  static final _italic = RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)');

  static TextSpan parse(String text, TextStyle base) {
    final spans = <TextSpan>[];
    var remaining = text;

    while (remaining.isNotEmpty) {
      final boldMatch = _bold.firstMatch(remaining);
      final italicMatch = _italic.firstMatch(remaining);

      // Escolhe a marcação que aparece primeiro.
      RegExpMatch? first;
      bool isBold = false;
      if (boldMatch != null &&
          (italicMatch == null || boldMatch.start < italicMatch.start)) {
        first = boldMatch;
        isBold = true;
      } else if (italicMatch != null) {
        first = italicMatch;
      }

      if (first == null) {
        spans.add(TextSpan(text: remaining, style: base));
        break;
      }
      if (first.start > 0) {
        spans.add(TextSpan(
            text: remaining.substring(0, first.start), style: base));
      }
      spans.add(TextSpan(
        text: first.group(1),
        style: base.copyWith(
          fontWeight: isBold ? FontWeight.bold : base.fontWeight,
          fontStyle: isBold ? base.fontStyle : FontStyle.italic,
        ),
      ));
      remaining = remaining.substring(first.end);
    }
    return TextSpan(children: spans, style: base);
  }
}
