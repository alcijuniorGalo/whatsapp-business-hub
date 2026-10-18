import 'package:flutter/material.dart';
import '../../state/providers.dart';
import '../../services/api_service.dart';
import '../../core/models/phone_number.dart';
import '../../core/config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Onboarding guiado em 3 passos: token → números → teste de conexão.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _step = 0;

  final _token = TextEditingController();
  String? _tokenError;
  bool _validating = false;

  final _numberId = TextEditingController();
  final _display = TextEditingController();
  final _label = TextEditingController();

  String _testStatus = '';

  @override
  void dispose() {
    _page.dispose();
    _token.dispose();
    _numberId.dispose();
    _display.dispose();
    _label.dispose();
    super.dispose();
  }

  void _go(int step) {
    setState(() => _step = step);
    _page.animateToPage(step,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _validateAndSaveToken() async {
    final token = _token.text.trim();
    if (token.isEmpty) {
      setState(() => _tokenError = 'Cole o access token.');
      return;
    }
    setState(() {
      _validating = true;
      _tokenError = null;
    });
    try {
      final name = await WhatsAppApiService.validateToken(token);
      await ref.read(authServiceProvider).saveToken(token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Token válido ($name).')),
        );
        _go(1);
      }
    } catch (e) {
      setState(() => _tokenError = e.toString());
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Future<void> _addNumber() async {
    final numbers = ref.read(phoneNumbersProvider);
    if (numbers.length >= ApiConfig.maxPhoneNumbers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limite de 10 números.')));
      return;
    }
    if (_numberId.text.trim().isEmpty || _display.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha ID e número.')));
      return;
    }
    await ref.read(phoneNumbersProvider.notifier).add(PhoneNumber(
          id: _numberId.text.trim(),
          displayNumber: _display.text.trim(),
          label: _label.text.trim().isEmpty
              ? _display.text.trim()
              : _label.text.trim(),
        ));
    _numberId.clear();
    _display.clear();
    _label.clear();
    setState(() {});
  }

  /// Teste de conexão: envia mensagem de teste para o próprio número de teste.
  Future<void> _testConnection() async {
    final numbers = ref.read(phoneNumbersProvider);
    if (numbers.isEmpty) {
      setState(() => _testStatus = 'Adicione ao menos um número antes.');
      return;
    }
    setState(() => _testStatus = 'Enviando mensagem de teste...');
    try {
      final api = ref.read(resilientApiProvider);
      final first = numbers.first;
      // Envia para o próprio número cadastrado (eco de teste).
      final wamid = await api.sendText(
        phoneNumberId: first.id,
        to: first.displayNumber.replaceAll(RegExp(r'\D'), ''),
        body: '✅ Business Hub conectado e operacional.',
      );
      setState(() => _testStatus = 'OK! wamid: $wamid\n'
          'Verifique o webhook: a entrega deve aparecer no inbox em segundos.');
    } catch (e) {
      setState(() => _testStatus = 'Falha: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final numbers = ref.watch(phoneNumbersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Configuração inicial')),
      body: Column(
        children: [
          _StepperHeader(step: _step),
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _step = i),
              children: [
                _stepToken(),
                _stepNumbers(numbers),
                _stepTest(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepToken() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('1. Conexão Meta',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
                'No painel Meta Developers → seu app → WhatsApp → API Setup, copie o access token temporário (ou o do System User em produção) e cole abaixo. Ele é validado na hora via /me.'),
            const SizedBox(height: 16),
            TextField(
              controller: _token,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Access token',
                border: const OutlineInputBorder(),
                errorText: _tokenError,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _validating ? null : _validateAndSaveToken,
              child: _validating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Validar e continuar'),
            ),
          ],
        ),
      );

  Widget _stepNumbers(List<PhoneNumber> numbers) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('2. Números',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${numbers.length}/${ApiConfig.maxPhoneNumbers} cadastrados.'),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  for (final n in numbers)
                    ListTile(
                      leading: CircleAvatar(child: Text(n.label[0])),
                      title: Text(n.label),
                      subtitle: Text(n.displayNumber),
                    ),
                ],
              ),
            ),
            TextField(
                controller: _numberId,
                decoration: const InputDecoration(
                    labelText: 'phone_number_id', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: _display,
                decoration: const InputDecoration(
                    labelText: 'Número (+55...)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: _label,
                decoration: const InputDecoration(
                    labelText: 'Alias (ex: Vendas BR)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                      onPressed: _addNumber,
                      child: const Text('Adicionar')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                      onPressed: numbers.isEmpty ? null : () => _go(2),
                      child: const Text('Continuar')),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _stepTest() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('3. Teste de webhook',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
                'Enviamos uma mensagem de teste pelo primeiro número. Se o webhook estiver configurado, a entrega aparece no inbox em segundos.'),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: _testConnection,
                child: const Text('Testar conexão')),
            const SizedBox(height: 16),
            Text(_testStatus),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Concluir e abrir o Hub'),
            ),
          ],
        ),
      );
}

class _StepperHeader extends StatelessWidget {
  final int step;
  const _StepperHeader({required this.step});

  @override
  Widget build(BuildContext context) {
    const labels = ['Token', 'Números', 'Teste'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: i <= step
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
              child: Text('${i + 1}',
                  style: const TextStyle(fontSize: 12, color: Colors.white)),
            ),
            const SizedBox(width: 6),
            Text(labels[i]),
            if (i < 2) const Expanded(child: Divider()),
          ],
        ],
      ),
    );
  }
}
