import 'package:hive_flutter/hive_flutter.dart';

/// Cache local (Hive): mensagens, números e regras.
///
/// Sem codegen: guardamos Maps JSON puros nas boxes. O inbox inteiro é
/// derivado daqui — a Cloud API não tem endpoint de histórico.
class CacheService {
  static late Box _messages; // key: "$phoneNumberId::$chatId" -> List<Map>
  static late Box _meta; // números, regras, configs

  static Future<void> init() async {
    _messages = await Hive.openBox('messages');
    _meta = await Hive.openBox('meta');
  }

  // --- mensagens ---
  static String _threadKey(String phoneNumberId, String chatId) => '$phoneNumberId::$chatId';

  static Future<void> appendMessage(Map<String, dynamic> json) async {
    final key = _threadKey(json['phoneNumberId'] as String, json['chatId'] as String);
    final list = List<Map>.from(_messages.get(key, defaultValue: <Map>[]) as List);
    // idempotência pelo wamid
    if (list.any((m) => m['id'] == json['id'])) return;
    list.add(json);
    // poda: mantém as últimas 500 por thread (lazy loading do restante via API não existe;
    // o histórico profundo vive no backend, se você o persistir lá)
    while (list.length > 500) {
      list.removeAt(0);
    }
    await _messages.put(key, list);
  }

  static List<Map<String, dynamic>> thread(String phoneNumberId, String chatId,
      {int limit = 50}) {
    final key = _threadKey(phoneNumberId, chatId);
    final list = List<Map>.from(_messages.get(key, defaultValue: <Map>[]) as List);
    final tail = list.length > limit ? list.sublist(list.length - limit) : list;
    return tail.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  static List<String> threadKeys() =>
      _messages.keys.map((k) => k.toString()).toList();

  /// Volume de mensagens por dia (últimos [days] dias) para o gráfico.
  static Map<String, int> messagesPerDay(int days) {
    final counts = <String, int>{};
    final now = DateTime.now();
    for (var i = 0; i < days; i++) {
      final d = now.subtract(Duration(days: i));
      counts['${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'] = 0;
    }
    for (final key in _messages.keys) {
      final list = _messages.get(key) as List;
      for (final raw in list) {
        final m = Map<String, dynamic>.from(raw as Map);
        final ts = DateTime.tryParse(m['timestamp'] as String? ?? '');
        if (ts == null) continue;
        final dayKey =
            '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
        if (counts.containsKey(dayKey)) {
          counts[dayKey] = counts[dayKey]! + 1;
        }
      }
    }
    return counts;
  }

  static Future<void> markRead(String phoneNumberId, String chatId) async {
    final key = _threadKey(phoneNumberId, chatId);
    final list = List<Map>.from(_messages.get(key, defaultValue: <Map>[]) as List);
    for (final m in list) {
      if (m['direction'] == 'inbound') m['status'] = 'read';
    }
    await _messages.put(key, list);
  }

  // --- meta (números, regras) ---
  static Future<void> putMeta(String key, dynamic value) => _meta.put(key, value);
  static T? getMeta<T>(String key) => _meta.get(key) as T?;
}
