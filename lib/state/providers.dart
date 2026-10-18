import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/models/phone_number.dart';
import '../core/models/message.dart';
import '../core/models/conversation.dart';
import '../core/models/automation_rule.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/audit_service.dart';

final authServiceProvider = Provider((_) => AuthService());
final apiServiceProvider = Provider((ref) => WhatsAppApiService(ref.watch(authServiceProvider)));
final resilientApiProvider =
    Provider((ref) => ResilientApiService(ref.watch(apiServiceProvider)));

/// Números onboardados (persistidos criptografados via meta box; em produção,
/// prefira guardar também no secure storage).
class PhoneNumbersNotifier extends Notifier<List<PhoneNumber>> {
  @override
  List<PhoneNumber> build() {
    final raw = CacheService.getMeta<List>('phone_numbers') ?? [];
    return raw.map((e) => PhoneNumber.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> _persist() => CacheService.putMeta(
      'phone_numbers', [for (final p in state) p.toJson()]);

  Future<void> add(PhoneNumber number) async {
    state = [...state, number];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _persist();
  }

  Future<void> toggle(String id) async {
    state = [for (final p in state) p.id == id
        ? PhoneNumber(id: p.id, displayNumber: p.displayNumber, label: p.label, active: !p.active)
        : p];
    await _persist();
  }
}

final phoneNumbersProvider =
    NotifierProvider<PhoneNumbersNotifier, List<PhoneNumber>>(PhoneNumbersNotifier.new);

/// Inbox unificado derivado do cache local (webhooks -> Hive).
class InboxNotifier extends Notifier<List<Conversation>> {
  @override
  List<Conversation> build() => _rebuild();

  List<Conversation> _rebuild() {
    final convos = <Conversation>[];
    for (final key in CacheService.threadKeys()) {
      final parts = key.split('::');
      if (parts.length != 2) continue;
      final msgs = CacheService.thread(parts[0], parts[1], limit: 500)
          .map(ChatMessage.fromJson)
          .toList();
      if (msgs.isEmpty) continue;
      msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final last = msgs.last;
      final unread = msgs
          .where((m) => m.direction == MessageDirection.inbound && m.status != 'read')
          .length;
      convos.add(Conversation(
        phoneNumberId: parts[0],
        chatId: parts[1],
        contactName: last.contactName,
        lastMessage: last,
        unreadCount: unread,
      ));
    }
    convos.sort((a, b) => b.lastMessage.timestamp.compareTo(a.lastMessage.timestamp));
    return convos;
  }

  void refresh() => state = _rebuild();

  /// Chamado pelo handler de push (FCM) ao chegar mensagem do backend.
  Future<void> ingest(Map<String, dynamic> json) async {
    await CacheService.appendMessage(json);
    refresh();
  }
}

final inboxProvider =
    NotifierProvider<InboxNotifier, List<Conversation>>(InboxNotifier.new);

/// Filtro atual do inbox: null = todos os números.
final inboxFilterProvider = StateProvider<String?>((_) => null);

/// Regras de automação (editadas no app, executadas no backend).
class AutomationNotifier extends Notifier<List<AutomationRule>> {
  @override
  List<AutomationRule> build() {
    final raw = CacheService.getMeta<List>('automation_rules') ?? [];
    return raw.map((e) => AutomationRule.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> _persist() =>
      CacheService.putMeta('automation_rules', [for (final r in state) r.toJson()]);

  Future<void> upsert(AutomationRule rule) async {
    final i = state.indexWhere((r) => r.id == rule.id);
    state = i >= 0
        ? [for (final r in state) r.id == rule.id ? rule : r]
        : [...state, rule];
    await _persist();
    await AuditService.log(
        i >= 0 ? 'automation.update' : 'automation.create',
        'Regra "${rule.keyword}" ${rule.enabled ? "ativa" : "inativa"}');
  }

  Future<void> remove(String id) async {
    final removed = state.where((r) => r.id == id).map((r) => r.keyword).firstOrNull;
    state = state.where((r) => r.id != id).toList();
    await _persist();
    await AuditService.log('automation.delete', 'Regra "$removed" removida');
  }

  String newId() => const Uuid().v4();
}

final automationProvider =
    NotifierProvider<AutomationNotifier, List<AutomationRule>>(AutomationNotifier.new);

/// Respostas prontas (canned responses).
final cannedResponsesProvider = StateProvider<List<String>>((_) => const [
      'Olá! Como posso ajudar?',
      'Aguarde um momento, já verifico para você.',
      'Obrigado pelo contato! Qualquer dúvida estou à disposição.',
    ]);

/// Status operacional da thread (kanban do operador).
enum ThreadStatus { open, awaiting, resolved }

/// Filtros avançados do inbox.
enum InboxFilter { all, unread, pendingReply, awaitingClient, resolved }

final inboxFilterModeProvider = StateProvider<InboxFilter>((_) => InboxFilter.all);
final inboxSearchProvider = StateProvider<String>((_) => '');

/// Atalhos do composer: "/atalho" → texto.
final composerShortcutsProvider = StateProvider<Map<String, String>>((_) => const {
      '/preco': 'Segue nossa tabela de preços: ...',
      '/horario': 'Atendemos de seg a sex, das 9h às 18h.',
      '/endereco': 'Estamos na Rua Exemplo, 123 — São Paulo/SP.',
    });

/// Status por thread, persistido no Hive (meta box).
class ThreadStatusNotifier extends Notifier<Map<String, ThreadStatus>> {
  String _key(String pid, String chat) => 'thread_status::$pid::$chat';

  @override
  Map<String, ThreadStatus> build() {
    final map = <String, ThreadStatus>{};
    // Carregamento preguiçoso: lido sob demanda em [of].
    return map;
  }

  ThreadStatus of(String pid, String chat) {
    final raw = CacheService.getMeta<String>(_key(pid, chat));
    if (raw != null) {
      return ThreadStatus.values.asNameMap()[raw] ?? ThreadStatus.open;
    }
    return state[_key(pid, chat)] ?? ThreadStatus.open;
  }

  Future<void> set(String pid, String chat, ThreadStatus status) async {
    await CacheService.putMeta(_key(pid, chat), status.name);
    state = {...state, _key(pid, chat): status};
  }
}

final threadStatusProvider =
    NotifierProvider<ThreadStatusNotifier, Map<String, ThreadStatus>>(
        ThreadStatusNotifier.new);
