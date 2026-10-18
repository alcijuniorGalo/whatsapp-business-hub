import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:whatsapp_business_hub/services/cache_service.dart';
import 'package:whatsapp_business_hub/services/state_sync_service.dart';
import 'package:whatsapp_business_hub/services/audit_service.dart';

class MockClient extends Mock implements http.Client {}

void main() {
  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('bhub_test');
    Hive.init(tmp.path);
    registerFallbackValue(Uri.parse('https://x.test'));
  });

  setUp(() async {
    await CacheService.init();
    await AuditService.init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  Map<String, dynamic> event(String wamid, String body) => {
        'ts': '2026-10-17T12:00:00.000Z',
        'kind': 'inbound',
        'wamid': wamid,
        'phoneNumberId': 'pid1',
        'chatId': '5511999999999',
        'contactName': 'Cliente',
        'msgType': 'text',
        'body': body,
        'at': '2026-10-17T12:00:00.000Z',
      };

  test('sync incorpora eventos novos de forma idempotente', () async {
    final client = MockClient();
    when(() => client.get(any())).thenAnswer((_) async => http.Response(
        jsonEncode({
          'events': [event('w1', 'oi'), event('w2', 'tudo bem?')]
        }),
        200));

    final sync =
        StateSyncService(serverBase: 'https://srv.test', client: client);
    final added1 = await sync.sync();
    expect(added1, 2);

    // Segunda sincronização com os mesmos eventos: nada novo (idempotente).
    final added2 = await sync.sync();
    expect(added2, 0);

    final thread = CacheService.thread('pid1', '5511999999999', limit: 50);
    expect(thread.length, 2);
  });

  test('sync falha com erro claro se o servidor cair', () async {
    final client = MockClient();
    when(() => client.get(any()))
        .thenAnswer((_) async => http.Response('erro', 500));
    final sync =
        StateSyncService(serverBase: 'https://srv.test', client: client);
    expect(() => sync.sync(), throwsA(isA<StateError>()));
  });
}
