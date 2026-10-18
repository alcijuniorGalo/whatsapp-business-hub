import 'dart:async';
import 'dart:math';
import 'api_service.dart';

/// Envolve a Cloud API com resiliência:
/// - **Circuit Breaker:** após [failureThreshold] falhas consecutivas, o
///   circuito abre por [cooldown] e rejeita chamadas imediatamente (fail-fast),
///   evitando sobrecarregar a API da Meta.
/// - **Exponential Backoff + Jitter:** cada tentativa espera
///   `min(cap, base * 2^tentativa)` com jitter de ±50%.
class ResilientApiService {
  final WhatsAppApiService _inner;
  final int failureThreshold;
  final Duration cooldown;
  final Duration baseDelay;
  final Duration maxDelay;
  final int maxAttempts;
  final Random _random = Random();

  int _consecutiveFailures = 0;
  DateTime? _openedAt;

  ResilientApiService(
    this._inner, {
    this.failureThreshold = 5,
    this.cooldown = const Duration(seconds: 30),
    this.baseDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 16),
    this.maxAttempts = 4,
  });

  bool get circuitOpen {
    final opened = _openedAt;
    if (opened == null) return false;
    if (DateTime.now().difference(opened) >= cooldown) {
      _openedAt = null; // half-open: próxima chamada testa a água
      _consecutiveFailures = 0;
      return false;
    }
    return true;
  }

  Duration _delayFor(int attempt) {
    final exp = baseDelay * (1 << attempt);
    final capped = exp > maxDelay ? maxDelay : exp;
    final jitter = 0.5 + _random.nextDouble(); // 0.5x .. 1.5x
    return Duration(milliseconds: (capped.inMilliseconds * jitter).round());
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    if (circuitOpen) {
      throw StateError('Circuit breaker aberto: aguarde ${cooldown.inSeconds}s.');
    }
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final result = await call().timeout(const Duration(seconds: 20));
        _consecutiveFailures = 0;
        return result;
      } catch (e) {
        lastError = e;
        _consecutiveFailures++;
        if (_consecutiveFailures >= failureThreshold) {
          _openedAt = DateTime.now();
          break;
        }
        if (attempt < maxAttempts - 1) {
          await Future.delayed(_delayFor(attempt));
        }
      }
    }
    throw lastError ?? StateError('Falha desconhecida na Cloud API');
  }

  Future<String> sendText({
    required String phoneNumberId,
    required String to,
    required String body,
  }) =>
      _guard(() => _inner.sendText(
          phoneNumberId: phoneNumberId, to: to, body: body));

  Future<String> sendTemplate({
    required String phoneNumberId,
    required String to,
    required String templateName,
    String languageCode = 'pt_BR',
    List<String> bodyParams = const [],
  }) =>
      _guard(() => _inner.sendTemplate(
          phoneNumberId: phoneNumberId,
          to: to,
          templateName: templateName,
          languageCode: languageCode,
          bodyParams: bodyParams));
}
