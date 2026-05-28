import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/csv_export_service.dart';
import '../../../core/services/obra_location_service.dart';
import '../../../data/models/concretagem_model.dart';
import '../../../data/models/lancamento_model.dart';
import '../../../data/models/obra_model.dart';
import '../../../data/repositories/concretagem_repository.dart';
import '../../../data/repositories/lancamento_repository.dart';
import 'concretagem_detalhe_page.dart';
import 'editar_obra_page.dart';
import 'nova_concretagem_page.dart';

enum _PeriodoFiltro { todos, hoje, ultimos7, ultimos30, personalizado }

enum _Ordenacao {
  dataDesc,
  dataAsc,
  volumeDesc,
  volumeAsc,
  cwsDesc,
  cwsAsc,
  betoneiraAsc,
  concreteiraAsc,
}

class ObraDetalhePage extends StatefulWidget {
  final Obra obra;

  const ObraDetalhePage({super.key, required this.obra});

  @override
  State<ObraDetalhePage> createState() => _ObraDetalhePageState();
}

class _ObraDetalhePageState extends State<ObraDetalhePage> {
  final _repo = LancamentoRepository();
  final _concretagemRepo = ConcretagemRepository();
  final CsvExportService _csv = CsvExportService();
  final ObraLocationService _locationService = ObraLocationService();

  late Obra _obraAtual;

  bool _loading = true;

  // Base (filtrado só por período, vindo do DB)
  List<Lancamento> _base = [];

  // Resultado final (período + filtros extras + ordenação)
  List<Lancamento> _filtrado = [];
  List<Concretagem> _concretagens = [];

  ResumoLancamentosObra _resumo = const ResumoLancamentosObra(
    quantidade: 0,
    volumeTotalM3: 0,
    cwsTotalKg: 0,
  );

  // Filtro de período
  _PeriodoFiltro _periodo = _PeriodoFiltro.todos;
  DateTimeRange? _rangePersonalizado;

  // Filtros extras
  String? _filtroConcreteira; // null = todas
  String? _filtroBetoneira; // null = todas
  final TextEditingController _buscaCtrl = TextEditingController();
  bool _filtrosExpandidos = false;
  Timer? _buscaDebounce;

  // Ordenação
  _Ordenacao _ordenacao = _Ordenacao.dataDesc;
  List<String> _opcoesConcreteiraCache = const [];
  List<String> _opcoesBetoneiraCache = const [];

  @override
  void initState() {
    super.initState();
    _obraAtual = widget.obra;
    _buscaCtrl.addListener(() {
      _buscaDebounce?.cancel();
      _buscaDebounce = Timer(const Duration(milliseconds: 180), () {
        if (mounted) setState(_aplicarFiltros);
      });
    });
    _carregar();
  }

  @override
  void dispose() {
    _buscaDebounce?.cancel();
    _buscaCtrl.dispose();
    super.dispose();
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  (DateTime? inicio, DateTime? fimExclusivo) _intervaloAtual() {
    final now = DateTime.now();
    final today = _startOfDay(now);

    switch (_periodo) {
      case _PeriodoFiltro.todos:
        return (null, null);
      case _PeriodoFiltro.hoje:
        return (today, today.add(const Duration(days: 1)));
      case _PeriodoFiltro.ultimos7:
        return (
          today.subtract(const Duration(days: 6)),
          today.add(const Duration(days: 1)),
        );
      case _PeriodoFiltro.ultimos30:
        return (
          today.subtract(const Duration(days: 29)),
          today.add(const Duration(days: 1)),
        );
      case _PeriodoFiltro.personalizado:
        final r = _rangePersonalizado;
        if (r == null) return (null, null);
        final ini = _startOfDay(r.start);
        final fim = _startOfDay(r.end).add(const Duration(days: 1));
        return (ini, fim);
    }
  }

  String _labelPeriodo() {
    String ddmm(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

    switch (_periodo) {
      case _PeriodoFiltro.todos:
        return tr('Todos');
      case _PeriodoFiltro.hoje:
        return tr('Hoje');
      case _PeriodoFiltro.ultimos7:
        return '7d';
      case _PeriodoFiltro.ultimos30:
        return '30d';
      case _PeriodoFiltro.personalizado:
        final r = _rangePersonalizado;
        if (r == null) return tr('Período');
        return '${ddmm(r.start)}–${ddmm(r.end)}';
    }
  }

  String _labelOrdenacao() {
    switch (_ordenacao) {
      case _Ordenacao.dataDesc:
        return tr('Data (recente→antigo)');
      case _Ordenacao.dataAsc:
        return tr('Data (antigo→recente)');
      case _Ordenacao.volumeDesc:
        return tr('Volume (maior→menor)');
      case _Ordenacao.volumeAsc:
        return tr('Volume (menor→maior)');
      case _Ordenacao.cwsDesc:
        return tr('CWS (maior→menor)');
      case _Ordenacao.cwsAsc:
        return tr('CWS (menor→maior)');
      case _Ordenacao.betoneiraAsc:
        return tr('Betoneira (A→Z)');
      case _Ordenacao.concreteiraAsc:
        return tr('Concreteira (A→Z)');
    }
  }

  List<String> _opcoesConcreteira() => _opcoesConcreteiraCache;

  List<String> _opcoesBetoneira() => _opcoesBetoneiraCache;

  String _norm(String s) => s.toLowerCase().trim();

  bool _matchBusca(Lancamento l, String q) {
    if (q.isEmpty) return true;
    final hay = [
      l.caminhao,
      l.estruturaConcretada,
      l.concreteira,
      l.empresaTecnologiaConcreto,
      l.notaFiscal,
      l.observacoes,
    ].join(' ');
    return _norm(hay).contains(q);
  }

  int _cmpStr(String a, String b) => _norm(a).compareTo(_norm(b));

  void _ordenar(List<Lancamento> list) {
    switch (_ordenacao) {
      case _Ordenacao.dataDesc:
        list.sort((a, b) => b.dataHora.compareTo(a.dataHora));
        return;
      case _Ordenacao.dataAsc:
        list.sort((a, b) => a.dataHora.compareTo(b.dataHora));
        return;
      case _Ordenacao.volumeDesc:
        list.sort((a, b) => b.volumeM3.compareTo(a.volumeM3));
        return;
      case _Ordenacao.volumeAsc:
        list.sort((a, b) => a.volumeM3.compareTo(b.volumeM3));
        return;
      case _Ordenacao.cwsDesc:
        list.sort((a, b) => b.cwsTotalKg.compareTo(a.cwsTotalKg));
        return;
      case _Ordenacao.cwsAsc:
        list.sort((a, b) => a.cwsTotalKg.compareTo(b.cwsTotalKg));
        return;
      case _Ordenacao.betoneiraAsc:
        list.sort((a, b) => _cmpStr(a.caminhao, b.caminhao));
        return;
      case _Ordenacao.concreteiraAsc:
        list.sort((a, b) => _cmpStr(a.concreteira, b.concreteira));
        return;
    }
  }

  void _aplicarFiltros() {
    final q = _norm(_buscaCtrl.text);

    final out = _base.where((l) {
      if (_filtroConcreteira != null &&
          _norm(l.concreteira) != _norm(_filtroConcreteira!)) {
        return false;
      }
      if (_filtroBetoneira != null &&
          _norm(l.caminhao) != _norm(_filtroBetoneira!)) {
        return false;
      }
      if (!_matchBusca(l, q)) return false;
      return true;
    }).toList();

    _ordenar(out);

    double vol = 0;
    double cws = 0;
    for (final l in out) {
      vol += l.volumeM3;
      cws += l.cwsTotalKg;
    }

    _filtrado = out;
    _resumo = ResumoLancamentosObra(
      quantidade: out.length,
      volumeTotalM3: vol,
      cwsTotalKg: cws,
    );
  }

  bool get _temFiltrosExtras =>
      _filtroConcreteira != null ||
      _filtroBetoneira != null ||
      _buscaCtrl.text.trim().isNotEmpty;

  int get _quantidadeFiltrosExtrasAtivos {
    var total = 0;
    if (_filtroConcreteira != null) total++;
    if (_filtroBetoneira != null) total++;
    if (_buscaCtrl.text.trim().isNotEmpty) total++;
    return total;
  }

  void _limparFiltrosExtras() {
    setState(() {
      _filtroConcreteira = null;
      _filtroBetoneira = null;
      _buscaCtrl.clear();
      _aplicarFiltros();
    });
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final (inicio, fimExclusivo) = _intervaloAtual();

      final lista = await _repo.listarPorObra(
        _obraAtual.id!,
        inicio: inicio,
        fimExclusivo: fimExclusivo,
      );
      final concretagens = await _concretagemRepo.listarPorObra(_obraAtual.id!);

      if (!mounted) return;
      setState(() {
        _base = lista;
        _concretagens = concretagens;
        _opcoesConcreteiraCache =
            concretagens
                .map((item) => item.concreteira.trim())
                .where((item) => item.isNotEmpty)
                .toSet()
                .toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _opcoesBetoneiraCache = _buildFilterOptions(
          lista,
          selector: (l) => l.caminhao,
        );

        // Se o filtro selecionado sumiu no período, reseta.
        final concs = _opcoesConcreteiraCache.map(_norm).toSet();
        final bets = _opcoesBetoneiraCache.map(_norm).toSet();

        if (_filtroConcreteira != null &&
            !concs.contains(_norm(_filtroConcreteira!))) {
          _filtroConcreteira = null;
        }
        if (_filtroBetoneira != null &&
            !bets.contains(_norm(_filtroBetoneira!))) {
          _filtroBetoneira = null;
        }

        _aplicarFiltros();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Erro ao carregar lançamentos: {error}', params: {'error': e}),
          ),
        ),
      );
    }
  }

  List<String> _buildFilterOptions(
    List<Lancamento> lancamentos, {
    required String Function(Lancamento lancamento) selector,
  }) {
    final values = <String>{};
    for (final lancamento in lancamentos) {
      final value = selector(lancamento).trim();
      if (value.isNotEmpty) values.add(value);
    }
    final list = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  Map<int, List<Lancamento>> _lancamentosPorConcretagem() {
    final grouped = <int, List<Lancamento>>{};
    for (final lancamento in _filtrado) {
      grouped.putIfAbsent(lancamento.concretagemId, () => []).add(lancamento);
    }
    return grouped;
  }

  List<Concretagem> _concretagensVisiveis() {
    final grouped = _lancamentosPorConcretagem();
    final possuiRestricao =
        _periodo != _PeriodoFiltro.todos || _temFiltrosExtras;
    if (!possuiRestricao) return _concretagens;
    return _concretagens
        .where((concretagem) => grouped.containsKey(concretagem.id))
        .toList();
  }

  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _editarObra() async {
    final updated = await Navigator.of(context).push<Obra>(
      MaterialPageRoute(builder: (_) => EditarObraPage(obra: _obraAtual)),
    );

    if (updated != null) {
      setState(() => _obraAtual = updated);
    }
  }

  String _exportLabelAtual() {
    final parts = <String>[];
    parts.add('periodo_${_labelPeriodo()}');
    parts.add('ord_${_labelOrdenacao()}');

    if (_filtroConcreteira != null) parts.add('conc_${_filtroConcreteira!}');
    if (_filtroBetoneira != null) parts.add('bet_${_filtroBetoneira!}');
    final q = _buscaCtrl.text.trim();
    if (q.isNotEmpty) parts.add('q_$q');

    return parts.join('_');
  }

  Future<void> _exportarCsv() async {
    try {
      final path = await _csv.exportLancamentosToDownloads(
        obra: _obraAtual,
        lancamentos: _filtrado,
        exportLabel: _exportLabelAtual(),
      );
      if (!mounted) return;

      if (Platform.isIOS) {
        final origin = _shareOrigin();
        await Share.shareXFiles(
          [XFile(path)],
          subject: tr(
            'Relatório CSV da obra {obra}',
            params: {'obra': _obraAtual.nome},
          ),
          text: tr(
            'Relatório CSV da obra {obra}. Toque em "Salvar em Arquivos" para escolher onde guardar.',
            params: {'obra': _obraAtual.nome},
          ),
          sharePositionOrigin: origin,
        );
        if (!mounted) return;
      }

      if (Platform.isAndroid) {
        final origin = _shareOrigin();
        await Share.shareXFiles(
          [XFile(path)],
          subject: tr(
            'Relatório CSV da obra {obra}',
            params: {'obra': _obraAtual.nome},
          ),
          text: tr(
            'CSV da obra {obra}. Use "Salvar em Arquivos" ou sua nuvem preferida.',
            params: {'obra': _obraAtual.nome},
          ),
          sharePositionOrigin: origin,
        );
        if (!mounted) return;
      }

      if (Platform.isMacOS) {
        await Process.run('open', ['-R', path]);
        if (!mounted) return;
      }

      final message = Platform.isIOS
          ? tr(
              'CSV pronto para exportacao ({count} linhas). Use "Salvar em Arquivos".',
              params: {'count': _filtrado.length},
            )
          : Platform.isAndroid
          ? tr(
              'CSV pronto para compartilhar ({count} linhas).',
              params: {'count': _filtrado.length},
            )
          : tr(
              'CSV exportado ({count} linhas): {path}',
              params: {'count': _filtrado.length, 'path': path},
            );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Erro ao exportar CSV: {error}', params: {'error': e}),
          ),
        ),
      );
    }
  }

  Future<void> _selecionarPeriodo(_PeriodoFiltro p) async {
    if (p != _PeriodoFiltro.personalizado) {
      setState(() {
        _periodo = p;
        if (p != _PeriodoFiltro.personalizado) _rangePersonalizado = null;
      });
      await _carregar();
      return;
    }

    final now = DateTime.now();
    final initial =
        _rangePersonalizado ??
        DateTimeRange(
          start: _startOfDay(now).subtract(const Duration(days: 6)),
          end: _startOfDay(now),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDateRange: initial,
      helpText: tr('Selecionar período'),
      saveText: tr('Aplicar'),
      cancelText: tr('Cancelar'),
      locale: CwsLocalizations.current.locale,
    );

    if (!mounted) return;

    if (picked == null) {
      if (_rangePersonalizado == null) {
        setState(() => _periodo = _PeriodoFiltro.todos);
      }
      return;
    }

    setState(() {
      _periodo = _PeriodoFiltro.personalizado;
      _rangePersonalizado = picked;
    });
    await _carregar();
  }

  Future<void> _abrirConcretagem(Concretagem concretagem) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ConcretagemDetalhePage(obra: _obraAtual, concretagem: concretagem),
      ),
    );
    await _carregar();
  }

  Future<void> _abrirNovaConcretagem() async {
    final concretagem = await Navigator.of(context).push<Concretagem>(
      MaterialPageRoute(
        builder: (_) => NovaConcretagemPage(
          obraId: _obraAtual.id!,
          obraNome: _obraAtual.nome,
        ),
      ),
    );

    if (concretagem == null) return;
    if (!mounted) return;
    await _abrirConcretagem(concretagem);
  }

  String _fmtDataHora(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _fmtNum(double v, {int casas = 1}) {
    return v.toStringAsFixed(casas).replaceAll('.', ',');
  }

  Future<void> _abrirNoMapa() async {
    final latitude = _obraAtual.latitude;
    final longitude = _obraAtual.longitude;
    if (latitude == null || longitude == null) return;

    try {
      await _locationService.abrirNoMapa(
        latitude: latitude,
        longitude: longitude,
        label: _obraAtual.nome,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Erro ao abrir mapa: {error}', params: {'error': e}),
          ),
        ),
      );
    }
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text),
    );
  }

  Widget _resumoCard() {
    final obra = _obraAtual;

    final filtros = <Widget>[
      _tag(tr('Período: {value}', params: {'value': _labelPeriodo()})),
      _tag(tr('Ordem: {value}', params: {'value': _labelOrdenacao()})),
      if (_filtroConcreteira != null)
        _tag(tr('Concreteira: {value}', params: {'value': _filtroConcreteira})),
      if (_filtroBetoneira != null)
        _tag(tr('Betoneira: {value}', params: {'value': _filtroBetoneira})),
      if (_buscaCtrl.text.trim().isNotEmpty)
        _tag(tr('Busca: {value}', params: {'value': _buscaCtrl.text.trim()})),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              obra.nome,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (obra.cliente.isNotEmpty)
              Text(tr('Cliente: {value}', params: {'value': obra.cliente})),
            if (obra.local.isNotEmpty)
              Text(tr('Local: {value}', params: {'value': obra.local})),
            if (obra.localizacaoDescricao.isNotEmpty) ...[
              Text(
                tr(
                  'Localizacao da obra: {value}',
                  params: {'value': obra.localizacaoDescricao},
                ),
              ),
              if (obra.latitude != null && obra.longitude != null)
                Text(
                  tr(
                    'Coordenadas: {value}',
                    params: {
                      'value':
                          '${obra.latitude!.toStringAsFixed(6)}, ${obra.longitude!.toStringAsFixed(6)}',
                    },
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _abrirNoMapa,
                icon: const Icon(Icons.map_outlined),
                label: Text(tr('Abrir no mapa')),
              ),
            ],
            if (obra.responsavel.isNotEmpty)
              Text(
                tr('Responsável: {value}', params: {'value': obra.responsavel}),
              ),
            if (obra.emailEngenheiro.isNotEmpty)
              Text(
                tr(
                  'E-mail engenheiro: {value}',
                  params: {'value': obra.emailEngenheiro},
                ),
              ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: filtros),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _tag(
                  tr(
                    'Lançamentos: {count}',
                    params: {'count': _resumo.quantidade},
                  ),
                ),
                _tag(
                  tr(
                    'Volume: {value} m³',
                    params: {'value': _fmtNum(_resumo.volumeTotalM3, casas: 1)},
                  ),
                ),
                _tag(
                  tr(
                    'CWS: {value} kg',
                    params: {'value': _fmtNum(_resumo.cwsTotalKg, casas: 1)},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtrosPeriodo() {
    ChoiceChip chip(String label, _PeriodoFiltro value) {
      final selected = _periodo == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _selecionarPeriodo(value),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(tr('Todos'), _PeriodoFiltro.todos),
          const SizedBox(width: 8),
          chip(tr('Hoje'), _PeriodoFiltro.hoje),
          const SizedBox(width: 8),
          chip('7d', _PeriodoFiltro.ultimos7),
          const SizedBox(width: 8),
          chip('30d', _PeriodoFiltro.ultimos30),
          const SizedBox(width: 8),
          chip(_labelPeriodo(), _PeriodoFiltro.personalizado),
        ],
      ),
    );
  }

  Widget _filtrosExtras() {
    final concs = _opcoesConcreteira();
    final bets = _opcoesBetoneira();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _filtrosExpandidos = !_filtrosExpandidos;
                      });
                    },
                    icon: Icon(
                      _filtrosExpandidos
                          ? Icons.filter_alt_off_outlined
                          : Icons.filter_alt_outlined,
                    ),
                    label: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _temFiltrosExtras
                            ? 'Filtros ($_quantidadeFiltrosExtrasAtivos ativos)'
                            : 'Filtros',
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _filtrosExpandidos
                      ? 'Recolher filtros'
                      : 'Expandir filtros',
                  onPressed: () {
                    setState(() {
                      _filtrosExpandidos = !_filtrosExpandidos;
                    });
                  },
                  icon: Icon(
                    _filtrosExpandidos
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _filtroConcreteira,
                        decoration: InputDecoration(
                          labelText: tr('Concreteira'),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(tr('Todas')),
                          ),
                          ...concs.map(
                            (v) => DropdownMenuItem<String?>(
                              value: v,
                              child: Text(v),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _filtroConcreteira = v;
                            _aplicarFiltros();
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _filtroBetoneira,
                        decoration: InputDecoration(
                          labelText: tr('Betoneira (nº/placa)'),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(tr('Todas')),
                          ),
                          ...bets.map(
                            (v) => DropdownMenuItem<String?>(
                              value: v,
                              child: Text(v),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _filtroBetoneira = v;
                            _aplicarFiltros();
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: TextField(
                        controller: _buscaCtrl,
                        decoration: InputDecoration(
                          labelText: tr(
                            'Busca (betoneira, concreteira, NF, obs)',
                          ),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _buscaCtrl.text.trim().isEmpty
                              ? null
                              : IconButton(
                                  tooltip: tr('Limpar busca'),
                                  onPressed: () {
                                    _buscaCtrl.clear();
                                    setState(_aplicarFiltros);
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: DropdownButtonFormField<_Ordenacao>(
                        initialValue: _ordenacao,
                        decoration: InputDecoration(
                          labelText: tr('Ordenação'),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: _Ordenacao.dataDesc,
                            child: Text(tr('Data (recente→antigo)')),
                          ),
                          DropdownMenuItem(
                            value: _Ordenacao.dataAsc,
                            child: Text(tr('Data (antigo→recente)')),
                          ),
                          DropdownMenuItem(
                            value: _Ordenacao.volumeDesc,
                            child: Text(tr('Volume (maior→menor)')),
                          ),
                          DropdownMenuItem(
                            value: _Ordenacao.volumeAsc,
                            child: Text(tr('Volume (menor→maior)')),
                          ),
                          DropdownMenuItem(
                            value: _Ordenacao.cwsDesc,
                            child: Text(tr('CWS (maior→menor)')),
                          ),
                          DropdownMenuItem(
                            value: _Ordenacao.cwsAsc,
                            child: Text(tr('CWS (menor→maior)')),
                          ),
                          DropdownMenuItem(
                            value: _Ordenacao.betoneiraAsc,
                            child: Text(tr('Betoneira (A→Z)')),
                          ),
                          DropdownMenuItem(
                            value: _Ordenacao.concreteiraAsc,
                            child: Text(tr('Concreteira (A→Z)')),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _ordenacao = v;
                            _aplicarFiltros();
                          });
                        },
                      ),
                    ),
                    if (_temFiltrosExtras)
                      TextButton.icon(
                        onPressed: _limparFiltrosExtras,
                        icon: const Icon(Icons.filter_alt_off),
                        label: Text(tr('Limpar filtros')),
                      ),
                  ],
                ),
              ),
              crossFadeState: _filtrosExpandidos
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listaConcretagens() {
    final grouped = _lancamentosPorConcretagem();
    final concretagens = _concretagensVisiveis();

    if (concretagens.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const Icon(Icons.foundation_outlined, size: 30),
              const SizedBox(height: 8),
              Text(
                tr('Nenhuma concretagem com os filtros atuais.'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  'Ajuste o período/filtros ou adicione uma nova concretagem.',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: concretagens.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final concretagem = concretagens[index];
        final lancamentos = grouped[concretagem.id] ?? const <Lancamento>[];
        final volume = lancamentos.fold<double>(
          0,
          (total, item) => total + item.volumeM3,
        );
        final cws = lancamentos.fold<double>(
          0,
          (total, item) => total + item.cwsTotalKg,
        );
        final ultimoLancamento = lancamentos.isEmpty
            ? null
            : lancamentos
                  .map((item) => item.dataHora)
                  .reduce((a, b) => a.isAfter(b) ? a : b);
        final controle =
            concretagem.controleTecnologico.trim().toLowerCase() == 'sim'
            ? tr('Sim')
            : tr('Não informado');
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.foundation_outlined)),
            title: Text(
              concretagem.estruturaConcretada.trim().isEmpty
                  ? tr('Estrutura não informada')
                  : concretagem.estruturaConcretada,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    'Concreteira: {value}',
                    params: {
                      'value': concretagem.concreteira.trim().isEmpty
                          ? tr('não informada')
                          : concretagem.concreteira,
                    },
                  ),
                ),
                Text(
                  tr(
                    'Controle tecnológico: {value}',
                    params: {'value': controle},
                  ),
                ),
                Text(
                  tr(
                    'Empresa tecnologia: {value}',
                    params: {
                      'value':
                          concretagem.controleTecnologico
                                      .trim()
                                      .toLowerCase() ==
                                  'sim' &&
                              concretagem.empresaTecnologiaConcreto
                                  .trim()
                                  .isNotEmpty
                          ? concretagem.empresaTecnologiaConcreto
                          : tr('não informada'),
                    },
                  ),
                ),
                Text(
                  tr(
                    'Lançamentos: {count}',
                    params: {'count': lancamentos.length},
                  ),
                ),
                Text(
                  tr(
                    'Volume: {value} m³',
                    params: {'value': _fmtNum(volume, casas: 1)},
                  ),
                ),
                Text(
                  tr(
                    'CWS: {value} kg',
                    params: {'value': _fmtNum(cws, casas: 1)},
                  ),
                ),
                if (ultimoLancamento != null)
                  Text(
                    tr(
                      'Último lançamento: {date}',
                      params: {'date': _fmtDataHora(ultimoLancamento)},
                    ),
                  ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _abrirConcretagem(concretagem),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Obra')),
        actions: [
          IconButton(
            tooltip: context.tr('Salvar ou compartilhar CSV'),
            onPressed: _exportarCsv,
            icon: const Icon(Icons.table_chart_outlined),
          ),
          IconButton(
            tooltip: context.tr('Editar obra'),
            onPressed: _editarObra,
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _carregar,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _resumoCard(),
                    const SizedBox(height: 10),
                    _filtrosPeriodo(),
                    const SizedBox(height: 10),
                    _filtrosExtras(),
                    const SizedBox(height: 10),
                    _listaConcretagens(),
                    const SizedBox(height: 128),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _abrirNovaConcretagem,
            icon: const Icon(Icons.add),
            label: Text(context.tr('Nova Concretagem')),
          ),
        ),
      ),
    );
  }
}
