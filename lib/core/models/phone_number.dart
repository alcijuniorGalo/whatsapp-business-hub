/// Número de telefone onboardado na Cloud API.
///
/// IMPORTANTE: a Cloud API não oferece endpoint de "listar conversas" ou
/// "baixar histórico". O inbox do hub é construído a partir dos eventos de
/// webhook (servidor em `server/webhook_server.js`) persistidos no Hive.
class PhoneNumber {
  final String id; // phone_number_id da Meta
  final String displayNumber; // ex: +55 11 90000-0000
  final String label; // ex: "Vendas", "Suporte"
  final bool active;

  const PhoneNumber({
    required this.id,
    required this.displayNumber,
    required this.label,
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayNumber': displayNumber,
        'label': label,
        'active': active,
      };

  factory PhoneNumber.fromJson(Map<String, dynamic> json) => PhoneNumber(
        id: json['id'] as String,
        displayNumber: json['displayNumber'] as String,
        label: json['label'] as String,
        active: json['active'] as bool? ?? true,
      );
}
