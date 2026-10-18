import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/audit_service.dart';

/// Histórico de ações do operador (auditoria).
class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final events = AuditService.recent();
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de ações')),
      body: events.isEmpty
          ? const Center(child: Text('Nenhuma ação registrada ainda.'))
          : ListView.builder(
              itemCount: events.length,
              itemBuilder: (_, i) {
                final e = events[i];
                final at = DateTime.tryParse(e['at'] as String? ?? '');
                return ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(e['action'] as String? ?? ''),
                  subtitle: Text(e['details'] as String? ?? ''),
                  trailing: Text(
                    at == null ? '' : DateFormat('dd/MM HH:mm').format(at),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
    );
  }
}
