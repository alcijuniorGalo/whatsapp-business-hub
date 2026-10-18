/// Teste de integração (scaffold).
///
/// Roda em dispositivo/simulador real com `flutter test integration_test`.
/// Requer:
///   - Token de TESTE da Cloud API (nunca produção) via --dart-define:
///       flutter test integration_test --dart-define=WA_TEST_TOKEN=... \
///         --dart-define=WA_TEST_NUMBER_ID=... --dart-define=WA_TEST_TO=...
///   - Webhook server de staging acessível.
///
/// Fluxo: onboarding do token -> envio de mensagem de teste -> aguarda o
/// evento no /events/since do servidor -> valida que o inbox o incorporou.
///
/// Este arquivo documenta o contrato; a implementação completa usa
/// `integration_test` + `flutter_driver` e é executada no CI apenas com
/// secrets configurados (job separado, manual).
void main() {}
