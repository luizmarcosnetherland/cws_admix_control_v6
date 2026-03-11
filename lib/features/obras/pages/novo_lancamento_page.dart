import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../core/services/local_dropbox_storage_service.dart';
import '../../../data/models/lancamento_model.dart';
import '../../../data/repositories/lancamento_repository.dart';

class NovoLancamentoPage extends StatefulWidget {
  final int obraId;
  final String obraNome;
  final Lancamento? lancamento; // null = novo | != null = edição

  const NovoLancamentoPage({
    super.key,
    required this.obraId,
    required this.obraNome,
    this.lancamento,
  });

  @override
  State<NovoLancamentoPage> createState() => _NovoLancamentoPageState();
}

class _NovoLancamentoPageState extends State<NovoLancamentoPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = LancamentoRepository();
  final _storage = LocalDropboxStorageService();
  final _imagePicker = ImagePicker();

  final _betoneiraCtrl = TextEditingController();
  final _concreteiraCtrl = TextEditingController();
  final _notaFiscalCtrl = TextEditingController();

  final _volumeCtrl = TextEditingController();
  final _dosagemCtrl = TextEditingController();
  final _cwsAdicionadoCtrl = TextEditingController();

  final _slumpAntesCtrl = TextEditingController();
  final _slumpDepoisCtrl = TextEditingController();
  final _tempoMisturaCtrl = TextEditingController();

  final _obsCtrl = TextEditingController();
  List<String> _fotoPaths = [];

  late final DateTime _dataHora;
  bool _saving = false;
  bool _pickingFotos = false;

  bool get _isEdicao => widget.lancamento != null;

  @override
  void initState() {
    super.initState();

    final l = widget.lancamento;
    _dataHora = l?.dataHora ?? DateTime.now();

    _betoneiraCtrl.text = l?.caminhao ?? '';
    _concreteiraCtrl.text = l?.concreteira ?? '';
    _notaFiscalCtrl.text = l?.notaFiscal ?? '';

    _volumeCtrl.text = l != null
        ? l.volumeM3.toStringAsFixed(3).replaceAll('.', ',')
        : '';
    _dosagemCtrl.text = l != null
        ? l.dosagemKgM3.toStringAsFixed(3).replaceAll('.', ',')
        : '0,80';
    _cwsAdicionadoCtrl.text = l?.cwsAdicionadoKg == null
        ? ''
        : l!.cwsAdicionadoKg!.toStringAsFixed(3).replaceAll('.', ',');
    _slumpAntesCtrl.text = l?.slumpAntes == null
        ? ''
        : l!.slumpAntes!.toStringAsFixed(1).replaceAll('.', ',');
    _slumpDepoisCtrl.text = l?.slumpDepois == null
        ? ''
        : l!.slumpDepois!.toStringAsFixed(1).replaceAll('.', ',');
    _tempoMisturaCtrl.text = l?.tempoMisturaMin == null
        ? ''
        : l!.tempoMisturaMin!.toStringAsFixed(1).replaceAll('.', ',');

    _obsCtrl.text = l?.observacoes ?? '';
    _fotoPaths = List<String>.from(l?.fotoPaths ?? const []);

    _volumeCtrl.addListener(_recalc);
    _dosagemCtrl.addListener(_recalc);
    _cwsAdicionadoCtrl.addListener(_recalc);
  }

  @override
  void dispose() {
    _betoneiraCtrl.dispose();
    _concreteiraCtrl.dispose();
    _notaFiscalCtrl.dispose();
    _volumeCtrl.dispose();
    _dosagemCtrl.dispose();
    _cwsAdicionadoCtrl.dispose();
    _slumpAntesCtrl.dispose();
    _slumpDepoisCtrl.dispose();
    _tempoMisturaCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  void _recalc() {
    if (mounted) setState(() {});
  }

  double? _parseNumero(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  String _fmtNum(double v, {int casas = 3}) {
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
            concreteira: _concreteiraCtrl.text.trim(),
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
          obraId: widget.obraId,
          dataHora: _dataHora,
          caminhao: _betoneiraCtrl.text,
          concreteira: _concreteiraCtrl.text,
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

  Future<void> _adicionarFotos() async {
    if (_pickingFotos || _saving) return;

    setState(() => _pickingFotos = true);
    try {
      final picked = await _imagePicker.pickMultiImage(imageQuality: 85);
      if (picked.isEmpty) return;

      await _storage.ensureBaseStructure();
      final fotosDir = await _storage.lancamentoPhotosDir(widget.obraId);
      final savedPaths = <String>[];

      for (final foto in picked) {
        final source = File(foto.path);
        if (!await source.exists()) continue;

        final now = DateTime.now();
        final ext = p.extension(foto.path).toLowerCase();
        final safeExt = ext.isEmpty ? '.jpg' : ext;
        final filename =
            'obra_${widget.obraId}_${now.microsecondsSinceEpoch}_${savedPaths.length}$safeExt';
        final target = File(p.join(fotosDir.path, filename));
        await source.copy(target.path);
        savedPaths.add(target.path);
      }

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

  void _removerFoto(String path) {
    setState(() {
      _fotoPaths = _fotoPaths.where((foto) => foto != path).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _isEdicao ? 'Editar Lançamento' : 'Novo Lançamento';

    final cwsAddPreview = _parseNumero(_cwsAdicionadoCtrl.text);

    int? dosagemOk;
    if (cwsAddPreview != null && _volumePreview > 0 && _dosagemPreview > 0) {
      final esperado = _cwsPreview;
      final diff = (cwsAddPreview - esperado).abs();

      final tol2pct = esperado * 0.02;
      final tol = tol2pct < 0.2 ? 0.2 : tol2pct;

      dosagemOk = diff <= tol ? 1 : 0;
    }
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

              TextFormField(
                controller: _notaFiscalCtrl,
                decoration: _dec('Nota fiscal (NF)'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _concreteiraCtrl,
                decoration: _dec('Concreteira'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _volumeCtrl,
                decoration: _dec('Volume (m³) *'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
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
                decoration: _dec('Dosagem (kg/m³) *'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
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
                decoration: _dec('Quantidade adicionada (kg)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                validator: _validateOptionalNumber,
              ),
              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.calculate_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'CWS total: ${_fmtNum(_cwsPreview, casas: 3)} kg',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (cwsAddPreview != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.fact_check_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'CWS adicionado: ${_fmtNum(cwsAddPreview, casas: 3)} kg',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (dosagemOk != null)
                          Text(dosagemOk == 1 ? '✅' : '⚠️'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // Extras de campo
              TextFormField(
                controller: _slumpAntesCtrl,
                decoration: _dec('Slump antes (cm)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                validator: _validateOptionalNumber,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _slumpDepoisCtrl,
                decoration: _dec('Slump depois (cm)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                validator: _validateOptionalNumber,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _tempoMisturaCtrl,
                decoration: _dec('Tempo de mistura (min)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
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
                                      child: Icon(Icons.broken_image_outlined),
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
    );
  }
}
