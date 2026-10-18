/// Ofuscação de dados sensíveis na UI (telefones, e-mails, CPFs).
///
/// Ativado por sessão na tela de Configurações; o dado real continua
/// intacto no Hive — só a apresentação muda.
class DataMaskingService {
  static final _phone = RegExp(r'\+?\d[\d\s().-]{7,}\d');
  static final _email =
      RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');
  static final _cpf = RegExp(r'\d{3}\.\d{3}\.\d{3}-\d{2}');

  static String maskPhone(String input) => input.replaceAllMapped(_phone, (m) {
        final digits = m.group(0)!.replaceAll(RegExp(r'\D'), '');
        if (digits.length < 4) return m.group(0)!;
        final last4 = digits.substring(digits.length - 4);
        return '+•• •••••-$last4';
      });

  static String maskEmail(String input) =>
      input.replaceAllMapped(_email, (m) {
        final parts = m.group(0)!.split('@');
        final user = parts[0];
        final maskedUser =
            user.length <= 2 ? '••' : '${user[0]}••${user[user.length - 1]}';
        return '$maskedUser@${parts[1]}';
      });

  static String maskCpf(String input) =>
      input.replaceAll(_cpf, '•••.•••.•••-••');

  /// Aplica todas as máscaras de uma vez.
  static String maskAll(String input) =>
      maskCpf(maskEmail(maskPhone(input)));
}
