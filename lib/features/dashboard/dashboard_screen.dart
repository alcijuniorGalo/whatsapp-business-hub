import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../state/providers.dart';
import '../../core/models/phone_number.dart';
import '../../core/models/message.dart';
import '../../services/cache_service.dart';
import '../../services/outbox_service.dart';
import '../inbox/inbox_screen.dart';
import '../automation/automation_screen.dart';
import '../settings/settings_screen.dart';
import '../audit/audit_screen.dart';
import '../onboarding/onboarding_screen.dart';

/// Dashboard: resumo operacional + gráfico de volume + grid de números.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numbers = ref.watch(phoneNumbersProvider);
    final inbox = ref.watch(inboxProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Automações',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AutomationScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Auditoria',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AuditScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: numbers.isEmpty
          ? _emptyState(context)
          : RefreshIndicator(
              onRefresh: () async => ref.read(inboxProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _SummaryCard(inbox: inbox, numbers: numbers),
                  const SizedBox(height: 12),
                  _VolumeChart(),
                  const SizedBox(height: 12),
                  Text('Números',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.92,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: numbers.length,
                    itemBuilder: (_, i) => _NumberCard(
                      number: numbers[i],
                      conversations: inbox
                          .where((c) => c.phoneNumberId == numbers[i].id)
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InboxScreen()),
        ),
        icon: const Icon(Icons.inbox),
        label: const Text('Inbox unificado'),
      ),
    );
  }

  Widget _emptyState(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hub_outlined, size: 72, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Nenhum número conectado',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Faça o onboarding guiado para conectar seus números da Cloud API.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OnboardingScreen()),
                ),
                child: const Text('Iniciar configuração'),
              ),
            ],
          ),
        ),
      );
}

/// Resumo: mensagens hoje, taxa de resposta, números ativos, pendentes.
class _SummaryCard extends StatelessWidget {
  final List<dynamic> inbox;
  final List<PhoneNumber> numbers;
  const _SummaryCard({required this.inbox, required this.numbers});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    var todayCount = 0, inbound = 0, replied = 0, unread = 0;
    final activeNumbers =
        numbers.where((n) => n.active).length;
    for (final c in inbox) {
      final convo = c as dynamic;
      unread += (convo.unreadCount as int);
      final msgs = CacheService.thread(
              convo.phoneNumberId as String, convo.chatId as String,
              limit: 500)
          .map((m) => ChatMessage.fromJson(m))
          .toList();
      for (final m in msgs) {
        if (m.timestamp.year == today.year &&
            m.timestamp.month == today.month &&
            m.timestamp.day == today.day) {
          todayCount++;
        }
        if (m.direction == MessageDirection.inbound) inbound++;
        if (m.direction == MessageDirection.outbound) replied++;
      }
    }
    final responseRate =
        inbound == 0 ? 0 : (replied / inbound * 100).clamp(0, 100).round();
    final pending = OutboxService.pendingCount();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumo operacional',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Metric(value: '$todayCount', label: 'msgs hoje'),
                _Metric(value: '$responseRate%', label: 'taxa resposta'),
                _Metric(
                    value: '$activeNumbers/${numbers.length}',
                    label: 'números ativos'),
                _Metric(
                    value: '$unread', label: 'não lidas',
                    highlight: unread > 0),
              ],
            ),
            if (pending > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text('$pending mensagem(ns) no outbox (serão reenviadas)',
                        style: const TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  final bool highlight;
  const _Metric(
      {required this.value, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: highlight ? Colors.red : null)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Volume de mensagens por dia (últimos 30 dias).
class _VolumeChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final perDay = CacheService.messagesPerDay(30);
    final keys = perDay.keys.toList()..sort();
    final maxY =
        (perDay.values.fold<int>(0, (a, b) => a > b ? a : b)).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Volume — 30 dias',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  maxY: (maxY + 1).clamp(1, double.infinity),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: [
                    for (var i = 0; i < keys.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: perDay[keys[i]]!.toDouble(),
                            color:
                                Theme.of(context).colorScheme.primary,
                            width: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberCard extends ConsumerWidget {
  final PhoneNumber number;
  final List<dynamic> conversations;
  const _NumberCard({required this.number, required this.conversations});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var unread = 0;
    for (final c in conversations) {
      unread += (c as dynamic).unreadCount as int;
    }
    final last = conversations.isEmpty
        ? null
        : (conversations.first as dynamic).lastMessage as ChatMessage;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ref.read(inboxFilterProvider.notifier).state = number.id;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InboxScreen()),
          );
        },
        onLongPress: () => _actions(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: number.active
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    child: Text(
                      number.label.isNotEmpty
                          ? number.label[0].toUpperCase()
                          : '#',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(number.label,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                        Text(number.displayNumber,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: number.active ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (unread > 0)
                Chip(
                  label: Text('$unread não lidas'),
                  visualDensity: VisualDensity.compact,
                ),
              const SizedBox(height: 4),
              Text(
                last?.body ?? 'Sem mensagens ainda',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${conversations.length} conversas',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _actions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(number.active ? Icons.pause : Icons.play_arrow),
              title: Text(number.active ? 'Desativar' : 'Ativar'),
              onTap: () {
                ref.read(phoneNumbersProvider.notifier).toggle(number.id);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remover número',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                ref.read(phoneNumbersProvider.notifier).remove(number.id);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
