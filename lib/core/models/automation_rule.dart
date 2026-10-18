/// Regra de automação: "se a mensagem contiver <keyword>, responda <reply>".
///
/// A execução acontece no backend (webhook server), para responder mesmo com
/// o app em background. O app apenas edita/sincroniza as regras.
class AutomationRule {
  final String id;
  final String keyword; // gatilho (case-insensitive, contém)
  final String replyTemplate; // suporta variáveis {{nome}}, {{numero}}
  final bool enabled;
  final String? phoneNumberId; // null = vale para todos os números

  const AutomationRule({
    required this.id,
    required this.keyword,
    required this.replyTemplate,
    this.enabled = true,
    this.phoneNumberId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'keyword': keyword,
        'replyTemplate': replyTemplate,
        'enabled': enabled,
        'phoneNumberId': phoneNumberId,
      };

  factory AutomationRule.fromJson(Map<String, dynamic> json) => AutomationRule(
        id: json['id'] as String,
        keyword: json['keyword'] as String,
        replyTemplate: json['replyTemplate'] as String,
        enabled: json['enabled'] as bool? ?? true,
        phoneNumberId: json['phoneNumberId'] as String?,
      );

  /// Aplica variáveis de personalização no template.
  String render({required String contactName, required String chatId}) {
    return replyTemplate
        .replaceAll('{{nome}}', contactName)
        .replaceAll('{{numero}}', chatId);
  }
}
