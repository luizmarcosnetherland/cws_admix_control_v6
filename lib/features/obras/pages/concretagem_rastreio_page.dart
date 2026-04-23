import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../core/services/local_storage_service.dart';
import '../../../data/models/concretagem_model.dart';
import '../../../data/models/lancamento_model.dart';
import '../../../data/repositories/concretagem_repository.dart';

enum _ModoRastreio { spray, navegar }

enum _AcaoSaidaRastreio { cancelar, descartar, salvar }

class ConcretagemRastreioPage extends StatefulWidget {
  final String obraNome;
  final Concretagem concretagem;
  final List<Lancamento> lancamentos;

  const ConcretagemRastreioPage({
    super.key,
    required this.obraNome,
    required this.concretagem,
    required this.lancamentos,
  });

  @override
  State<ConcretagemRastreioPage> createState() =>
      _ConcretagemRastreioPageState();
}

class _ConcretagemRastreioPageState extends State<ConcretagemRastreioPage> {
  static const double _viewportHeight = 420;
  static const double _minBrushSize = 8;
  static const double _maxBrushSize = 40;

  final _repo = ConcretagemRepository();
  final _storage = LocalStorageService();
  final _picker = ImagePicker();
  final _viewerController = TransformationController();

  late Concretagem _concretagemAtual;
  late List<ConcretagemRastreioTraco> _tracos;
  _ModoRastreio _modo = _ModoRastreio.spray;
  double _brushSize = 18;
  double _imageAspectRatio = 1.3;
  bool _carregandoAspectRatio = false;
  bool _salvando = false;
  bool _selecionandoPlanta = false;
  bool _temAlteracoesPendentes = false;
  int? _lancamentoSelecionadoId;
  List<Offset> _activePoints = [];
  double _activeCanvasMinSide = 0;

  List<Lancamento> get _lancamentosComId => widget.lancamentos
      .where((item) => item.id != null)
      .toList(growable: false);

  bool get _temLancamentos => _lancamentosComId.isNotEmpty;

  File? get _plantaFile {
    final path = _concretagemAtual.plantaPath.trim();
    if (path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file;
  }

  bool get _temPlanta => _plantaFile != null;

  Set<int> get _lancamentosMarcados =>
      _tracos.map((item) => item.lancamentoId).toSet();

  Lancamento? get _lancamentoSelecionado {
    final id = _lancamentoSelecionadoId;
    if (id == null) return null;
    for (final item in _lancamentosComId) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _concretagemAtual = widget.concretagem;
    _tracos = _filtrarTracosValidos(widget.concretagem.rastreioTracos);
    if (_temLancamentos) {
      _lancamentoSelecionadoId = _lancamentosComId.first.id;
    }
    if (_tracos.isNotEmpty) {
      _lancamentoSelecionadoId = _tracos.last.lancamentoId;
      _brushSize = _tracos.last.brushSize
          .clamp(_minBrushSize, _maxBrushSize)
          .toDouble();
    }
    _carregarAspectRatio();

    if (_tracos.length != widget.concretagem.rastreioTracos.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _persistirRastreio(tracos: _tracos, silent: true);
      });
    }
  }

  @override
  void dispose() {
    _viewerController.dispose();
    super.dispose();
  }

  List<ConcretagemRastreioTraco> _filtrarTracosValidos(
    List<ConcretagemRastreioTraco> origem,
  ) {
    final idsValidos = _lancamentosComId.map((item) => item.id!).toSet();
    return origem
        .where((item) => idsValidos.contains(item.lancamentoId))
        .where((item) => item.points.length >= 2)
        .toList(growable: false);
  }

  Future<void> _carregarAspectRatio() async {
    final file = _plantaFile;
    if (file == null) {
      if (!mounted) return;
      setState(() => _imageAspectRatio = 1.3);
      return;
    }

    setState(() => _carregandoAspectRatio = true);
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final height = image.height == 0 ? 1 : image.height;
      final aspectRatio = image.width / height;
      image.dispose();

      if (!mounted) return;
      setState(() => _imageAspectRatio = aspectRatio > 0 ? aspectRatio : 1.3);
    } catch (_) {
      if (!mounted) return;
      setState(() => _imageAspectRatio = 1.3);
    } finally {
      if (mounted) {
        setState(() => _carregandoAspectRatio = false);
      }
    }
  }

  bool get _podeSalvar =>
      _temAlteracoesPendentes && !_salvando && _concretagemAtual.id != null;

  Future<bool> _persistirRastreio({
    List<ConcretagemRastreioTraco>? tracos,
    String? plantaPath,
    bool silent = false,
  }) async {
    if (_concretagemAtual.id == null) return false;

    final atualizado = _concretagemAtual.copyWith(
      plantaPath: plantaPath ?? _concretagemAtual.plantaPath,
      rastreioTracos: tracos ?? _tracos,
    );
    var salvou = false;

    if (mounted) {
      setState(() => _salvando = true);
    }

    try {
      final salvo = await _repo.atualizarConcretagem(atualizado);
      salvou = true;
      if (!mounted) return true;
      setState(() {
        _concretagemAtual = salvo;
        _temAlteracoesPendentes = false;
      });
    } catch (e) {
      if (!mounted || silent) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar rastreio da planta: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }

    return salvou;
  }

  Future<bool> _salvarAlteracoes({bool showFeedback = true}) async {
    if (!_temAlteracoesPendentes) return true;

    final salvou = await _persistirRastreio(tracos: _tracos);
    if (salvou && showFeedback && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marcações salvas na concretagem.')),
      );
    }
    return salvou;
  }

  Future<bool> _confirmarSaida() async {
    if (!_temAlteracoesPendentes) return true;

    final acao = await showDialog<_AcaoSaidaRastreio>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salvar marcações'),
        content: const Text(
          'Há marcações pendentes nesta planta. Deseja salvar antes de sair?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_AcaoSaidaRastreio.cancelar),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_AcaoSaidaRastreio.descartar),
            child: const Text('Sair sem salvar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_AcaoSaidaRastreio.salvar),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    switch (acao) {
      case _AcaoSaidaRastreio.descartar:
        return true;
      case _AcaoSaidaRastreio.salvar:
        return _salvarAlteracoes(showFeedback: false);
      case _AcaoSaidaRastreio.cancelar:
      case null:
        return false;
    }
  }

  Future<void> _selecionarPlanta() async {
    if (_selecionandoPlanta || _salvando) return;

    if (_temPlanta || _tracos.isNotEmpty) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Substituir planta'),
          content: Text(
            _tracos.isEmpty
                ? 'Deseja substituir a planta atual desta concretagem?'
                : 'Substituir a planta vai limpar as marcações já feitas. Deseja continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Substituir'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
    }
    if (!mounted) return;

    setState(() => _selecionandoPlanta = true);
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Escanear com a câmera'),
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

      final picked = await _picker.pickImage(source: source, imageQuality: 90);
      if (picked == null) return;

      final path = await _salvarPlantaSelecionada(picked);
      final novosTracos = <ConcretagemRastreioTraco>[];

      if (!mounted) return;
      setState(() {
        _concretagemAtual = _concretagemAtual.copyWith(
          plantaPath: path,
          rastreioTracos: novosTracos,
        );
        _tracos = novosTracos;
        _activePoints = [];
        _temAlteracoesPendentes = true;
        _modo = _ModoRastreio.spray;
        _viewerController.value = Matrix4.identity();
      });

      await _carregarAspectRatio();
      await _persistirRastreio(tracos: novosTracos, plantaPath: path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao selecionar a planta: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _selecionandoPlanta = false);
      }
    }
  }

  Future<String> _salvarPlantaSelecionada(XFile picked) async {
    if (_concretagemAtual.id == null) {
      throw Exception('Concretagem sem ID.');
    }

    await _storage.ensureBaseStructure();
    final dir = await _storage.concretagemRastreioDir(
      _concretagemAtual.obraId,
      _concretagemAtual.id!,
    );
    final ext = p.extension(picked.path).toLowerCase();
    final safeExt = ext.isEmpty ? '.jpg' : ext;
    final filename = 'planta_${DateTime.now().microsecondsSinceEpoch}$safeExt';
    final target = File(p.join(dir.path, filename));

    final original = File(picked.path);
    await original.copy(target.path);

    final antigoPath = _concretagemAtual.plantaPath.trim();
    if (antigoPath.isNotEmpty && antigoPath != target.path) {
      final antigoArquivo = File(antigoPath);
      if (await antigoArquivo.exists()) {
        await antigoArquivo.delete();
      }
    }

    return target.path;
  }

  Future<void> _limparMarcacoes() async {
    if (_tracos.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar marcações'),
        content: const Text('Deseja apagar todas as marcações desta planta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final novosTracos = <ConcretagemRastreioTraco>[];
    setState(() {
      _tracos = novosTracos;
      _activePoints = [];
      _temAlteracoesPendentes = true;
    });
  }

  Future<void> _desfazerUltimoTraco() async {
    final lancamentoId = _lancamentoSelecionadoId;
    if (lancamentoId == null) return;

    final index = _tracos.lastIndexWhere(
      (item) => item.lancamentoId == lancamentoId,
    );
    if (index < 0) return;

    final novosTracos = List<ConcretagemRastreioTraco>.from(_tracos)
      ..removeAt(index);
    setState(() {
      _tracos = novosTracos;
      _temAlteracoesPendentes = true;
    });
  }

  void _mudarModo(_ModoRastreio modo) {
    setState(() {
      _modo = modo;
      _activePoints = [];
    });
  }

  void _iniciarTraco(Offset position, Size canvasSize) {
    if (!_temPlanta || _lancamentoSelecionadoId == null) return;
    final normalized = _toNormalizedOffset(position, canvasSize);
    if (normalized == null) return;
    setState(() {
      _activeCanvasMinSide = math.min(canvasSize.width, canvasSize.height);
      _activePoints = [normalized];
    });
  }

  void _atualizarTraco(Offset position, Size canvasSize) {
    if (_activePoints.isEmpty) return;
    final normalized = _toNormalizedOffset(position, canvasSize);
    if (normalized == null) return;

    final ultimo = _activePoints.last;
    final dx = (normalized.dx - ultimo.dx) * canvasSize.width;
    final dy = (normalized.dy - ultimo.dy) * canvasSize.height;
    if ((dx * dx) + (dy * dy) < 4) return;

    setState(() => _activePoints = [..._activePoints, normalized]);
  }

  Future<void> _finalizarTraco() async {
    final lancamentoId = _lancamentoSelecionadoId;
    if (lancamentoId == null || _activePoints.length < 2) {
      setState(() {
        _activeCanvasMinSide = 0;
        _activePoints = [];
      });
      return;
    }

    final novoTraco = ConcretagemRastreioTraco(
      lancamentoId: lancamentoId,
      brushSize: _brushSize,
      brushScale: _activeCanvasMinSide <= 0
          ? 0
          : (_brushSize / _activeCanvasMinSide),
      points: _activePoints
          .map((item) => ConcretagemRastreioPonto(x: item.dx, y: item.dy))
          .toList(growable: false),
    );
    final novosTracos = [..._tracos, novoTraco];

    setState(() {
      _tracos = novosTracos;
      _activeCanvasMinSide = 0;
      _activePoints = [];
      _temAlteracoesPendentes = true;
    });
  }

  Offset? _toNormalizedOffset(Offset position, Size canvasSize) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return null;

    final dx = position.dx.clamp(0.0, canvasSize.width);
    final dy = position.dy.clamp(0.0, canvasSize.height);

    return Offset(dx / canvasSize.width, dy / canvasSize.height);
  }

  int _quantidadeTracosLancamento(int lancamentoId) {
    return _tracos.where((item) => item.lancamentoId == lancamentoId).length;
  }

  Color _corDoLancamento(int lancamentoId) {
    const palette = <Color>[
      Color(0xFFE07A5F),
      Color(0xFF3D405B),
      Color(0xFF81B29A),
      Color(0xFFF2CC8F),
      Color(0xFF6D597A),
      Color(0xFF2A9D8F),
      Color(0xFFC8553D),
      Color(0xFF4D908E),
    ];
    return palette[lancamentoId.abs() % palette.length];
  }

  String _fmtNum(double value, {int casas = 1}) {
    return value.toStringAsFixed(casas).replaceAll('.', ',');
  }

  String _fmtDataHora(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _tituloLancamento(Lancamento lancamento) {
    final caminhao = lancamento.caminhao.trim();
    if (caminhao.isNotEmpty) return caminhao;
    return 'Lançamento ${lancamento.id}';
  }

  String _statusRastreio() {
    if (!_temPlanta) {
      return 'Escaneie ou importe a planta para começar o rastreio.';
    }
    if (!_temLancamentos) {
      return 'A planta já foi salva. Agora basta cadastrar os lançamentos desta concretagem para marcá-los.';
    }
    return '${_lancamentosMarcados.length} de ${_lancamentosComId.length} lançamentos já foram marcados.';
  }

  String _instrucaoCanvas() {
    if (!_temPlanta) {
      return 'Use a câmera para fotografar a planta ou escolha uma imagem já escaneada da galeria.';
    }
    if (!_temLancamentos) {
      return 'Cadastre pelo menos um lançamento nesta concretagem para habilitar as marcações.';
    }
    if (_modo == _ModoRastreio.navegar) {
      return 'Modo navegar ativo: use pinça e arraste para ampliar e posicionar a planta. Ao voltar para o spray, esse enquadramento é mantido.';
    }
    return 'Modo spray ativo: a planta fica travada no enquadramento atual para não se mover durante a marcação. Use Navegar para ajustar o zoom e depois Salvar para gravar.';
  }

  Size _canvasSizeFor(Size viewportSize) {
    final maxWidth = viewportSize.width - 8;
    final maxHeight = viewportSize.height - 8;
    final viewportAspectRatio = maxWidth / maxHeight;

    if (_imageAspectRatio >= viewportAspectRatio) {
      final width = maxWidth;
      return Size(width, width / _imageAspectRatio);
    }

    final height = maxHeight;
    return Size(height * _imageAspectRatio, height);
  }

  Widget _buildCabecalho() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.obraNome,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              _concretagemAtual.estruturaConcretada.trim().isEmpty
                  ? 'Estrutura não informada'
                  : _concretagemAtual.estruturaConcretada,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _tag(_temPlanta ? 'Planta salva' : 'Sem planta'),
                _tag('Lançamentos: ${_lancamentosComId.length}'),
                _tag('Marcados: ${_lancamentosMarcados.length}'),
                _tag(
                  _temAlteracoesPendentes
                      ? 'Alterações pendentes'
                      : 'Tudo salvo',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(_statusRastreio()),
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

  Widget _buildControles() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ferramentas de rastreio',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (_salvando)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Spray'),
                  selected: _modo == _ModoRastreio.spray,
                  onSelected: (_) => _mudarModo(_ModoRastreio.spray),
                  avatar: const Icon(Icons.brush_outlined, size: 18),
                ),
                ChoiceChip(
                  label: const Text('Navegar'),
                  selected: _modo == _ModoRastreio.navegar,
                  onSelected: (_) => _mudarModo(_ModoRastreio.navegar),
                  avatar: const Icon(Icons.pan_tool_alt_outlined, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_modo == _ModoRastreio.spray)
              Row(
                children: [
                  const Icon(Icons.blur_circular_outlined, size: 18),
                  const SizedBox(width: 8),
                  const Text('Spray'),
                  Expanded(
                    child: Slider(
                      value: _brushSize,
                      min: _minBrushSize,
                      max: _maxBrushSize,
                      divisions: 16,
                      label: _brushSize.round().toString(),
                      onChanged: (_temPlanta && _temLancamentos)
                          ? (value) => setState(() => _brushSize = value)
                          : null,
                    ),
                  ),
                  Text('${_brushSize.round()}'),
                ],
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _selecionandoPlanta ? null : _selecionarPlanta,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Text(
                    _temPlanta ? 'Substituir planta' : 'Escanear planta',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed:
                      (_temLancamentos &&
                          _lancamentoSelecionadoId != null &&
                          _quantidadeTracosLancamento(
                                _lancamentoSelecionadoId!,
                              ) >
                              0)
                      ? _desfazerUltimoTraco
                      : null,
                  icon: const Icon(Icons.undo_outlined),
                  label: const Text('Desfazer'),
                ),
                OutlinedButton.icon(
                  onPressed: _tracos.isNotEmpty ? _limparMarcacoes : null,
                  icon: const Icon(Icons.layers_clear_outlined),
                  label: const Text('Limpar marcações'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _instrucaoCanvas(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          height: _viewportHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F1E8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: _carregandoAspectRatio
              ? const Center(child: CircularProgressIndicator())
              : !_temPlanta
              ? _buildCanvasVazio()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final viewportSize = Size(
                      constraints.maxWidth,
                      _viewportHeight,
                    );
                    final canvasSize = _canvasSizeFor(viewportSize);
                    final canvas = _buildCanvasConteudo(
                      _plantaFile!,
                      canvasSize,
                    );

                    return InteractiveViewer(
                      transformationController: _viewerController,
                      minScale: 1,
                      maxScale: 6,
                      boundaryMargin: const EdgeInsets.all(24),
                      panEnabled: _modo == _ModoRastreio.navegar,
                      scaleEnabled: _modo == _ModoRastreio.navegar,
                      child: SizedBox(
                        width: viewportSize.width,
                        height: viewportSize.height,
                        child: Center(child: canvas),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildCanvasVazio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 40),
            const SizedBox(height: 10),
            const Text(
              'Nenhuma planta carregada',
              style: TextStyle(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(_instrucaoCanvas(), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasConteudo(File file, Size canvasSize) {
    return GestureDetector(
      onPanStart:
          (_modo == _ModoRastreio.spray &&
              _temPlanta &&
              _temLancamentos &&
              _lancamentoSelecionadoId != null)
          ? (details) => _iniciarTraco(details.localPosition, canvasSize)
          : null,
      onPanUpdate:
          (_modo == _ModoRastreio.spray &&
              _temPlanta &&
              _temLancamentos &&
              _lancamentoSelecionadoId != null)
          ? (details) => _atualizarTraco(details.localPosition, canvasSize)
          : null,
      onPanEnd:
          (_modo == _ModoRastreio.spray &&
              _temPlanta &&
              _temLancamentos &&
              _lancamentoSelecionadoId != null)
          ? (_) => _finalizarTraco()
          : null,
      child: Container(
        width: canvasSize.width,
        height: canvasSize.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.black.withValues(alpha: 0.04),
                alignment: Alignment.center,
                child: const Text('Não foi possível abrir a planta'),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _RastreioSprayPainter(
                  tracos: _tracos,
                  activePoints: _activePoints,
                  activeBrushSize: _brushSize,
                  activeLancamentoId: _lancamentoSelecionadoId,
                  colorForLancamento: _corDoLancamento,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLancamentos() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lançamentos para marcar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (!_temLancamentos)
              const Text('Nenhum lançamento cadastrado nesta concretagem.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _lancamentosComId
                    .map((lancamento) {
                      final id = lancamento.id!;
                      final selecionado = _lancamentoSelecionadoId == id;
                      final tracos = _quantidadeTracosLancamento(id);
                      return ChoiceChip(
                        selected: selecionado,
                        onSelected: (_) {
                          setState(() {
                            _lancamentoSelecionadoId = id;
                            _activePoints = [];
                          });
                        },
                        avatar: CircleAvatar(
                          radius: 9,
                          backgroundColor: _corDoLancamento(id),
                        ),
                        label: Text(
                          tracos > 0
                              ? '${_tituloLancamento(lancamento)} ($tracos)'
                              : _tituloLancamento(lancamento),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            if (_lancamentoSelecionado != null) ...[
              const SizedBox(height: 12),
              Text(
                'Selecionado: ${_tituloLancamento(_lancamentoSelecionado!)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${_fmtDataHora(_lancamentoSelecionado!.dataHora)} • ${_fmtNum(_lancamentoSelecionado!.volumeM3)} m³',
              ),
              if (_lancamentoSelecionado!.notaFiscal.trim().isNotEmpty)
                Text('NF: ${_lancamentoSelecionado!.notaFiscal.trim()}'),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !_temAlteracoesPendentes && !_salvando,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _salvando) return;
        final podeSair = await _confirmarSaida();
        if (!podeSair || !context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Rastreio da Planta')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildCabecalho(),
              const SizedBox(height: 10),
              _buildControles(),
              const SizedBox(height: 10),
              _buildCanvas(),
              const SizedBox(height: 10),
              _buildLancamentos(),
              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _podeSalvar ? _salvarAlteracoes : null,
              icon: _salvando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _temAlteracoesPendentes ? 'Salvar marcações' : 'Tudo salvo',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RastreioSprayPainter extends CustomPainter {
  final List<ConcretagemRastreioTraco> tracos;
  final List<Offset> activePoints;
  final double activeBrushSize;
  final int? activeLancamentoId;
  final Color Function(int lancamentoId) colorForLancamento;

  const _RastreioSprayPainter({
    required this.tracos,
    required this.activePoints,
    required this.activeBrushSize,
    required this.activeLancamentoId,
    required this.colorForLancamento,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final traco in tracos) {
      _paintSpray(
        canvas,
        traco.points
            .map((item) => Offset(item.x * size.width, item.y * size.height))
            .toList(growable: false),
        colorForLancamento(traco.lancamentoId),
        traco.brushSize,
        size,
        traco: traco,
      );
    }

    if (activePoints.length >= 2 && activeLancamentoId != null) {
      _paintSpray(
        canvas,
        activePoints
            .map((item) => Offset(item.dx * size.width, item.dy * size.height))
            .toList(growable: false),
        colorForLancamento(activeLancamentoId!),
        activeBrushSize,
        size,
      );
    }
  }

  void _paintSpray(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double brushSize,
    Size size, {
    ConcretagemRastreioTraco? traco,
  }) {
    if (points.length < 2) return;

    final effectiveBrushSize = traco == null
        ? brushSize
        : traco.resolveBrushSize(math.min(size.width, size.height));
    if (effectiveBrushSize <= 0) return;

    final spacing = effectiveBrushSize * 0.22;
    final densified = _densify(points, spacing);
    final blurPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.18)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        effectiveBrushSize * 0.26,
      );
    final corePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.34);

    for (final point in densified) {
      canvas.drawCircle(point, effectiveBrushSize * 0.55, blurPaint);
      canvas.drawCircle(point, effectiveBrushSize * 0.18, corePaint);
    }

    for (final point in points) {
      canvas.drawCircle(point, effectiveBrushSize * 0.25, corePaint);
    }
  }

  List<Offset> _densify(List<Offset> points, double spacing) {
    final output = <Offset>[];
    for (var index = 0; index < points.length - 1; index++) {
      final start = points[index];
      final end = points[index + 1];
      output.add(start);

      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final distance = math.sqrt((dx * dx) + (dy * dy));
      if (distance <= spacing) continue;

      final steps = (distance / spacing).floor();
      for (var step = 1; step < steps; step++) {
        final t = step / steps;
        output.add(Offset(start.dx + (dx * t), start.dy + (dy * t)));
      }
    }
    output.add(points.last);
    return output;
  }

  @override
  bool shouldRepaint(covariant _RastreioSprayPainter oldDelegate) {
    return oldDelegate.tracos != tracos ||
        oldDelegate.activePoints != activePoints ||
        oldDelegate.activeBrushSize != activeBrushSize ||
        oldDelegate.activeLancamentoId != activeLancamentoId;
  }
}
