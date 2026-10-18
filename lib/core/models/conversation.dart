import 'message.dart';

/// Conversa agregada (1 contato em 1 número). Derivada do cache local.
class Conversation {
  final String phoneNumberId;
  final String chatId;
  final String contactName;
  final ChatMessage lastMessage;
  final int unreadCount;

  const Conversation({
    required this.phoneNumberId,
    required this.chatId,
    required this.contactName,
    required this.lastMessage,
    this.unreadCount = 0,
  });
}
