import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notificações locais. O push real chega via FCM (o backend dispara);
/// aqui apenas exibimos de forma agrupada por número.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (_) {},
    );
    // Canal por número é criado sob demanda em [notifyMessage].
  }

  /// Exibe notificação de mensagem; canal separado por número (permite silenciar
  /// "Vendas" sem afetar "Suporte" nas configs do Android).
  static Future<void> notifyMessage({
    required String phoneNumberId,
    required String channelLabel,
    required String contactName,
    required String body,
    required int id,
  }) async {
    final channelId = 'wa_$phoneNumberId';
    final androidDetails = AndroidNotificationDetails(
      channelId,
      'WhatsApp - $channelLabel',
      channelDescription: 'Mensagens recebidas no número $channelLabel',
      importance: Importance.high,
      priority: Priority.high,
      groupKey: channelId,
    );
    await _plugin.show(
      id,
      contactName,
      body,
      NotificationDetails(android: androidDetails),
    );
  }
}
