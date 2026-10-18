import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:whatsapp_business_hub/services/api_service.dart';
import 'package:whatsapp_business_hub/services/auth_service.dart';
import 'package:whatsapp_business_hub/services/resilient_api_service.dart';

class MockClient extends Mock implements http.Client {}

class FakeAuth extends AuthService {
  @override
  Future<String?> readToken() async => 'test-token';
}

http.Response ok(String wamid) => http.Response(
      jsonEncode({
        'messaging_product': 'whatsapp',
        'messages': [
          {'id': wamid}
        ]
      }),
      200,
    );

http.Response err() => http.Response(
      jsonEncode({
        'error': {'message': 'timeout', 'code': 500}
      }),
      500,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://x.test'));
  });

  group('ResilientApiService', () {
    test('reenvia com backoff e entrega após falhas transitórias', () async {
      final client = MockClient();
      var calls = 0;
      when(() => client.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async {
        calls++;
        return calls < 3 ? err() : ok('wamid_123');
      });

      final api = ResilientApiService(
        WhatsAppApiService(FakeAuth(), client),
        baseDelay: const Duration(milliseconds: 1),
        maxDelay: const Duration(milliseconds: 5),
      );
      final wamid = await api.sendText(
          phoneNumberId: 'pid', to: '5511999999999', body: 'oi');
      expect(wamid, 'wamid_123');
      expect(calls, 3);
    });

    test('circuit breaker abre após falhas consecutivas', () async {
      final client = MockClient();
      when(() => client.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => err());

      final api = ResilientApiService(
        WhatsAppApiService(FakeAuth(), client),
        failureThreshold: 2,
        maxAttempts: 1,
        cooldown: const Duration(seconds: 30),
        baseDelay: const Duration(milliseconds: 1),
      );

      // 2 falhas -> circuito abre
      await expectLater(
          api.sendText(phoneNumberId: 'p', to: 't', body: 'b'),
          throwsA(isA<StateError>()));
      await expectLater(
          api.sendText(phoneNumberId: 'p', to: 't', body: 'b'),
          throwsA(isA<StateError>()));
      expect(api.circuitOpen, isTrue);

      // Com circuito aberto, nem tenta a rede (fail-fast).
      verify(() => client.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .called(2);
      await expectLater(
          api.sendText(phoneNumberId: 'p', to: 't', body: 'b'),
          throwsA(predicate((e) =>
              e is StateError &&
              e.message.contains('Circuit breaker'))));
    });
  });
}
