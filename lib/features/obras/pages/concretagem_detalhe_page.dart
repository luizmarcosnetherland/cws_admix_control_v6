import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/email_compose_service.dart';
import '../../../core/services/obra_report_pdf_service.dart';
import '../../../data/models/concretagem_model.dart';
import '../../../data/models/lancamento_model.dart';
import '../../../data/models/obra_model.dart';
import '../../../data/repositories/concretagem_repository.dart';
import '../../../data/repositories/lancamento_repository.dart';
import 'concretagem_rastreio_page.dart';
import 'nova_concretagem_page.dart';
import 'novo_lancamento_page.dart';

enum _AcaoEncerrarConcretagem { cancelar, encerrar, gerarPdf }

class ConcretagemDetalhePage extends StatefulWidget {
  final Obra obra;
  final Concretagem concretagem;

  const ConcretagemDetalhePage({
    super.key,
    required this.obra,
    required this.concretagem,
  });

  @override
  State<ConcretagemDetalhePage> createState() => _ConcretagemDetalhePageState();
}

class _ConcretagemDetalhePageState extends State<ConcretagemDetalhePage> {
  final _repo = LancamentoRepository();
  final _concretagemRepo = ConcretagemRepository();
  final _pdfService = ObraReportPdfService();
  final _emailService = EmailComposeService();

  late Concretagem _concretagemAtual;
  bool _loading = true;
  bool _processandoRelatorio = false;
  List<Lancamento> _lancamentos = [];

  @override
  void initState() {
    super.initState();
    _concretagemAtual = widget.concretagem;
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final concretagemAtualizada = _concretagemAtual.id == null
          ? null
          : await _concretagemRepo.buscarPorId(_concretagemAtual.id!);
      final lista = await _repo.listarPorConcretagem(_concretagemAtual.id!);
      if (!mounted) return;
      setState(() {
        _concretagemAtual = concretagemAtualizada ?? _concretagemAtual;
        _lancamentos = lista;
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

  Future<void> _abrirNovoLancamento() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NovoLancamentoPage(
          obraNome: widget.obra.nome,
          concretagem: _concretagemAtual,
        ),
      ),
    );

    if (created == true) {
      await _carregar();
    }
  }

  Future<void> _editarConcretagem() async {
    final updated = await Navigator.of(context).push<Concretagem>(
      MaterialPageRoute(
        builder: (_) => NovaConcretagemPage(
          obraId: _concretagemAtual.obraId,
          obraNome: widget.obra.nome,
          concretagem: _concretagemAtual,
        ),
      ),
    );
    if (updated == null) return;
    setState(() => _concretagemAtual = updated);
    await _carregar();
  }

  Future<void> _editarLancamento(Lancamento lancamento) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NovoLancamentoPage(
          obraNome: widget.obra.nome,
          concretagem: _concretagemAtual,
          lancamento: lancamento,
        ),
      ),
    );
    if (updated == true) {
      await _carregar();
    }
  }

  Future<void> _abrirRastreio() async {
    final encerrou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ConcretagemRastreioPage(
          obraNome: widget.obra.nome,
          concretagem: _concretagemAtual,
          lancamentos: _lancamentos,
        ),
      ),
    );
    await _carregar();
    if (encerrou == true && mounted) {
      await _encerrarConcretagem();
    }
  }

  Future<void> _excluirLancamento(Lancamento lancamento) async {
    if (lancamento.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Excluir lançamento')),
        content: Text(
          tr(
            'Deseja excluir o lançamento da betoneira "{betoneira}"?',
            params: {'betoneira': lancamento.caminhao},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('Excluir')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repo.excluirLancamento(lancamento.id!);
      final rastreioAtualizado = _concretagemAtual.rastreioTracos
          .where((item) => item.lancamentoId != lancamento.id)
          .toList(growable: false);
      if (rastreioAtualizado.length !=
          _concretagemAtual.rastreioTracos.length) {
        _concretagemAtual = await _concretagemRepo.atualizarConcretagem(
          _concretagemAtual.copyWith(rastreioTracos: rastreioAtualizado),
        );
      }
      if (!mounted) return;
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Erro ao excluir lançamento: {error}', params: {'error': e}),
          ),
        ),
      );
    }
  }

  String _fmtNum(double value, {int casas = 1}) {
    return value.toStringAsFixed(casas).replaceAll('.', ',');
  }

  String _fmtDataHora(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _fallbackNaoInformado(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? tr('não informada') : trimmed;
  }

  String _controleTecnologicoLabel() {
    if (_concretagemAtual.controleTecnologico.trim().toLowerCase() == 'sim') {
      return tr('Sim');
    }
    return tr('não informado');
  }

  String _tituloConcretagem() {
    final estrutura = _concretagemAtual.estruturaConcretada.trim();
    if (estrutura.isNotEmpty) return estrutura;
    if (_concretagemAtual.id != null) {
      return tr('Concretagem {id}', params: {'id': _concretagemAtual.id});
    }
    return tr('Concretagem');
  }

  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _compartilharRelatorio() async {
    if (_processandoRelatorio) return;

    setState(() => _processandoRelatorio = true);
    try {
      await _pdfService.shareConcretagemReportPdf(
        obra: widget.obra,
        concretagem: _concretagemAtual,
        lancamentos: _lancamentos,
        sharePositionOrigin: _shareOrigin(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Erro ao gerar relatório da concretagem: {error}',
              params: {'error': e},
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processandoRelatorio = false);
      }
    }
  }

  Future<bool> _oferecerRelatorioEncerramento() async {
    final acao = await showDialog<_AcaoEncerrarConcretagem>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Encerrar concretagem')),
        content: Text(
          tr('Deseja gerar o PDF da concretagem antes de encerrar?'),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_AcaoEncerrarConcretagem.cancelar),
            child: Text(tr('Cancelar')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_AcaoEncerrarConcretagem.encerrar),
            child: Text(tr('Encerrar sem PDF')),
          ),
          FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).pop(_AcaoEncerrarConcretagem.gerarPdf),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(tr('Gerar PDF')),
          ),
        ],
      ),
    );

    if (acao == null || acao == _AcaoEncerrarConcretagem.cancelar) {
      return false;
    }

    if (acao == _AcaoEncerrarConcretagem.gerarPdf) {
      await _compartilharRelatorio();
    }

    return mounted;
  }

  Future<void> _encerrarConcretagem() async {
    if (_processandoRelatorio) return;

    final encerrar = await _oferecerRelatorioEncerramento();
    if (!encerrar || !mounted) return;

    Navigator.of(context).pop(true);
  }

  Future<void> _enviarRelatorioPorEmail() async {
    final emailDestino = widget.obra.emailEngenheiro.trim();
    if (emailDestino.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Cadastre o e-mail do engenheiro na obra antes de enviar.'),
          ),
        ),
      );
      return;
    }
    if (_processandoRelatorio) return;

    setState(() => _processandoRelatorio = true);
    try {
      final pdfPath = await _pdfService.buildConcretagemReportPdf(
        obra: widget.obra,
        concretagem: _concretagemAtual,
        lancamentos: _lancamentos,
      );
      final assunto = tr(
        'Relatório da concretagem {concretagem}',
        params: {'concretagem': _tituloConcretagem()},
      );
      final body = [
        tr(
          'Segue em anexo o relatório da concretagem {concretagem} da obra {obra}.',
          params: {
            'concretagem': _tituloConcretagem(),
            'obra': widget.obra.nome,
          },
        ),
        '',
        tr('Lançamentos: {count}', params: {'count': _lancamentos.length}),
        tr(
          'Volume total: {value} m3',
          params: {'value': _fmtNum(_volumeTotal, casas: 1)},
        ),
        tr(
          'CWS total: {value} kg',
          params: {'value': _fmtNum(_cwsTotal, casas: 1)},
        ),
      ].join('\n');

      await _emailService.composeEmail(
        recipients: [emailDestino],
        subject: assunto,
        body: body,
        attachmentPaths: [pdfPath],
        sharePositionOrigin: _shareOrigin(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'E-mail preparado para {email}',
              params: {'email': emailDestino},
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Erro ao enviar relatório por e-mail: {error}',
              params: {'error': e},
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processandoRelatorio = false);
      }
    }
  }

  double get _volumeTotal =>
      _lancamentos.fold(0.0, (total, item) => total + item.volumeM3);

  double get _cwsTotal =>
      _lancamentos.fold(0.0, (total, item) => total + item.cwsTotalKg);

  bool get _plantaDisponivel {
    final path = _concretagemAtual.plantaPath.trim();
    return path.isNotEmpty && File(path).existsSync();
  }

  Set<int> get _lancamentosMarcados {
    final ids = _lancamentos.map((item) => item.id).whereType<int>().toSet();
    return _concretagemAtual.rastreioTracos
        .map((item) => item.lancamentoId)
        .where(ids.contains)
        .toSet();
  }

  bool _lancamentoTemRastreio(int? lancamentoId) {
    if (lancamentoId == null) return false;
    return _concretagemAtual.rastreioTracos.any(
      (item) => item.lancamentoId == lancamentoId,
    );
  }

  String _resumoRastreio() {
    if (!_plantaDisponivel) {
      return tr('Planta ainda não cadastrada para esta concretagem.');
    }
    if (_lancamentos.isEmpty) {
      return tr(
        'Planta salva. Adicione lançamentos para começar as marcações.',
      );
    }
    return tr(
      '{marked} de {total} lançamentos já foram marcados na planta.',
      params: {
        'marked': _lancamentosMarcados.length,
        'total': _lancamentos.length,
      },
    );
  }

  Widget _resumoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.obra.nome,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                'Estrutura: {value}',
                params: {
                  'value': _fallbackNaoInformado(
                    _concretagemAtual.estruturaConcretada,
                  ),
                },
              ),
            ),
            Text(
              tr(
                'Concreteira: {value}',
                params: {
                  'value': _fallbackNaoInformado(_concretagemAtual.concreteira),
                },
              ),
            ),
            Text(
              tr(
                'Controle tecnológico: {value}',
                params: {'value': _controleTecnologicoLabel()},
              ),
            ),
            Text(
              tr(
                'Empresa de tecnologia do concreto: {value}',
                params: {
                  'value':
                      _concretagemAtual.controleTecnologico
                              .trim()
                              .toLowerCase() ==
                          'sim'
                      ? _fallbackNaoInformado(
                          _concretagemAtual.empresaTecnologiaConcreto,
                        )
                      : tr('não informada'),
                },
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _tag(
                  tr(
                    'Lançamentos: {count}',
                    params: {'count': _lancamentos.length},
                  ),
                ),
                _tag(
                  tr(
                    'Volume: {value} m³',
                    params: {'value': _fmtNum(_volumeTotal)},
                  ),
                ),
                _tag(
                  tr('CWS: {value} kg', params: {'value': _fmtNum(_cwsTotal)}),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _processandoRelatorio
                      ? null
                      : _compartilharRelatorio,
                  icon: _processandoRelatorio
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    _processandoRelatorio
                        ? tr('Gerando relatório...')
                        : tr('Relatório da concretagem'),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _processandoRelatorio
                      ? null
                      : _enviarRelatorioPorEmail,
                  icon: const Icon(Icons.email_outlined),
                  label: Text(tr('Enviar por e-mail')),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.draw_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('Rastreio na planta'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (_plantaDisponivel)
                  _tag('${_lancamentosMarcados.length}/${_lancamentos.length}'),
              ],
            ),
            const SizedBox(height: 8),
            Text(_resumoRastreio()),
            if (_plantaDisponivel) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_concretagemAtual.plantaPath),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 150,
                    alignment: Alignment.center,
                    color: Colors.black.withValues(alpha: 0.04),
                    child: Text(tr('Pré-visualização indisponível')),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _abrirRastreio,
                icon: const Icon(Icons.draw_outlined),
                label: Text(
                  _plantaDisponivel
                      ? tr('Abrir rastreio da planta')
                      : tr('Escanear ou importar planta'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _listaLancamentos() {
    if (_lancamentos.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const Icon(Icons.local_shipping_outlined, size: 30),
              const SizedBox(height: 8),
              Text(
                tr('Nenhum lançamento cadastrado nesta concretagem.'),
                style: const TextStyle(fontWeight: FontWeight.w600),
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
      itemCount: _lancamentos.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final l = _lancamentos[index];
        final status = l.dosagemDeAcordo == null
            ? ''
            : (l.dosagemDeAcordo == 1 ? '✅' : '⚠️');
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.local_shipping)),
            title: Text(
              l.caminhao.isEmpty
                  ? tr('Betoneira sem identificação')
                  : l.caminhao,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fmtDataHora(l.dataHora)),
                if (l.notaFiscal.isNotEmpty)
                  Text(tr('NF: {value}', params: {'value': l.notaFiscal})),
                Text(
                  tr(
                    'Volume: {value} m³',
                    params: {'value': _fmtNum(l.volumeM3)},
                  ),
                ),
                Text(
                  tr(
                    'Dosagem: {value} kg/m³',
                    params: {'value': _fmtNum(l.dosagemKgM3)},
                  ),
                ),
                Text(
                  tr(
                    'CWS: {value} kg',
                    params: {'value': _fmtNum(l.cwsTotalKg)},
                  ),
                ),
                if (l.cwsAdicionadoKg != null)
                  Text(
                    tr(
                      'CWS adicionado: {value} kg',
                      params: {'value': _fmtNum(l.cwsAdicionadoKg!)},
                    ),
                  ),
                if (l.slumpAntes != null)
                  Text(
                    tr(
                      'Slump antes: {value} cm',
                      params: {'value': _fmtNum(l.slumpAntes!)},
                    ),
                  ),
                if (l.slumpDepois != null)
                  Text(
                    tr(
                      'Slump depois: {value} cm',
                      params: {'value': _fmtNum(l.slumpDepois!)},
                    ),
                  ),
                if (l.tempoMisturaMin != null)
                  Text(
                    tr(
                      'Mistura: {value} min',
                      params: {'value': _fmtNum(l.tempoMisturaMin!)},
                    ),
                  ),
                if (_lancamentoTemRastreio(l.id))
                  Text(tr('Rastreio na planta: marcado')),
                if (l.observacoes.isNotEmpty)
                  Text(tr('Obs.: {value}', params: {'value': l.observacoes})),
                if (l.fotoPaths.isNotEmpty)
                  Text(
                    tr(
                      'Fotos anexas: {count}',
                      params: {'count': l.fotoPaths.length},
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(status, style: const TextStyle(fontSize: 18)),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'editar') {
                      await _editarLancamento(l);
                    }
                    if (value == 'excluir') {
                      await _excluirLancamento(l);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'editar', child: Text(tr('Editar'))),
                    PopupMenuItem(value: 'excluir', child: Text(tr('Excluir'))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Concretagem')),
        actions: [
          IconButton(
            tooltip: context.tr('Gerar PDF da concretagem'),
            onPressed: _processandoRelatorio ? null : _compartilharRelatorio,
            icon: _processandoRelatorio
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: context.tr('Editar concretagem'),
            onPressed: _editarConcretagem,
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
                    _listaLancamentos(),
                    const SizedBox(height: 128),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _abrirNovoLancamento,
                icon: const Icon(Icons.add),
                label: Text(context.tr('Adicionar')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _encerrarConcretagem,
                icon: const Icon(Icons.task_alt_outlined),
                label: Text(context.tr('Encerrar')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
