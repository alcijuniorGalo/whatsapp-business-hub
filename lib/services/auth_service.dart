import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda o token da Cloud API no armazenamento criptografado do Android
/// (EncryptedSharedPreferences por baixo dos panos).
///
/// O token é colado na tela de Configurações (ou obtido via OAuth) e nunca
/// vai hardcoded no código.
class AuthService {
  static const _tokenKey = 'wa_cloud_api_token';
  static const _expiryKey = 'wa_cloud_api_token_expiry';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token, {Duration ttl = const Duration(days: 60)}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(
      key: _expiryKey,
      value: DateTime.now().add(ttl).toIso8601String(),
    );
  }

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  /// Data de expiração estimada do token (null = desconhecida).
  Future<DateTime?> expiryDate() async {
    final expiry = await _storage.read(key: _expiryKey);
    if (expiry == null) return null;
    return DateTime.tryParse(expiry);
  }

  Future<bool> get hasValidToken async {
    final token = await _storage.read(key: _tokenKey);
    final expiry = await _storage.read(key: _expiryKey);
    if (token == null || token.isEmpty) return false;
    if (expiry == null) return true; // sem expiração conhecida: assume válido
    return DateTime.now().isBefore(DateTime.parse(expiry));
  }

  /// Troca um token de curta duração por um de longa duração (60 dias).
  /// Endpoint oficial: GET graph.facebook.com/oauth/access_token
  ///   ?grant_type=fb_exchange_token&client_id=...&client_secret=...&fb_exchange_token=...
  /// O client_secret NUNCA deve estar no app: faça essa troca no backend.
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiryKey);
  }
}
