import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'audit_service.dart';

/// Monitora a expiração do token da Cloud API e tenta renovar via backend.
///
/// Limitação honesta: renovar um long-lived token exige o `client_secret`,
/// que **nunca** deve estar no app. A renovação automática real acontece no
/// webhook server (`POST /token/refresh`); aqui monitoramos, tentamos o
/// refresh via backend quando configurado e avisamos o operador caso contrário.
enum TokenHealth { ok, expiringSoon, expired, missing }

class TokenManager {
  final AuthService _auth;
  final String serverBase; // base do webhook server; '' = sem backend
  final http.Client _client;

  TokenManager(this._auth, {this.serverBase = '', http.Client? client})
      : _client = client ?? http.Client();

  Future<TokenHealth> check() async {
    final token = await _auth.readToken();
    if (token == null || token.isEmpty) return TokenHealth.missing;
    final expiry = await _auth.expiryDate();
    if (expiry == null) return TokenHealth.ok; // sem expiração conhecida
    final now = DateTime.now();
    if (now.isAfter(expiry)) return TokenHealth.expired;
    if (expiry.difference(now) < const Duration(days: 7)) {
      return TokenHealth.expiringSoon;
    }
    return TokenHealth.ok;
  }

  Future<int?> daysRemaining() async {
    final expiry = await _auth.expiryDate();
    if (expiry == null) return null;
    return expiry.difference(DateTime.now()).inDays;
  }

  /// Tenta renovar via backend. Retorna true se o token foi atualizado.
  /// O servidor precisa implementar `POST /token/refresh` com o client_secret.
  Future<bool> tryBackendRefresh() async {
    if (serverBase.isEmpty) return false;
    try {
      final res = await _client
          .post(Uri.parse('$serverBase/token/refresh'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return false;
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final newToken = decoded['access_token'] as String?;
      if (newToken == null || newToken.isEmpty) return false;
      final expiresIn = (decoded['expires_in'] as int?) ?? 5184000; // 60 dias
      await _auth.saveToken(newToken,
          ttl: Duration(seconds: expiresIn));
      await AuditService.log('token.refresh', 'Token renovado via backend');
      return true;
    } catch (_) {
      return false;
    }
  }
}
