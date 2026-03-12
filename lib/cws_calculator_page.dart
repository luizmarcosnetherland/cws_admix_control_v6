import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class CwsCalculatorPage extends StatefulWidget {
  const CwsCalculatorPage({super.key});

  @override
  State<CwsCalculatorPage> createState() => _CwsCalculatorPageState();
}

class _CwsCalculatorPageState extends State<CwsCalculatorPage> {
  static const _cotacaoEmail = 'luizmarcos@netherland.com.br';
  static const _cotacaoWhatsapp = '5541999731741';
  final _volumeCtrl = TextEditingController(text: '10');
  final _cementCtrl = TextEditingController(text: '350');

  double get volume =>
      double.tryParse(_volumeCtrl.text.replaceAll(',', '.')) ?? 0.0;
  double get cementKgM3 =>
      double.tryParse(_cementCtrl.text.replaceAll(',', '.')) ?? 0.0;

  double get dosageKgM3 => cementKgM3 > 450 ? 1.0 : 0.8;
  double get totalKg => volume * dosageKgM3;
  int get bags => totalKg <= 0 ? 0 : (totalKg / 6.4).ceil();
  double get providedKg => bags * 6.4;

  String fmt(double value, {int casas = 1}) =>
      NumberFormat.decimalPatternDigits(
        locale: 'pt_BR',
        decimalDigits: casas,
      ).format(value);

  String get _mensagemCotacao => [
        'Olá, gostaria de solicitar uma cotação do CWS Admix.',
        '',
        'Volume de concreto: ${fmt(volume, casas: 1)} m³',
        'Consumo de cimento: ${fmt(cementKgM3, casas: 1)} kg/m³',
        'Dosagem aplicada: ${fmt(dosageKgM3, casas: 1)} kg/m³',
        'Quantidade necessária: ${fmt(totalKg, casas: 1)} kg',
        'Sacos de 6,4 kg: $bags',
        'Quantidade para compra: ${fmt(providedKg, casas: 1)} kg',
      ].join('\n');

  Future<void> _solicitarCotacaoEmail() async {
    try {
      final uri = Uri(
        scheme: 'mailto',
        path: _cotacaoEmail,
        query: _encodeQueryParameters({
          'subject': 'Solicitação de cotação CWS Admix',
          'body': _mensagemCotacao,
        }),
      );
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        await _showContatoFallback(
          titulo: 'Solicitar cotação por e-mail',
          destino: _cotacaoEmail,
        );
      }
    } catch (_) {
      if (!mounted) return;
      await _showContatoFallback(
        titulo: 'Solicitar cotação por e-mail',
        destino: _cotacaoEmail,
      );
    }
  }

  Future<void> _solicitarCotacaoWhatsapp() async {
    try {
      final uri = Uri.parse(
        'https://wa.me/$_cotacaoWhatsapp?text=${Uri.encodeComponent(_mensagemCotacao)}',
      );
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        await _showContatoFallback(
          titulo: 'Solicitar cotação por WhatsApp',
          destino: '+55 41 99973-1741',
        );
      }
    } catch (_) {
      if (!mounted) return;
      await _showContatoFallback(
        titulo: 'Solicitar cotação por WhatsApp',
        destino: '+55 41 99973-1741',
      );
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  Future<void> _showContatoFallback({
    required String titulo,
    required String destino,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: SelectableText(
          'Destino: $destino\n\nMensagem:\n$_mensagemCotacao',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: 'Destino: $destino\n\n$_mensagemCotacao'),
              );
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dados copiados para a área de transferência.')),
              );
            },
            child: const Text('Copiar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _volumeCtrl.dispose();
    _cementCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blue = const Color(0xFF1E3A5F);
    final regra = cementKgM3 > 450
        ? 'Para consumos acima de 450 kg/m³, usar 1,00 kg de CWS Admix por m³.'
        : 'Para consumos até 450 kg/m³, usar 0,80 kg de CWS Admix por m³.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadora CWS'),
        backgroundColor: blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cálculo de produto por volume de concreto',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    regra,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.68),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _field(
                    _volumeCtrl,
                    'Volume de concreto (m³)',
                    keyboard: TextInputType.number,
                  ),
                  _field(
                    _cementCtrl,
                    'Consumo de cimento (kg/m³)',
                    keyboard: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resultado',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _resultLine(
                    'Dosagem aplicada',
                    '${fmt(dosageKgM3, casas: 1)} kg/m³',
                  ),
                  _resultLine(
                    'Quantidade necessária',
                    '${fmt(totalKg, casas: 1)} kg',
                  ),
                  _resultLine('Sacos de 6,4 kg', '$bags'),
                  _resultLine(
                    'Quantidade para compra',
                    '${fmt(providedKg, casas: 1)} kg',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _solicitarCotacaoEmail,
            icon: const Icon(Icons.email_outlined),
            label: const Text('Solicitar cotação por e-mail'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _solicitarCotacaoWhatsapp,
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Solicitar cotação por WhatsApp'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    required TextInputType keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _resultLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.black.withValues(alpha: 0.68)),
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
