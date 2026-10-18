import 'dart:convert';
import 'package:http/http.dart' as http;
import 'cache_service.dart';
import 'audit_service.dart';

/// Reconciliação de estado: funde o Hive local com o log de eventos do
/// webhook server (`GET /events/since`), de forma idempotente por `wamid`.
///
/// Por que não a Meta? A Cloud API **não expõe endpoint de histórico** — o
/// servidor de webhooks é a fonte de verdade para eventos que o FCM perdeu
/// (ex: app fechado, push descartado).
class StateSyncService {
  final String serverBase; // ex: https://seu-servidor.com
  final http.Client _client;

  StateSyncService({required this.serverBase, http.Client? client})
      : _client = client ?? http.Client();

  /// Retorna quantas mensagens novas foram incorporadas.
  Future<int> sync() async {
    final since = CacheService.getMeta<String>('last_event_ts');
    final uri = Uri.parse('$serverBase/events/since').replace(
      queryParameters: {if (since != null) 'since': since},
    );
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw StateError('Sync falhou: HTTP ${res.statusCode}');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final events = (decoded['events'] as List).cast<Map<String, dynamic>>();
    var added = 0;
    var maxTs = since;
    for (final e in events) {
      final msg = _eventToMessage(e);
      if (msg == null) continue;
      final before = CacheService.thread(
              msg['phoneNumberId'] as String, msg['chatId'] as String,
              limit: 500)
          .length;
      await CacheService.appendMessage(msg);
      final after = CacheService.thread(
              msg['phoneNumberId'] as String, msg['chatId'] as String,
              limit: 500)
          .length;
      if (after > before) added++;
      final ts = e['ts'] as String?;
      if (ts != null && (maxTs == null || ts.compareTo(maxTs) > 0)) {
        maxTs = ts;
      }
    }
    if (maxTs != null) await CacheService.putMeta('last_event_ts', maxTs);
    await AuditService.log('sync', '$added mensagens reconciliadas do servidor');
    return added;
  }

  Map<String, dynamic>? _eventToMessage(Map<String, dynamic> e) {
    if (e['kind'] != 'inbound') return null;
    return {
      'id': e['wamid'],
      'phoneNumberId': e['phoneNumberId'],
      'chatId': e['chatId'],
      'contactName': e['contactName'] ?? e['chatId'],
      'direction': 'inbound',
      'type': e['msgType'] ?? 'text',
      'body': e['body'] ?? '',
      'timestamp': e['at'] ?? DateTime.now().toIso8601String(),
      'status': 'received',
    };
  }
}
