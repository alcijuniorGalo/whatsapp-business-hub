import 'package:hive_flutter/hive_flutter.dart';

/// Trilha de auditoria: registra ações do operador (envios, regras, tokens).
/// Tela de leitura em `features/audit/audit_screen.dart`.
class AuditService {
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox('audit_log');
  }

  static Future<void> log(String action, String details) async {
    await _box.add({
      'at': DateTime.now().toIso8601String(),
      'action': action,
      'details': details,
    });
    // Poda: mantém os últimos 2000 eventos.
    while (_box.length > 2000) {
      await _box.deleteAt(0);
    }
  }

  static List<Map<String, dynamic>> recent({int limit = 200}) {
    final all = _box.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList()
      ..sort((a, b) =>
          (b['at'] as String).compareTo(a['at'] as String));
    return all.take(limit).toList();
  }
}
