import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:whatsapp_business_hub/services/auth_service.dart';
import 'package:whatsapp_business_hub/services/token_manager.dart';

class MockAuth extends Mock implements AuthService {}

void main() {
  test('sem token -> missing', () async {
    final auth = MockAuth();
    when(() => auth.readToken()).thenAnswer((_) async => null);
    final tm = TokenManager(auth);
    expect(await tm.check(), TokenHealth.missing);
  });

  test('token válido longe da expiração -> ok', () async {
    final auth = MockAuth();
    when(() => auth.readToken()).thenAnswer((_) async => 'tok');
    when(() => auth.expiryDate()).thenAnswer(
        (_) async => DateTime.now().add(const Duration(days: 30)));
    final tm = TokenManager(auth);
    expect(await tm.check(), TokenHealth.ok);
    expect(await tm.daysRemaining(), 30);
  });

  test('expira em < 7 dias -> expiringSoon', () async {
    final auth = MockAuth();
    when(() => auth.readToken()).thenAnswer((_) async => 'tok');
    when(() => auth.expiryDate()).thenAnswer(
        (_) async => DateTime.now().add(const Duration(days: 3)));
    final tm = TokenManager(auth);
    expect(await tm.check(), TokenHealth.expiringSoon);
  });

  test('expirado -> expired', () async {
    final auth = MockAuth();
    when(() => auth.readToken()).thenAnswer((_) async => 'tok');
    when(() => auth.expiryDate()).thenAnswer(
        (_) async => DateTime.now().subtract(const Duration(days: 1)));
    final tm = TokenManager(auth);
    expect(await tm.check(), TokenHealth.expired);
  });
}
