import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_business_hub/services/data_masking_service.dart';

void main() {
  test('mascara telefone mantendo os 4 últimos dígitos', () {
    final out = DataMaskingService.maskPhone('ligar para +55 11 98765-4321 ok');
    expect(out.contains('4321'), isTrue);
    expect(out.contains('98765'), isFalse);
  });

  test('mascara e-mail preservando domínio', () {
    final out = DataMaskingService.maskEmail('contato joao.silva@empresa.com.br');
    expect(out.contains('empresa.com.br'), isTrue);
    expect(out.contains('joao.silva@'), isFalse);
  });

  test('mascara CPF', () {
    final out = DataMaskingService.maskCpf('cpf 123.456.789-00 fim');
    expect(out.contains('123.456'), isFalse);
    expect(out.contains('•••.•••.•••-••'), isTrue);
  });

  test('maskAll aplica as três máscaras', () {
    final out = DataMaskingService.maskAll(
        'Maria +55 11 90000-0000 maria@x.com 111.222.333-44');
    expect(out.contains('90000'), isFalse);
    expect(out.contains('maria@'), isFalse);
    expect(out.contains('111.222'), isFalse);
  });
}
