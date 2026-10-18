import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../core/models/phone_number.dart';
import '../../core/config.dart';
import '../../services/cache_service.dart';
import '../../services/audit_service.dart';

/// Configurações: token da Cloud API + cadastro dos números.
///
/// O token vai para o EncryptedSharedPreferences (flutter_secure_storage).
/// Obtenha em: Meta Developers → seu app → WhatsApp → API Setup (token
/// temporário) ou via System User para produção.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _token = TextEditingController();
  final _numberId = TextEditingController();
  final _display = TextEditingController();
  final _label = TextEditingController();
  bool _hasToken = false;
  bool _maskData = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = ref.read(authServiceProvider);
    final ok = await auth.hasValidToken;
    final mask = CacheService.getMeta<bool>('mask_data') ?? false;
    if (mounted) setState(() {
      _hasToken = ok;
      _maskData = mask;
    });
  }

  Future<void> _saveToken() async {
    final token = _token.text.trim();
    if (token.isEmpty) return;
    await ref.read(authServiceProvider).saveToken(token);
    await AuditService.log('token.update', 'Token da Cloud API atualizado');
    _token.clear();
    if (mounted) {
      setState(() => _hasToken = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token salvo com segurança.')),
      );
    }
  }

  Future<void> _addNumber() async {
    final numbers = ref.read(phoneNumbersProvider);
    if (numbers.length >= ApiConfig.maxPhoneNumbers) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Limite de 10 números atingido.')),
        );
      }
      return;
    }
    if (_numberId.text.trim().isEmpty || _display.text.trim().isEmpty) return;
    await ref.read(phoneNumbersProvider.notifier).add(PhoneNumber(
          id: _numberId.text.trim(),
          displayNumber: _display.text.trim(),
          label: _label.text.trim().isEmpty ? _display.text.trim() : _label.text.trim(),
        ));
    _numberId.clear();
    _display.clear();
    _label.clear();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _token.dispose();
    _numberId.dispose();
    _display.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Cloud API', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(_hasToken ? Icons.check_circle : Icons.warning,
                  color: _hasToken ? Colors.green : Colors.orange),
              const SizedBox(width: 8),
              Text(_hasToken ? 'Token configurado' : 'Token não configurado'),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _token,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Access token (será criptografado)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _saveToken, child: const Text('Salvar token')),
          TextButton(
            onPressed: () async {
              await ref.read(authServiceProvider).clear();
              if (mounted) setState(() => _hasToken = false);
            },
            child: const Text('Apagar token'),
          ),
          const Divider(height: 32),
          Text('Números (${ref.watch(phoneNumbersProvider).length}/10)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _numberId,
            decoration: const InputDecoration(
              labelText: 'phone_number_id (Meta)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _display,
            decoration: const InputDecoration(
              labelText: 'Número exibido (ex: +55 11 90000-0000)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _label,
            decoration: const InputDecoration(
              labelText: 'Rótulo (ex: Vendas)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
              onPressed: _addNumber, child: const Text('Adicionar número')),
          const Divider(height: 32),
          SwitchListTile(
            title: const Text('Mascarar dados sensíveis'),
            subtitle: const Text('Oculta telefones na UI (+55 •••••-1234)'),
            value: _maskData,
            onChanged: (v) async {
              setState(() => _maskData = v);
              await CacheService.putMeta('mask_data', v);
            },
          ),
        ],
      ),
    );
  }
}
