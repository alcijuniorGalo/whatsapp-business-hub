import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/message.dart';
import '../../core/models/conversation.dart';
import '../../core/config.dart';
import '../../core/markdown.dart';
import '../../state/providers.dart';
import '../../services/cache_service.dart';
import '../../services/outbox_service.dart';
import '../../services/audit_service.dart';

/// Conversa nativa: markdown, atalhos `/`, menu de contexto, reenvio, export.
class ConversationScreen extends ConsumerStatefulWidget {
  final Conversation conversation;
  const ConversationScreen({super.key, required this.conversation});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  String get _pid => widget.conversation.phoneNumberId;
  String get _chatId => widget.conversation.chatId;

  List<ChatMessage> _messages() => CacheService.thread(
          _pid, _chatId, limit: ApiConfig.historyPageSize)
      .map(ChatMessage.fromJson)
      .toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await CacheService.markRead(_pid, _chatId);
      ref.read(inboxProvider.notifier).refresh();
      // Tenta reenviar pendentes ao abrir o chat.
      await OutboxService.processAll(ref.read(resilientApiProvider));
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Resolve atalhos `/` e variáveis antes do envio.
  String _expand(String raw) {
    var text = raw;
    final shortcuts = ref.read(composerShortcutsProvider);
    for (final e in shortcuts.entries) {
      if (text.startsWith(e.key)) {
        text = text.replaceFirst(e.key, e.value);
        break;
      }
    }
    return text
        .replaceAll('{{nome}}', widget.conversation.contactName)
        .replaceAll('{{numero}}', _chatId);
  }

  Future<void> _send() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty || _sending) return;
    final text = _expand(raw);
    setState(() => _sending = true);
    try {
      final api = ref.read(resilientApiProvider);
      final wamid = await api.sendText(
          phoneNumberId: _pid, to: _chatId, body: text);
      await CacheService.appendMessage(ChatMessage(
        id: wamid,
        phoneNumberId: _pid,
        chatId: _chatId,
        contactName: widget.conversation.contactName,
        direction: MessageDirection.outbound,
        type: 'text',
        body: text,
        timestamp: DateTime.now(),
        status: 'sent',
      ).toJson());
      await ref
          .read(threadStatusProvider.notifier)
          .set(_pid, _chatId, ThreadStatus.awaiting);
      await AuditService.log('message.send', 'Para $_chatId (${text.length} chars)');
      _controller.clear();
      ref.read(inboxProvider.notifier).refresh();
      setState(() {});
      _scrollToBottom();
    } catch (e) {
      // Falha mesmo com retry: vai para o outbox (ícone de reenviar na UI).
      await OutboxService.enqueue(
        phoneNumberId: _pid,
        to: _chatId,
        contactName: widget.conversation.contactName,
        body: text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Sem conexão: mensagem salva e será reenviada.')),
        );
      }
      setState(() {});
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _export() async {
    final msgs = CacheService.thread(_pid, _chatId, limit: 500);
    final jsonStr =
        const JsonEncoder.withIndent('  ').convert(msgs);
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/conversa_${_chatId}_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonStr);
    await AuditService.log('conversation.export', 'Exportada conversa $_chatId');
    await Share.shareXFiles([XFile(file.path)], text: 'Histórico da conversa');
  }

  void _messageMenu(ChatMessage m) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copiar'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: m.body));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('Encaminhar (copia para o composer)'),
              onTap: () {
                _controller.text = m.body;
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mark_chat_read),
              title: const Text('Marcar como não lida'),
              onTap: () async {
                // Recoloca a thread como não lida (status local).
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Thread marcada como não lida.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final msgs = _messages();
    final pending =
        OutboxService.pending().where((p) => p['to'] == _chatId).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.conversation.contactName),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Exportar conversa (JSON)',
            onPressed: _export,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: msgs.length + pending.length,
              itemBuilder: (_, i) {
                if (i < msgs.length) {
                  final m = msgs[i];
                  return GestureDetector(
                    onLongPress: () => _messageMenu(m),
                    child: _Bubble(message: m),
                  );
                }
                final p = pending[i - msgs.length];
                return _PendingBubble(
                  body: p['body'] as String,
                  onRetry: () async {
                    await OutboxService.retryNow(p['localId'] as String);
                    await OutboxService.processAll(
                        ref.read(resilientApiProvider));
                    if (mounted) setState(() {});
                  },
                  onDiscard: () async {
                    await OutboxService.discard(p['localId'] as String);
                    if (mounted) setState(() {});
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.bolt_outlined),
                  tooltip: 'Respostas rápidas (ou digite /)',
                  onPressed: () {
                    final canned = ref.read(cannedResponsesProvider);
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => SafeArea(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final r in canned)
                              ListTile(
                                title: Text(r),
                                onTap: () {
                                  Navigator.pop(context);
                                  _controller.text = r;
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Mensagem... (/atalho, {{nome}})',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 4),
                _sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton.filled(
                        icon: const Icon(Icons.send), onPressed: _send),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final mine = message.direction == MessageDirection.outbound;
    final scheme = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.bodyMedium!;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color:
              mine ? const Color(0xFFD9FDD3) : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message.mediaUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: CachedNetworkImage(
                  imageUrl: message.mediaUrl!,
                  height: 160,
                  fit: BoxFit.cover,
                  // Downsampling: o plugin redimensiona antes de renderizar.
                  memCacheHeight: 320,
                  placeholder: (_, __) =>
                      const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.broken_image),
                ),
              ),
            if (message.type != 'text' && message.mediaUrl == null)
              Text('[${message.type}]',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            if (message.body.isNotEmpty)
              RichText(text: SimpleMarkdown.parse(message.body, base)),
            const SizedBox(height: 2),
            Text(
              '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')} · ${_statusLabel(message.status)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String s) => switch (s) {
        'read' => '✓✓ lida',
        'delivered' => '✓✓',
        'sent' => '✓',
        'failed' => 'falhou',
        _ => '',
      };
}

/// Bolha de mensagem pendente (outbox) com ações de reenviar/descartar.
class _PendingBubble extends StatelessWidget {
  final String body;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;
  const _PendingBubble(
      {required this.body, required this.onRetry, required this.onDiscard});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(body)),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'Reenviar agora',
              onPressed: onRetry,
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Descartar',
              onPressed: onDiscard,
            ),
          ],
        ),
      ),
    );
  }
}
