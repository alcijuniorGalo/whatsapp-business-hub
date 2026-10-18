import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../state/providers.dart';
import '../../core/models/automation_rule.dart';

/// Editor de fluxos de resposta. As regras são sincronizadas com o backend,
/// que as executa (resposta < 2s mesmo com o app em background).
class AutomationScreen extends ConsumerWidget {
  const AutomationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(automationProvider);
    final numbers = ref.watch(phoneNumbersProvider);

    String scopeLabel(AutomationRule r) {
      if (r.phoneNumberId == null) return 'Todos os números';
      return numbers
              .where((n) => n.id == r.phoneNumberId)
              .map((n) => n.label)
              .firstOrNull ??
          'Número removido';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Automações')),
      body: rules.isEmpty
          ? const Center(
              child: Text('Nenhuma regra.\nToque em + para criar a primeira.'))
          : ListView.builder(
              itemCount: rules.length,
              itemBuilder: (_, i) {
                final r = rules[i];
                return SwitchListTile(
                  title: Text('Se contém "${r.keyword}"'),
                  subtitle: Text('${r.replyTemplate}\n${scopeLabel(r)}'),
                  isThreeLine: true,
                  value: r.enabled,
                  onChanged: (v) => ref
                      .read(automationProvider.notifier)
                      .upsert(AutomationRule(
                        id: r.id,
                        keyword: r.keyword,
                        replyTemplate: r.replyTemplate,
                        enabled: v,
                        phoneNumberId: r.phoneNumberId,
                      )),
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        ref.read(automationProvider.notifier).remove(r.id),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editRule(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _editRule(BuildContext context, WidgetRef ref, AutomationRule? existing) {
    final keyword = TextEditingController(text: existing?.keyword ?? '');
    final reply = TextEditingController(text: existing?.replyTemplate ?? '');
    String? scope = existing?.phoneNumberId;
    final numbers = ref.read(phoneNumbersProvider);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Nova regra' : 'Editar regra'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyword,
                  decoration: const InputDecoration(
                    labelText: 'Palavra-chave (ex: preço)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reply,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Resposta (use {{nome}})',
                    hintText: 'Olá {{nome}}! Segue nossa tabela...',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: scope,
                  decoration: const InputDecoration(labelText: 'Aplicar em'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Todos os números')),
                    for (final n in numbers)
                      DropdownMenuItem(value: n.id, child: Text(n.label)),
                  ],
                  onChanged: (v) => setState(() => scope = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (keyword.text.trim().isEmpty ||
                    reply.text.trim().isEmpty) {
                  return;
                }
                final notifier = ref.read(automationProvider.notifier);
                notifier.upsert(AutomationRule(
                  id: existing?.id ?? notifier.newId(),
                  keyword: keyword.text.trim(),
                  replyTemplate: reply.text.trim(),
                  enabled: existing?.enabled ?? true,
                  phoneNumberId: scope,
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
