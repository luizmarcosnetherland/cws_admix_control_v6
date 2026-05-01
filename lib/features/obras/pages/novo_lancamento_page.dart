import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:path/path.dart' as p;

import '../../../core/services/local_storage_service.dart';
import '../../../core/services/nota_fiscal_ocr_service.dart';
import '../../../data/models/concretagem_model.dart';
import '../../../data/models/lancamento_model.dart';
import '../../../data/repositories/lancamento_repository.dart';

class NovoLancamentoPage extends StatefulWidget {
  final String obraNome;
  final Concretagem concretagem;
  final Lancamento? lancamento; // null = novo | != null = edição

  const NovoLancamentoPage({
    super.key,
    required this.obraNome,
    required this.concretagem,
    this.lancamento,
  });

  @override
  State<NovoLancamentoPage> createState() => _NovoLancamentoPageState();
}

class _NovoLancamentoPageState extends State<NovoLancamentoPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = LancamentoRepository();
  final _storage = LocalStorageService();
  final _imagePicker = ImagePicker();
  final _notaFiscalOcr = NotaFiscalOcrService();

  final _betoneiraCtrl = TextEditingController();
  final _notaFiscalCtrl = TextEditingController();

  final _volumeCtrl = TextEditingController();
  final _dosagemCtrl = TextEditingController();
  final _cwsAdicionadoCtrl = TextEditingController();

  final _slumpAntesCtrl = TextEditingController();
  final _slumpDepoisCtrl = TextEditingController();
  final _tempoMisturaCtrl = TextEditingController();

  final _obsCtrl = TextEditingController();
  final _volumeFocusNode = FocusNode();
  final _dosagemFocusNode = FocusNode();
  final _cwsAdicionadoFocusNode = FocusNode();
  final _slumpAntesFocusNode = FocusNode();
  final _slumpDepoisFocusNode = FocusNode();
  final _tempoMisturaFocusNode = FocusNode();
  final _obsFocusNode = FocusNode();
  List<String> _fotoPaths = [];

  late final DateTime _dataHora;
  late final Listenable _previewListenable;
  bool _saving = false;
  bool _pickingFotos = false;
  bool _scanningNotaFiscal = false;
  String? _notaFiscalOcrAviso;

  bool get _isEdicao => widget.lancamento != null;

  @override
  void initState() {
    super.initState();

    final l = widget.lancamento;
    _dataHora = l?.dataHora ?? DateTime.now();

    _betoneiraCtrl.text = l?.caminhao ?? '';
    _notaFiscalCtrl.text = l?.notaFiscal ?? '';

    _volumeCtrl.text = _formatInitialDecimal(l?.volumeM3);
    _dosagemCtrl.text = _formatInitialDecimal(l?.dosagemKgM3, fallback: '0,8');
    _cwsAdicionadoCtrl.text = _formatInitialDecimal(l?.cwsAdicionadoKg);
    _slumpAntesCtrl.text = _formatInitialDecimal(l?.slumpAntes);
    _slumpDepoisCtrl.text = _formatInitialDecimal(l?.slumpDepois);
    _tempoMisturaCtrl.text = _formatInitialDecimal(l?.tempoMisturaMin);

    _obsCtrl.text = l?.observacoes ?? '';
    _fotoPaths = List<String>.from(l?.fotoPaths ?? const []);
    _previewListenable = Listenable.merge([
      _volumeCtrl,
      _dosagemCtrl,
      _cwsAdicionadoCtrl,
    ]);
  }

  @override
  void dispose() {
    _betoneiraCtrl.dispose();
    _notaFiscalCtrl.dispose();
    _volumeCtrl.dispose();
    _dosagemCtrl.dispose();
    _cwsAdicionadoCtrl.dispose();
    _slumpAntesCtrl.dispose();
    _slumpDepoisCtrl.dispose();
    _tempoMisturaCtrl.dispose();
    _obsCtrl.dispose();
    _volumeFocusNode.dispose();
    _dosagemFocusNode.dispose();
    _cwsAdicionadoFocusNode.dispose();
    _slumpAntesFocusNode.dispose();
    _slumpDepoisFocusNode.dispose();
    _tempoMisturaFocusNode.dispose();
    _obsFocusNode.dispose();
    super.dispose();
  }

  double? _parseNumero(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  String _formatInitialDecimal(double? value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  String _fmtNum(double v, {int casas = 1}) {
    return v.toStringAsFixed(casas).replaceAll('.', ',');
  }

  String _fmtDataHora(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  double get _volumePreview => _parseNumero(_volumeCtrl.text) ?? 0;
  double get _dosagemPreview => _parseNumero(_dosagemCtrl.text) ?? 0;
  double get _cwsPreview => _volumePreview * _dosagemPreview;

  String? _validateOptionalNumber(String? value) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return null;
    final v = _parseNumero(t);
    if (v == null) return 'Número inválido';
    if (v < 0) return 'Não pode ser negativo';
    return null;
  }

  Future<void> _salvar() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final volume = _parseNumero(_volumeCtrl.text)!;
    final dosagem = _parseNumero(_dosagemCtrl.text)!;

    final slumpAntes = _parseNumero(_slumpAntesCtrl.text);
    final slumpDepois = _parseNumero(_slumpDepoisCtrl.text);
    final tempoMistura = _parseNumero(_tempoMisturaCtrl.text);
    final cwsAdicionado = _parseNumero(_cwsAdicionadoCtrl.text);

    setState(() => _saving = true);

    try {
      if (_isEdicao) {
        final original = widget.lancamento!;
        await _repo.atualizarLancamento(
          original.copyWith(
            dataHora: _dataHora,
            caminhao: _betoneiraCtrl.text.trim(),
            volumeM3: volume,
            dosagemKgM3: dosagem,
            cwsAdicionadoKg: cwsAdicionado,
            notaFiscal: _notaFiscalCtrl.text.trim(),
            slumpAntes: slumpAntes,
            slumpDepois: slumpDepois,
            tempoMisturaMin: tempoMistura,
            observacoes: _obsCtrl.text.trim(),
            fotoPaths: _fotoPaths,
          ),
        );
      } else {
        await _repo.criarLancamento(
          obraId: widget.concretagem.obraId,
          concretagemId: widget.concretagem.id!,
          dataHora: _dataHora,
          caminhao: _betoneiraCtrl.text,
          volumeM3: volume,
          dosagemKgM3: dosagem,
          cwsAdicionadoKg: cwsAdicionado,
          notaFiscal: _notaFiscalCtrl.text,
          slumpAntes: slumpAntes,
          slumpDepois: slumpDepois,
          tempoMisturaMin: tempoMistura,
          observacoes: _obsCtrl.text,
          fotoPaths: _fotoPaths,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdicao
                ? 'Lançamento atualizado com sucesso.'
                : 'Lançamento salvo com sucesso.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdicao
                ? 'Erro ao atualizar lançamento: $e'
                : 'Erro ao salvar lançamento: $e',
          ),
        ),
      );
    }
  }

  InputDecoration _dec(String label) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder());

  void _focusNextField() {
    FocusScope.of(context).nextFocus();
  }

  KeyboardActionsConfig _keyboardActionsConfig() {
    KeyboardActionsItem item(FocusNode node) {
      return KeyboardActionsItem(
        focusNode: node,
        toolbarButtons: [
          (focusNode) => TextButton.icon(
            onPressed: focusNode.nextFocus,
            icon: const Icon(Icons.keyboard_arrow_down),
            label: const Text('Próximo'),
          ),
        ],
      );
    }

    return KeyboardActionsConfig(
      keyboardActionsPlatform: KeyboardActionsPlatform.ALL,
      nextFocus: true,
      actions: [
        item(_volumeFocusNode),
        item(_dosagemFocusNode),
        item(_cwsAdicionadoFocusNode),
        item(_slumpAntesFocusNode),
        item(_slumpDepoisFocusNode),
        item(_tempoMisturaFocusNode),
      ],
    );
  }

  Future<void> _escanearNotaFiscal() async {
    if (_scanningNotaFiscal || _saving) return;

    if (!_notaFiscalOcr.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OCR de nota fiscal disponível apenas em Android/iOS.'),
        ),
      );
      return;
    }

    setState(() => _scanningNotaFiscal = true);
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined),
                title: const Text('Escanear com a câmera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Usar imagem da galeria'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;

      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (picked == null) return;

      final result = await _notaFiscalOcr.processarImagem(
        File(picked.path),
        dataHoraDescarga: _dataHora,
      );
      final savedPaths = await _salvarFotosSelecionadas([
        picked,
      ], filenamePrefix: 'nota_fiscal');

      if (!mounted) return;
      setState(() {
        final numero = result.numeroNotaFiscal;
        if (numero != null && numero.trim().isNotEmpty) {
          _notaFiscalCtrl.text = numero.trim();
        }
        final betoneira = result.betoneira;
        if (betoneira != null && betoneira.trim().isNotEmpty) {
          _betoneiraCtrl.text = betoneira.trim();
        }
        final volume = result.volumeM3;
        if (volume != null && volume > 0) {
          _volumeCtrl.text = _fmtNum(volume, casas: 1);
        }
        _obsCtrl.text = _mergeObservacoes(
          _obsCtrl.text,
          _observacoesNotaFiscalOcr(result),
        );
        if (savedPaths.isNotEmpty) {
          _fotoPaths = [..._fotoPaths, ...savedPaths];
        }
        _notaFiscalOcrAviso = _avisoTempoNotaFiscal(result);
      });

      if (!mounted) return;
      if (result.cargaDescargaAcimaDoLimite) {
        await _mostrarAvisoTempoNotaFiscal(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.hasStructuredData
                  ? 'Nota fiscal escaneada. Confira os dados preenchidos.'
                  : 'OCR concluído, mas os dados principais não foram identificados.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao escanear nota fiscal: $e')),
      );
    } finally {
      if (mounted) setState(() => _scanningNotaFiscal = false);
    }
  }

  String _observacoesNotaFiscalOcr(NotaFiscalOcrResult result) {
    final linhas = <String>['Dados extraídos da NF por OCR:'];

    final numero = result.numeroNotaFiscal?.trim();
    if (numero != null && numero.isNotEmpty) linhas.add('NF: $numero');

    final volume = result.volumeM3;
    if (volume != null) {
      linhas.add('Volume de concreto: ${_fmtNum(volume, casas: 1)} m³');
    }

    final lacre = result.lacre?.trim();
    if (lacre != null && lacre.isNotEmpty) linhas.add('Lacre: $lacre');

    final betoneira = result.betoneira?.trim();
    if (betoneira != null && betoneira.isNotEmpty) {
      linhas.add('Betoneira: $betoneira');
    }

    final traco = result.traco?.trim();
    if (traco != null && traco.isNotEmpty) linhas.add('Traço: $traco');

    final carregamento = result.horarioCarregamento;
    if (carregamento != null) {
      linhas.add('Carregamento: ${_fmtDataHora(carregamento)}');
    }

    final intervalo = result.intervaloCargaDescarga;
    if (intervalo != null) {
      final sufixo = result.cargaDescargaAcimaDoLimite
          ? ' - ATENÇÃO: acima do limite de 2h30'
          : '';
      linhas.add('Tempo carga-descarga: ${_fmtDuracao(intervalo)}$sufixo');
    }

    if (linhas.length == 1) {
      linhas.add('Nenhum dado estruturado identificado. Conferir a imagem.');
    }

    return linhas.join('\n');
  }

  String _mergeObservacoes(String atual, String blocoOcr) {
    final partes = [
      atual.trim(),
      blocoOcr.trim(),
    ].where((parte) => parte.isNotEmpty).toList(growable: false);
    return partes.join('\n\n');
  }

  String? _avisoTempoNotaFiscal(NotaFiscalOcrResult result) {
    if (!result.cargaDescargaAcimaDoLimite) return null;
    final carregamento = result.horarioCarregamento;
    final intervalo = result.intervaloCargaDescarga;
    if (carregamento == null || intervalo == null) return null;

    return 'Carregamento em ${_fmtDataHora(carregamento)}. '
        'Intervalo de ${_fmtDuracao(intervalo)} até o preenchimento.';
  }

  Future<void> _mostrarAvisoTempoNotaFiscal(NotaFiscalOcrResult result) async {
    final aviso = _avisoTempoNotaFiscal(result);
    if (aviso == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_outlined),
        title: const Text('Tempo de carregamento acima do limite'),
        content: Text(
          '$aviso\n\nO limite configurado é 2h30. Confira a nota fiscal e o horário do lançamento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  String _fmtDuracao(Duration duration) {
    final horas = duration.inHours;
    final minutos = duration.inMinutes.remainder(60);
    if (horas <= 0) return '${minutos}min';
    return '${horas}h${minutos.toString().padLeft(2, '0')}';
  }

  Future<void> _adicionarFotos() async {
    if (_pickingFotos || _saving) return;

    setState(() => _pickingFotos = true);
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tirar foto'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Escolher da galeria'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;

      final List<XFile> picked;
      if (source == ImageSource.camera) {
        final captured = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 82,
          maxWidth: 1600,
          maxHeight: 1600,
        );
        picked = captured == null ? <XFile>[] : <XFile>[captured];
      } else {
        picked = await _imagePicker.pickMultiImage(
          imageQuality: 82,
          maxWidth: 1600,
          maxHeight: 1600,
        );
      }
      if (picked.isEmpty) return;

      final savedPaths = await _salvarFotosSelecionadas(picked);

      if (!mounted || savedPaths.isEmpty) return;
      setState(() => _fotoPaths = [..._fotoPaths, ...savedPaths]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao adicionar fotos: $e')));
    } finally {
      if (mounted) setState(() => _pickingFotos = false);
    }
  }

  Future<List<String>> _salvarFotosSelecionadas(
    List<XFile> picked, {
    String filenamePrefix = 'foto',
  }) async {
    await _storage.ensureBaseStructure();
    final fotosDir = await _storage.lancamentoPhotosDir(
      widget.concretagem.obraId,
    );
    final savedPaths = <String>[];
    final safePrefix = filenamePrefix
        .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    for (final foto in picked) {
      final source = File(foto.path);
      if (!await source.exists()) continue;

      final now = DateTime.now();
      final ext = p.extension(foto.path).toLowerCase();
      final safeExt = ext.isEmpty ? '.jpg' : ext;
      final filename =
          '${safePrefix.isEmpty ? 'foto' : safePrefix}_obra_${widget.concretagem.obraId}_${now.microsecondsSinceEpoch}_${savedPaths.length}$safeExt';
      final target = File(p.join(fotosDir.path, filename));
      await source.copy(target.path);
      savedPaths.add(target.path);
    }

    return savedPaths;
  }

  void _removerFoto(String path) {
    setState(() {
      _fotoPaths = _fotoPaths.where((foto) => foto != path).toList();
    });
  }

  Widget _previewCards() {
    return AnimatedBuilder(
      animation: _previewListenable,
      builder: (context, _) {
        final cwsAddPreview = _parseNumero(_cwsAdicionadoCtrl.text);
        final cwsPreview = _cwsPreview;
        int? dosagemOk;
        if (cwsAddPreview != null &&
            _volumePreview > 0 &&
            _dosagemPreview > 0) {
          final diff = (cwsAddPreview - cwsPreview).abs();
          final tol2pct = cwsPreview * 0.02;
          final tol = tol2pct < 0.2 ? 0.2 : tol2pct;
          dosagemOk = diff <= tol ? 1 : 0;
        }

        return Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'CWS total: ${_fmtNum(cwsPreview, casas: 1)} kg',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (cwsAddPreview != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.fact_check_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'CWS adicionado: ${_fmtNum(cwsAddPreview, casas: 1)} kg',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (dosagemOk != null) Text(dosagemOk == 1 ? '✅' : '⚠️'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final concretagem = widget.concretagem;
    final titulo = _isEdicao ? 'Editar Lançamento' : 'Novo Lançamento';
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        actions: [
          TextButton(
            onPressed: _saving ? null : _salvar,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: KeyboardActions(
            config: _keyboardActionsConfig(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.obraNome,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Estrutura: ${concretagem.estruturaConcretada.trim().isEmpty ? 'não informada' : concretagem.estruturaConcretada}',
                        ),
                        Text(
                          'Concreteira: ${concretagem.concreteira.trim().isEmpty ? 'não informada' : concretagem.concreteira}',
                        ),
                        Text('Data/hora: ${_fmtDataHora(_dataHora)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _betoneiraCtrl,
                  decoration: _dec('Betoneira * (nº/placa)'),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe a betoneira'
                      : null,
                ),
                const SizedBox(height: 12),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _notaFiscalCtrl,
                        decoration: _dec('Nota fiscal (NF)').copyWith(
                          enabledBorder: _notaFiscalOcrAviso == null
                              ? null
                              : OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.orange.shade700,
                                    width: 1.4,
                                  ),
                                ),
                          focusedBorder: _notaFiscalOcrAviso == null
                              ? null
                              : OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.orange.shade800,
                                    width: 2,
                                  ),
                                ),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Escanear nota fiscal',
                      child: IconButton.filledTonal(
                        onPressed: _scanningNotaFiscal || _saving
                            ? null
                            : _escanearNotaFiscal,
                        icon: _scanningNotaFiscal
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.document_scanner_outlined),
                      ),
                    ),
                  ],
                ),
                if (_notaFiscalOcrAviso != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_outlined,
                          color: Colors.orange.shade800,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _notaFiscalOcrAviso!,
                            style: TextStyle(color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                TextFormField(
                  controller: _volumeCtrl,
                  focusNode: _volumeFocusNode,
                  decoration: _dec('Volume (m³) *'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _focusNextField(),
                  validator: (value) {
                    final v = _parseNumero(value ?? '');
                    if (v == null) return 'Informe o volume';
                    if (v <= 0) return 'Volume deve ser maior que zero';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _dosagemCtrl,
                  focusNode: _dosagemFocusNode,
                  decoration: _dec('Dosagem (kg/m³) *'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _focusNextField(),
                  validator: (value) {
                    final v = _parseNumero(value ?? '');
                    if (v == null) return 'Informe a dosagem';
                    if (v <= 0) return 'Dosagem deve ser maior que zero';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _cwsAdicionadoCtrl,
                  focusNode: _cwsAdicionadoFocusNode,
                  decoration: _dec('Quantidade adicionada (kg)'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _focusNextField(),
                  validator: _validateOptionalNumber,
                ),
                const SizedBox(height: 12),

                _previewCards(),
                const SizedBox(height: 12),

                // Extras de campo
                TextFormField(
                  controller: _slumpAntesCtrl,
                  focusNode: _slumpAntesFocusNode,
                  decoration: _dec('Slump antes (cm)'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _focusNextField(),
                  validator: _validateOptionalNumber,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _slumpDepoisCtrl,
                  focusNode: _slumpDepoisFocusNode,
                  decoration: _dec('Slump depois (cm)'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _focusNextField(),
                  validator: _validateOptionalNumber,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _tempoMisturaCtrl,
                  focusNode: _tempoMisturaFocusNode,
                  decoration: _dec('Tempo de mistura (min)'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _focusNextField(),
                  validator: _validateOptionalNumber,
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Observações',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pickingFotos || _saving
                          ? null
                          : _adicionarFotos,
                      icon: _pickingFotos
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_library_outlined),
                      label: const Text('Fotos'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _obsCtrl,
                  focusNode: _obsFocusNode,
                  decoration: const InputDecoration(
                    hintText: 'Observações do lançamento',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                if (_fotoPaths.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _fotoPaths.length,
                      separatorBuilder: (_, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final path = _fotoPaths[index];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 92,
                                height: 92,
                                color: Colors.grey.shade200,
                                child: Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Center(
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Material(
                                color: Colors.black54,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => _removerFoto(path),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _salvar,
                  icon: const Icon(Icons.save),
                  label: Text(
                    _isEdicao ? 'Salvar alterações' : 'Salvar lançamento',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
