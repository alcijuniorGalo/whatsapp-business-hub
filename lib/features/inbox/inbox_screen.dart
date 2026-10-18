import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import '../../state/providers.dart';
import '../../core/models/conversation.dart';
import '../../core/models/message.dart';
import 'conversation_screen.dart';

/// Inbox unificado: busca global + filtros avançados + SliverList.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numbers = ref.watch(phoneNumbersProvider);
    final numberFilter = ref.watch(inboxFilterProvider);
    final mode = ref.watch(inboxFilterModeProvider);
    final query = ref.watch(inboxSearchProvider).toLowerCase();
    final all = ref.watch(inboxProvider);
    final statuses = ref.watch(threadStatusProvider);

    bool matches(Conversation c) {
      if (numberFilter != null && c.phoneNumberId != numberFilter) return false;
      final st = statuses['thread_status::${c.phoneNumberId}::${c.chatId}'] ??
          ThreadStatus.open;
      switch (mode) {
        case InboxFilter.unread:
          if (c.unreadCount == 0) return false;
        case InboxFilter.pendingReply:
          // inbound não lida ou última mensagem é inbound
          if (!(c.unreadCount > 0 ||
              c.lastMessage.direction == MessageDirection.inbound)) {
            return false;
          }
        case InboxFilter.awaitingClient:
          if (st != ThreadStatus.awaiting) return false;
        case InboxFilter.resolved:
          if (st != ThreadStatus.resolved) return false;
        case InboxFilter.all:
          break;
      }
      if (query.isNotEmpty) {
        final hay =
            '${c.contactName} ${c.chatId} ${c.lastMessage.body}'.toLowerCase();
        if (!hay.contains(query)) return false;
      }
      return true;
    }

    final convos = all.where(matches).toList();
    String labelOf(String id) =>
        numbers.firstWhereOrNull((n) => n.id == id)?.label ?? id;

    return Scaffold(
      appBar: AppBar(title: const Text('Inbox unificado')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: SearchBar(
                hintText: 'Buscar por texto, contato ou número...',
                leading: const Icon(Icons.search),
                onChanged: (v) =>
                    ref.read(inboxSearchProvider.notifier).state = v,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final m in InboxFilter.values)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: FilterChip(
                        label: Text(_modeLabel(m)),
                        selected: mode == m,
                        onSelected: (_) => ref
                            .read(inboxFilterModeProvider.notifier)
                            .state = m,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _NumberChip(
                    label: 'Todos os números',
                    selected: numberFilter == null,
                    onTap: () =>
                        ref.read(inboxFilterProvider.notifier).state = null,
                  ),
                  for (final n in numbers)
                    _NumberChip(
                      label: n.label,
                      selected: numberFilter == n.id,
                      onTap: () =>
                          ref.read(inboxFilterProvider.notifier).state = n.id,
                    ),
                ],
              ),
            ),
          ),
          convos.isEmpty
              ? const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                      child: Text(
                          'Nada por aqui.\nAjuste os filtros ou aguarde o webhook.')),
                )
              : SliverList.builder(
                  itemCount: convos.length,
                  itemBuilder: (_, i) => _ConversationTile(
                    convo: convos[i],
                    numberLabel: labelOf(convos[i].phoneNumberId),
                  ),
                ),
        ],
      ),
    );
  }

  String _modeLabel(InboxFilter m) => switch (m) {
        InboxFilter.all => 'Todas',
        InboxFilter.unread => 'Não lidas',
        InboxFilter.pendingReply => 'Pendente resposta',
        InboxFilter.awaitingClient => 'Aguardando cliente',
        InboxFilter.resolved => 'Resolvidas',
      };
}

class _NumberChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NumberChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final Conversation convo;
  final String numberLabel;
  const _ConversationTile({required this.convo, required this.numberLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = convo.lastMessage;
    final time = DateFormat.Hm().format(last.timestamp);
    final status = ref
        .watch(threadStatusProvider.notifier)
        .of(convo.phoneNumberId, convo.chatId);
    return Dismissible(
      key: ValueKey('${convo.phoneNumberId}::${convo.chatId}'),
      background: Container(
        color: Colors.green.shade100,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: const Text('Resolvida'),
      ),
      secondaryBackground: Container(
        color: Colors.orange.shade100,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Text('Aguardando cliente'),
      ),
      confirmDismiss: (dir) async {
        final s = dir == DismissDirection.startToEnd
            ? ThreadStatus.resolved
            : ThreadStatus.awaiting;
        await ref
            .read(threadStatusProvider.notifier)
            .set(convo.phoneNumberId, convo.chatId, s);
        return false; // não remove da lista, só muda o status
      },
      child: ListTile(
        leading: CircleAvatar(
            child: Text(convo.contactName.isNotEmpty
                ? convo.contactName[0].toUpperCase()
                : '?')),
        title: Row(
          children: [
            Expanded(
              child: Text(convo.contactName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (status != ThreadStatus.open)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  status == ThreadStatus.resolved
                      ? Icons.check_circle
                      : Icons.hourglass_empty,
                  size: 14,
                  color: Colors.grey,
                ),
              ),
            Text(time, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(numberLabel,
                  style: Theme.of(context).textTheme.labelSmall),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(last.body,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        trailing: convo.unreadCount > 0
            ? CircleAvatar(
                radius: 11,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text('${convo.unreadCount}',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.white)),
              )
            : null,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationScreen(conversation: convo),
          ),
        ),
      ),
    );
  }
}
