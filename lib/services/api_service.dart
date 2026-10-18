import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'auth_service.dart';

/// Cliente da WhatsApp Business Cloud API (oficial Meta).
///
/// Base: https://graph.facebook.com/v21.0/{phone-number-id}/messages
class WhatsAppApiService {
  final AuthService _auth;
  final http.Client _client;

  /// [client] injetável para testes (mocktail).
  WhatsAppApiService(this._auth, [http.Client? client])
      : _client = client ?? http.Client();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.readToken();
    if (token == null || token.isEmpty) {
      throw StateError('Token da Cloud API não configurado. Abra Configurações.');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> _post(String phoneNumberId, Map<String, dynamic> payload) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/$phoneNumberId/messages');
    final res = await _client.post(uri, headers: await _headers(), body: jsonEncode(payload));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      final err = (decoded['error'] as Map?)?['message'] ?? 'HTTP ${res.statusCode}';
      throw StateError('Cloud API: $err');
    }
    return decoded; // contém messages: [{id: wamid}]
  }

  Map<String, dynamic> _base(String to) => {        'messaging_product': 'whatsapp',
        'recipient_type': 'individual',
        'to': to,
      };

  /// Texto simples (dentro da janela de 24h do cliente).
  Future<String> sendText({
    required String phoneNumberId,
    required String to,
    required String body,
    bool previewUrl = false,
  }) async {
    final payload = {
      ..._base(to),
      'type': 'text',
      'text': {'body': body, 'preview_url': previewUrl},
    };
    final res = await _post(phoneNumberId, payload);
    return (res['messages'] as List).first['id'] as String;
  }

  /// Template aprovado (obrigatório fora da janela de 24h / primeiro contato).
  Future<String> sendTemplate({
    required String phoneNumberId,
    required String to,
    required String templateName,
    String languageCode = 'pt_BR',
    List<String> bodyParams = const [],
  }) async {
    final payload = {
      ..._base(to),
      'type': 'template',
      'template': {
        'name': templateName,
        'language': {'code': languageCode},
        if (bodyParams.isNotEmpty)
          'components': [
            {
              'type': 'body',
              'parameters': [for (final p in bodyParams) {'type': 'text', 'text': p}],
            }
          ],
      },
    };
    final res = await _post(phoneNumberId, payload);
    return (res['messages'] as List).first['id'] as String;
  }

  /// Botões interativos (até 3).
  Future<String> sendButtons({
    required String phoneNumberId,
    required String to,
    required String bodyText,
    required List<String> buttons, // máx 3, máx 20 chars cada
  }) async {
    assert(buttons.length <= 3, 'Cloud API permite no máximo 3 botões');
    final payload = {
      ..._base(to),
      'type': 'interactive',
      'interactive': {
        'type': 'button',
        'body': {'text': bodyText},
        'action': {
          'buttons': [
            for (var i = 0; i < buttons.length; i++)
              {
                'type': 'reply',
                'reply': {'id': 'btn_$i', 'title': buttons[i]},
              }
          ],
        },
      },
    };
    final res = await _post(phoneNumberId, payload);
    return (res['messages'] as List).first['id'] as String;
  }

  /// Mídia por URL pública (o upload via /media é alternativa para arquivos locais).
  Future<String> sendMedia({
    required String phoneNumberId,
    required String to,
    required String mediaType, // image | document | audio | video
    required String link,
    String? caption,
  }) async {
    final payload = {
      ..._base(to),
      'type': mediaType,
      mediaType: {
        'link': link,
        if (caption != null) 'caption': caption,
      },
    };
    final res = await _post(phoneNumberId, payload);
    return (res['messages'] as List).first['id'] as String;
  }

  /// Valida um token (usado no onboarding): GET /me com o token candidato.
  /// Retorna o nome do app/business em caso de sucesso.
  static Future<String> validateToken(String candidate) async {
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}/me?fields=id,name&access_token=${Uri.encodeComponent(candidate)}');
    final res = await http.get(uri);
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      final err = (decoded['error'] as Map?)?['message'] ?? 'token inválido';
      throw StateError('Token inválido: $err');
    }
    return decoded['name'] as String? ?? 'token válido';
  }
}
