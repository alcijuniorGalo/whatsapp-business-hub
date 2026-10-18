import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:whatsapp_business_hub/services/cache_service.dart';
import 'package:whatsapp_business_hub/services/audit_service.dart';
import 'package:whatsapp_business_hub/services/outbox_service.dart';
import 'package:whatsapp_business_hub/features/dashboard/dashboard_screen.dart';

void main() {
  setUpAll(() async {
    final tmp = await Directory.systemTemp.createTemp('bhub_widget');
    Hive.init(tmp.path);
    await CacheService.init();
    await AuditService.init();
    await OutboxService.init();
  });

  tearDownAll(() async => Hive.close());

  testWidgets('dashboard vazio sugere o onboarding', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhum número conectado'), findsOneWidget);
    expect(find.text('Iniciar configuração'), findsOneWidget);
  });

  testWidgets('toque em Iniciar configuração abre o onboarding', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciar configuração'));
    await tester.pumpAndSettle();

    expect(find.text('Configuração inicial'), findsOneWidget);
    expect(find.text('1. Conexão Meta'), findsOneWidget);
  });
}
