/// Configuração central da Cloud API (WhatsApp Business Platform - Meta).
///
/// Nenhum segredo mora aqui: tokens e IDs sensíveis vão para o
/// `flutter_secure_storage` via [AuthService] (tela de Configurações).
class ApiConfig {
  static const graphVersion = 'v21.0';
  static const baseUrl = 'https://graph.facebook.com/$graphVersion';

  /// Escopo mínimo para envio/leitura via Cloud API.
  static const oauthScope = 'whatsapp_business_messaging,whatsapp_business_management';

  /// Limites operacionais do hub.
  static const maxPhoneNumbers = 10;
  static const historyPageSize = 50;
}
