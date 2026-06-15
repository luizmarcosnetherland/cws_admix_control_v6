import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../cws_calculator_page.dart';

enum _CalendarSaveResult { created, opened, shared }

class AgendamentoConcretagemPage extends StatefulWidget {
  final VoidCallback? onBackFallback;

  const AgendamentoConcretagemPage({super.key, this.onBackFallback});

  @override
  State<AgendamentoConcretagemPage> createState() =>
      _AgendamentoConcretagemPageState();
}

class _AgendamentoConcretagemPageState
    extends State<AgendamentoConcretagemPage> {
  static const _calendarChannel = MethodChannel(
    'br.com.netherland.cwsadmixcontrol/calendar',
  );
  static const _dosagemCwsAdmixKgPorM3 = 0.80;

  final _formKey = GlobalKey<FormState>();

  final _dataCtrl = TextEditingController();
  final _horaCtrl = TextEditingController();
  final _volumeCtrl = TextEditingController();
  final _estruturaCtrl = TextEditingController();
  final _tracoCtrl = TextEditingController();

  DateTime? _dataConcretagem;
  TimeOfDay? _horaInicio;
  bool _processando = false;
  bool _agendamentoConcluido = false;

  @override
  void initState() {
    super.initState();
    _volumeCtrl.addListener(_atualizarEstimativaCws);
    _estruturaCtrl.addListener(_limparConfirmacaoAgendamento);
    _tracoCtrl.addListener(_limparConfirmacaoAgendamento);
  }

  @override
  void dispose() {
    _volumeCtrl.removeListener(_atualizarEstimativaCws);
    _estruturaCtrl.removeListener(_limparConfirmacaoAgendamento);
    _tracoCtrl.removeListener(_limparConfirmacaoAgendamento);
    _dataCtrl.dispose();
    _horaCtrl.dispose();
    _volumeCtrl.dispose();
    _estruturaCtrl.dispose();
    _tracoCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: tr(label),
      prefixIcon: icon == null ? null : Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  void _atualizarEstimativaCws() {
    if (!mounted) return;
    setState(() => _agendamentoConcluido = false);
  }

  void _limparConfirmacaoAgendamento() {
    if (!mounted || !_agendamentoConcluido) return;
    setState(() => _agendamentoConcluido = false);
  }

  double? _volumeEstimadoM3() {
    return double.tryParse(_volumeCtrl.text.trim().replaceAll(',', '.'));
  }

  double? _cwsAdmixEstimadoKg() {
    final volume = _volumeEstimadoM3();
    if (volume == null || volume <= 0) return null;
    return volume * _dosagemCwsAdmixKgPorM3;
  }

  String _fmtDecimal(double value, {int decimalDigits = 2}) {
    return NumberFormat.decimalPatternDigits(
      locale: CwsLocalizations.current.dateLocale,
      decimalDigits: decimalDigits,
    ).format(value);
  }

  Future<void> _selecionarData() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataConcretagem ?? now,
      firstDate: today,
      lastDate: DateTime(now.year + 5),
      locale: CwsLocalizations.current.locale,
    );
    if (picked == null) return;
    if (!mounted) return;

    setState(() {
      _dataConcretagem = DateTime(picked.year, picked.month, picked.day);
      _dataCtrl.text = DateFormat.yMd(
        CwsLocalizations.current.dateLocale,
      ).format(picked);
      _agendamentoConcluido = false;
    });
  }

  Future<void> _selecionarHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _horaInicio ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    if (!mounted) return;

    setState(() {
      _horaInicio = picked;
      _horaCtrl.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      _agendamentoConcluido = false;
    });
  }

  DateTime _inicioConcretagem() {
    final data = _dataConcretagem!;
    final hora = _horaInicio!;
    return DateTime(data.year, data.month, data.day, hora.hour, hora.minute);
  }

  String? _volumeLabel() {
    final value = _volumeEstimadoM3();
    if (value == null || value <= 0) return null;
    final formatted = _fmtDecimal(
      value,
      decimalDigits: value.truncateToDouble() == value ? 0 : 2,
    );
    return '$formatted m3';
  }

  String? _cwsAdmixQuantidadeLabel() {
    final quantidade = _cwsAdmixEstimadoKg();
    if (quantidade == null) return null;
    return '${_fmtDecimal(quantidade)} kg';
  }

  String _tituloEvento() {
    final estrutura = _estruturaCtrl.text.trim();
    return estrutura.isEmpty
        ? tr('Concretagem programada')
        : '${tr('Concretagem')} - $estrutura';
  }

  String _descricaoEvento() {
    final inicio = DateFormat.yMd(
      CwsLocalizations.current.dateLocale,
    ).add_Hm().format(_inicioConcretagem());
    final estrutura = _estruturaCtrl.text.trim();
    final traco = _tracoCtrl.text.trim();
    final volumeLabel = _volumeLabel();
    final cwsAdmixQuantidadeLabel = _cwsAdmixQuantidadeLabel();

    return [
      tr('Agendamento de concretagem'),
      '',
      if (estrutura.isNotEmpty) '${tr('Estrutura')}: $estrutura',
      if (traco.isNotEmpty) '${tr('Traço do concreto')}: $traco',
      '${tr('Data e hora previstas')}: $inicio',
      if (volumeLabel != null) '${tr('Volume estimado')}: $volumeLabel',
      tr('Haverá adição do CWS Admix ao concreto.'),
      if (cwsAdmixQuantidadeLabel != null)
        '${tr('Quantidade estimada de CWS Admix')}: $cwsAdmixQuantidadeLabel',
    ].join('\n');
  }

  String _mensagemCompartilhamento() {
    return [
      tr('Segue o agendamento de concretagem:'),
      '',
      _tituloEvento(),
      '',
      _descricaoEvento(),
    ].join('\n');
  }

  String _mensagemConfirmacaoCalendario(_CalendarSaveResult result) {
    return switch (result) {
      _CalendarSaveResult.created => tr('Evento criado no Calendario.'),
      _CalendarSaveResult.opened => tr(
        'O evento foi enviado ao aplicativo de calendario. Confira e salve para concluir.',
      ),
      _CalendarSaveResult.shared => tr(
        'Convite de calendario preparado. Use o aplicativo escolhido para concluir.',
      ),
    };
  }

  String _dtCalendar(DateTime dateTime) {
    return DateFormat("yyyyMMdd'T'HHmmss'Z'").format(dateTime.toUtc());
  }

  String _icsEscape(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('\r\n', '\n')
        .replaceAll('\n', r'\n')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,');
  }

  String _arquivoSeguro(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'concretagem' : normalized;
  }

  String _icsFilename() {
    final date = DateFormat('yyyyMMdd_HHmm').format(_inicioConcretagem());
    return 'agendamento_${_arquivoSeguro(_estruturaCtrl.text)}_$date.ics';
  }

  String _icsContent() {
    final inicio = _inicioConcretagem();
    final fim = inicio.add(const Duration(hours: 2));
    final uid =
        '${inicio.millisecondsSinceEpoch}-${_arquivoSeguro(_estruturaCtrl.text)}@cwsadmixcontrol';

    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Netherland//CWS Admix Control//PT-BR',
      'CALSCALE:GREGORIAN',
      'METHOD:REQUEST',
      'BEGIN:VEVENT',
      'UID:$uid',
      'DTSTAMP:${_dtCalendar(DateTime.now())}',
      'DTSTART:${_dtCalendar(inicio)}',
      'DTEND:${_dtCalendar(fim)}',
      'SUMMARY:${_icsEscape(_tituloEvento())}',
      'DESCRIPTION:${_icsEscape(_descricaoEvento())}',
      'BEGIN:VALARM',
      'TRIGGER:-P1D',
      'ACTION:DISPLAY',
      'DESCRIPTION:${_icsEscape('${tr('Lembrete')}: ${_tituloEvento()} ${tr('amanha')}')}',
      'END:VALARM',
      'END:VEVENT',
      'END:VCALENDAR',
      '',
    ].join('\r\n');
  }

  Uint8List _icsBytes() {
    return Uint8List.fromList(utf8.encode(_icsContent()));
  }

  Future<XFile> _icsXFile() async {
    final filename = _icsFilename();
    final bytes = _icsBytes();

    if (kIsWeb) {
      return XFile.fromData(bytes, mimeType: 'text/calendar', name: filename);
    }

    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path, mimeType: 'text/calendar', name: filename);
  }

  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  bool _validarFormulario() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return false;

    if (_inicioConcretagem().isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Informe uma data e horario futuros.'))),
      );
      return false;
    }

    return true;
  }

  Future<void> _executarAcao(Future<void> Function() action) async {
    if (_processando) return;
    if (!_validarFormulario()) return;

    setState(() => _processando = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      final error = e is PlatformException && (e.message?.isNotEmpty ?? false)
          ? e.message!
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Erro ao preparar agendamento: {error}',
              params: {'error': error},
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processando = false);
      }
    }
  }

  Future<void> _agendar() async {
    await _executarAcao(() async {
      final calendarResult = await _salvarNoCalendario();

      if (!mounted) return;
      final compartilhar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('Agendamento enviado')),
          content: Text(
            '${_mensagemConfirmacaoCalendario(calendarResult)}\n\n'
            '${tr('Deseja enviar um resumo pelo WhatsApp?')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(tr('Agora não')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(tr('Compartilhar')),
            ),
          ],
        ),
      );

      if (!mounted) return;
      setState(() => _agendamentoConcluido = true);

      if (compartilhar == true) {
        await _compartilharWhatsAppResumo();
        if (!mounted) return;
      }
    });
  }

  Future<_CalendarSaveResult> _salvarNoCalendario() async {
    final inicio = _inicioConcretagem();
    final fim = inicio.add(const Duration(hours: 2));

    if (!kIsWeb && Platform.isIOS) {
      await _calendarChannel.invokeMethod<void>('createEvent', {
        'title': _tituloEvento(),
        'notes': _descricaoEvento(),
        'startMillis': inicio.millisecondsSinceEpoch,
        'endMillis': fim.millisecondsSinceEpoch,
        'alarmOffsetSeconds': -86400,
      });

      return _CalendarSaveResult.created;
    }

    if (!kIsWeb && Platform.isAndroid) {
      await _calendarChannel.invokeMethod<void>('openEventEditor', {
        'title': _tituloEvento(),
        'notes': _descricaoEvento(),
        'startMillis': inicio.millisecondsSinceEpoch,
        'endMillis': fim.millisecondsSinceEpoch,
        'alarmOffsetSeconds': -86400,
      });

      return _CalendarSaveResult.opened;
    }

    final xFile = await _icsXFile();

    if (!kIsWeb && Platform.isMacOS) {
      final result = await Process.run('open', [xFile.path]);
      if (result.exitCode == 0) {
        if (!mounted) return _CalendarSaveResult.opened;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Evento enviado ao Calendario.'))),
        );
        return _CalendarSaveResult.opened;
      }
    }

    if (!mounted) return _CalendarSaveResult.shared;
    await Share.shareXFiles(
      [xFile],
      subject: _tituloEvento(),
      text: _mensagemCompartilhamento(),
      sharePositionOrigin: _shareOrigin(),
    );
    return _CalendarSaveResult.shared;
  }

  Future<void> _compartilharWhatsApp() async {
    await _executarAcao(() async {
      await _compartilharWhatsAppResumo();
    });
  }

  Future<void> _compartilharWhatsAppResumo() async {
    if (!mounted) return;
    await Share.share(
      _mensagemCompartilhamento(),
      subject: _tituloEvento(),
      sharePositionOrigin: _shareOrigin(),
    );
  }

  void _abrirPedidoCwsAdmix() {
    final volume = _volumeEstimadoM3();
    if (volume == null || volume <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Informe o volume previsto antes de fazer o pedido.'),
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CwsCalculatorPage(initialVolumeM3: volume),
      ),
    );
  }

  Future<void> _voltar() async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    widget.onBackFallback?.call();
  }

  void _irParaDashboard() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
      return;
    }

    widget.onBackFallback?.call();
  }

  Widget _formActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _processando ? null : _agendar,
          icon: const Icon(Icons.event_available_outlined),
          label: Text(tr('AGENDAR')),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _processando ? null : _compartilharWhatsApp,
          icon: const Icon(Icons.chat_outlined),
          label: Text(tr('Compartilhar WhatsApp')),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _processando ? null : _abrirPedidoCwsAdmix,
          icon: const Icon(Icons.shopping_cart_outlined),
          label: Text(tr('Fazer pedido de CWS Admix')),
        ),
        if (_agendamentoConcluido) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _processando ? null : _irParaDashboard,
            icon: const Icon(Icons.dashboard_outlined),
            label: Text(tr('Voltar ao dashboard')),
          ),
        ],
      ],
    );
  }

  Widget _agendamentoConcluidoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr('Agendamento enviado ao Calendario.'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estimativaCwsCard() {
    final quantidade = _cwsAdmixEstimadoKg();
    final quantidadeLabel = quantidade == null
        ? tr('CWS Admix previsto: informe o volume.')
        : '${tr('CWS Admix previsto')}: ${_cwsAdmixQuantidadeLabel()}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF2B63A7).withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, color: Color(0xFF2B63A7)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              quantidadeLabel,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      appBar: AppBar(
        leading: IconButton(
          tooltip: tr('Voltar'),
          icon: const Icon(Icons.arrow_back),
          onPressed: _voltar,
        ),
        title: Text(tr('Agendamento de Concretagem')),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Dados da concretagem'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dataCtrl,
                        readOnly: true,
                        decoration: _dec(
                          'Data da concretagem *',
                          icon: Icons.event_outlined,
                        ),
                        onTap: _selecionarData,
                        validator: (_) => _dataConcretagem == null
                            ? tr('Informe a data da concretagem.')
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _horaCtrl,
                        readOnly: true,
                        decoration: _dec(
                          'Horário previsto de início *',
                          icon: Icons.schedule_outlined,
                        ),
                        onTap: _selecionarHora,
                        validator: (_) => _horaInicio == null
                            ? tr('Informe o horario previsto.')
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _volumeCtrl,
                        decoration: _dec(
                          'Volume estimado (m³)',
                          icon: Icons.straighten_outlined,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                        ],
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) return null;
                          final volume = double.tryParse(
                            (value ?? '').trim().replaceAll(',', '.'),
                          );
                          if (volume == null || volume <= 0) {
                            return tr('Informe um volume valido.');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _estruturaCtrl,
                        decoration: _dec(
                          'Estrutura a ser concretada',
                          icon: Icons.foundation_outlined,
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _tracoCtrl,
                        decoration: _dec(
                          'Traço do concreto',
                          icon: Icons.format_list_bulleted_outlined,
                        ),
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 12),
                      _estimativaCwsCard(),
                      if (_agendamentoConcluido) ...[
                        const SizedBox(height: 12),
                        _agendamentoConcluidoCard(),
                      ],
                      const SizedBox(height: 20),
                      _formActionButtons(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
