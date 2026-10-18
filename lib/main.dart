import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'services/cache_service.dart';
import 'services/notification_service.dart';
import 'services/audit_service.dart';
import 'services/outbox_service.dart';
import 'services/memory_monitor.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/resilient_api_service.dart';
import 'features/dashboard/dashboard_screen.dart';

/// Handler de push em background: data-only → persiste no Hive.
/// (A automação roda no backend.)
@pragma('vm:entry-point')
Future<void> _firebaseBgHandler(RemoteMessage msg) async {
  await Hive.initFlutter();
  await CacheService.init();
  final data = msg.data;
  if (data['type'] == 'wa_inbound') {
    await CacheService.appendMessage({
      'id': data['wamid'],
      'phoneNumberId': data['phoneNumberId'],
      'chatId': data['chatId'],
      'contactName': data['contactName'] ?? data['chatId'],
      'direction': 'inbound',
      'type': data['msgType'] ?? 'text',
      'body': data['body'] ?? '',
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'received',
    });
    await NotificationService.notifyMessage(
      phoneNumberId: data['phoneNumberId'] ?? '',
      channelLabel: data['phoneNumberId'] ?? '',
      contactName: data['contactName'] ?? data['chatId'] ?? '',
      body: (data['body'] ?? '').toString(),
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await CacheService.init();
  await AuditService.init();
  await OutboxService.init();
  await NotificationService.init();
  MemoryMonitor().attach();

  // Reenvio do outbox quando a conectividade voltar.
  Connectivity().onConnectivityChanged.listen((results) async {
    if (results.any((r) => r != ConnectivityResult.none)) {
      final api = ResilientApiService(WhatsAppApiService(AuthService()));
      final n = await OutboxService.processAll(api);
      if (n > 0) {
        await AuditService.log('outbox.auto', '$n mensagens reenviadas (rede voltou)');
      }
    }
  });

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseBgHandler);
    await FirebaseMessaging.instance.requestPermission();
    FirebaseMessaging.onMessage.listen((msg) async {
      // Foreground: mesmo pipeline do background handler.
      await _firebaseBgHandler(msg);
    });
  } catch (_) {
    // Sem google-services.json o app roda sem push (modo local).
  }
  runApp(const ProviderScope(child: BusinessHubApp()));
}

class BusinessHubApp extends StatelessWidget {
  const BusinessHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatsApp Business Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF075E54),
      ),
      home: const DashboardScreen(),
    );
  }
}
