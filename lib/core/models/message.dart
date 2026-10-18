/// Mensagem (entrada via webhook ou saída via API).
enum MessageDirection { inbound, outbound }

class ChatMessage {
  final String id; // wamid da Meta ou UUID local p/ rascunhos
  final String phoneNumberId; // de qual número (conta) ela é
  final String chatId; // wa_id do contato
  final String contactName;
  final MessageDirection direction;
  final String type; // text | image | document | audio | button | template
  final String body;
  final String? mediaUrl;
  final DateTime timestamp;
  final String status; // sent | delivered | read | failed | received

  const ChatMessage({
    required this.id,
    required this.phoneNumberId,
    required this.chatId,
    required this.contactName,
    required this.direction,
    required this.type,
    required this.body,
    this.mediaUrl,
    required this.timestamp,
    this.status = 'sent',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'phoneNumberId': phoneNumberId,
        'chatId': chatId,
        'contactName': contactName,
        'direction': direction.name,
        'type': type,
        'body': body,
        'mediaUrl': mediaUrl,
        'timestamp': timestamp.toIso8601String(),
        'status': status,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        phoneNumberId: json['phoneNumberId'] as String,
        chatId: json['chatId'] as String,
        contactName: json['contactName'] as String? ?? json['chatId'] as String,
        direction: MessageDirection.values.byName(json['direction'] as String),
        type: json['type'] as String? ?? 'text',
        body: json['body'] as String? ?? '',
        mediaUrl: json['mediaUrl'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        status: json['status'] as String? ?? 'sent',
      );
}
