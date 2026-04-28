import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:url_launcher/url_launcher.dart';

class CwsCalculatorPage extends StatefulWidget {
  final double? initialVolumeM3;

  const CwsCalculatorPage({super.key, this.initialVolumeM3});

  @override
  State<CwsCalculatorPage> createState() => _CwsCalculatorPageState();
}

class _CwsCalculatorPageState extends State<CwsCalculatorPage> {
  static const _cotacaoEmail = 'luizmarcos@netherland.com.br';
  static const _cotacaoWhatsapp = '5541999731741';
  final _volumeCtrl = TextEditingController();
  final _cementCtrl = TextEditingController(text: '350');
  final _enderecoEntregaCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _estadoCtrl = TextEditingController();
  final _empresaCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _volumeFocusNode = FocusNode();
  final _cementFocusNode = FocusNode();
  late final Listenable _inputsListenable;

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

  String _campoCotacao(String label, String value) {
    final texto = value.trim();
    return '$label: ${texto.isEmpty ? 'Nao informado' : texto}';
  }

  String get _mensagemCotacao => [
    'Olá, gostaria de solicitar uma cotação do CWS Admix.',
    '',
    'Volume de concreto: ${fmt(volume, casas: 1)} m³',
    'Consumo de cimento: ${fmt(cementKgM3, casas: 1)} kg/m³',
    'Dosagem aplicada: ${fmt(dosageKgM3, casas: 1)} kg/m³',
    'Quantidade necessária: ${fmt(totalKg, casas: 1)} kg',
    'Sacos de 6,4 kg: $bags',
    'Quantidade para compra: ${fmt(providedKg, casas: 1)} kg',
    '',
    _campoCotacao('Endereco de entrega', _enderecoEntregaCtrl.text),
    _campoCotacao('Cidade', _cidadeCtrl.text),
    _campoCotacao('Estado', _estadoCtrl.text),
    _campoCotacao('Empresa', _empresaCtrl.text),
    _campoCotacao('E-mail', _emailCtrl.text),
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
                const SnackBar(
                  content: Text('Dados copiados para a área de transferência.'),
                ),
              );
            },
            child: const Text('Copiar'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final initialVolume = widget.initialVolumeM3;
    if (initialVolume != null && initialVolume > 0) {
      final decimals = initialVolume.truncateToDouble() == initialVolume
          ? 0
          : 2;
      _volumeCtrl.text = initialVolume
          .toStringAsFixed(decimals)
          .replaceAll('.', ',');
    }
    _inputsListenable = Listenable.merge([_volumeCtrl, _cementCtrl]);
  }

  @override
  void dispose() {
    _volumeCtrl.dispose();
    _cementCtrl.dispose();
    _enderecoEntregaCtrl.dispose();
    _cidadeCtrl.dispose();
    _estadoCtrl.dispose();
    _empresaCtrl.dispose();
    _emailCtrl.dispose();
    _volumeFocusNode.dispose();
    _cementFocusNode.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  KeyboardActionsConfig _keyboardActionsConfig() {
    KeyboardActionsItem item(FocusNode node) {
      return KeyboardActionsItem(
        focusNode: node,
        toolbarButtons: [
          (focusNode) => TextButton(
            onPressed: focusNode.unfocus,
            child: const Text('Enter'),
          ),
        ],
      );
    }

    return KeyboardActionsConfig(
      keyboardActionsPlatform: KeyboardActionsPlatform.ALL,
      nextFocus: false,
      actions: [item(_volumeFocusNode), item(_cementFocusNode)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final blue = const Color(0xFF1E3A5F);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadora CWS'),
        backgroundColor: blue,
        foregroundColor: Colors.white,
      ),
      body: KeyboardActions(
        config: _keyboardActionsConfig(),
        child: ListView(
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ajuste o volume de concreto da sua concretagem e veja quanto CWS Admix será necessário.',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _field(
                      _volumeCtrl,
                      'Volume de concreto (m³)',
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      focusNode: _volumeFocusNode,
                      textInputAction: TextInputAction.done,
                    ),
                    _field(
                      _cementCtrl,
                      'Consumo de cimento (kg/m³)',
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      focusNode: _cementFocusNode,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _inputsListenable,
              builder: (context, _) {
                return Card(
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
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
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
                );
              },
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
                      'Dados para cotacao',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field(
                      _enderecoEntregaCtrl,
                      'Endereco de entrega',
                      keyboard: TextInputType.streetAddress,
                    ),
                    _field(_cidadeCtrl, 'Cidade', keyboard: TextInputType.text),
                    _field(_estadoCtrl, 'Estado', keyboard: TextInputType.text),
                    _field(
                      _empresaCtrl,
                      'Empresa',
                      keyboard: TextInputType.text,
                    ),
                    _field(
                      _emailCtrl,
                      'E-mail',
                      keyboard: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
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
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    required TextInputType keyboard,
    FocusNode? focusNode,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        focusNode: focusNode,
        keyboardType: keyboard,
        textInputAction: textInputAction,
        onSubmitted: (_) => _dismissKeyboard(),
        onTapOutside: (_) => _dismissKeyboard(),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
