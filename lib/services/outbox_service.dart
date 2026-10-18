import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'resilient_api_service.dart';
import 'audit_service.dart';

/// Outbox pattern: mensagens que falharam no envio ficam em `pending_messages`
/// com status PENDING e são reenviadas automaticamente (conectividade
/// restabelecida, app retomado, ou toque no ícone de reenviar).
class OutboxService {
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox('pending_messages');
  }

  static Future<String> enqueue({
    required String phoneNumberId,
    required String to,
    required String contactName,
    required String body,
  }) async {
    final localId = const Uuid().v4();
    await _box.put(localId, {
      'localId': localId,
      'phoneNumberId': phoneNumberId,
      'to': to,
      'contactName': contactName,
      'body': body,
      'attempts': 0,
      'status': 'PENDING',
      'createdAt': DateTime.now().toIso8601String(),
    });
    await AuditService.log('outbox.enqueue', 'Mensagem enfileirada para $to');
    return localId;
  }

  static List<Map<String, dynamic>> pending() => _box.values
      .map((e) => Map<String, dynamic>.from(e as Map))
      .where((m) => m['status'] == 'PENDING')
      .toList();

  static int pendingCount() => pending().length;

  /// Tenta reenviar tudo. Retorna quantas foram entregues.
  static Future<int> processAll(ResilientApiService api) async {
    var delivered = 0;
    for (final m in pending()) {
      try {
        await api.sendText(
          phoneNumberId: m['phoneNumberId'] as String,
          to: m['to'] as String,
          body: m['body'] as String,
        );
        await _box.delete(m['localId']);
        delivered++;
        await AuditService.log(
            'outbox.delivered', 'Mensagem entregue para ${m['to']}');
      } catch (_) {
        final attempts = (m['attempts'] as int) + 1;
        m['attempts'] = attempts;
        // Desiste após 10 tentativas: vira FAILED e o operador reenvia manual.
        m['status'] = attempts >= 10 ? 'FAILED' : 'PENDING';
        await _box.put(m['localId'], m);
      }
    }
    return delivered;
  }

  static Future<void> retryNow(String localId) async {
    final m = _box.get(localId);
    if (m == null) return;
    final map = Map<String, dynamic>.from(m as Map);
    map['status'] = 'PENDING';
    map['attempts'] = 0;
    await _box.put(localId, map);
  }

  static Future<void> discard(String localId) async => _box.delete(localId);
}
