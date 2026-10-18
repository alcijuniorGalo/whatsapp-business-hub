import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_business_hub/core/markdown.dart';

void main() {
  const base = TextStyle(fontSize: 14);

  test('negrito simples', () {
    final span = SimpleMarkdown.parse('olá **mundo**!', base);
    expect(span.children!.length, 3);
    expect((span.children![0] as TextSpan).text, 'olá ');
    final bold = span.children![1] as TextSpan;
    expect(bold.text, 'mundo');
    expect(bold.style!.fontWeight, FontWeight.bold);
    expect((span.children![2] as TextSpan).text, '!');
  });

  test('itálico simples', () {
    final span = SimpleMarkdown.parse('*atenção* aqui', base);
    final italic = span.children![0] as TextSpan;
    expect(italic.text, 'atenção');
    expect(italic.style!.fontStyle, FontStyle.italic);
  });

  test('texto sem marcação passa intacto', () {
    final span = SimpleMarkdown.parse('texto puro', base);
    expect(span.children!.length, 1);
    expect((span.children![0] as TextSpan).text, 'texto puro');
  });

  test('negrito tem prioridade sobre itálico aninhado', () {
    final span = SimpleMarkdown.parse('a **b** c *d*', base);
    final texts =
        span.children!.map((s) => (s as TextSpan).text).toList();
    expect(texts, ['a ', 'b', ' c ', 'd']);
  });
}
