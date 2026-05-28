import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../data/models/concretagem_model.dart';
import '../../../data/models/lancamento_model.dart';
import '../../../data/repositories/concretagem_repository.dart';
import '../../../data/repositories/lancamento_repository.dart';
import 'novo_lancamento_page.dart';

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

class _ConcretagemRastreioPageState extends State<ConcretagemRastreioPage>
    with WidgetsBindingObserver {
  static const double _viewportHeight = 420;
  static const double _minBrushSize = 8;
  static const double _maxBrushSize = 40;

  final _repo = ConcretagemRepository();
  final _lancamentoRepo = LancamentoRepository();
  final _storage = LocalStorageService();
  final _picker = ImagePicker();
  final _viewerController = TransformationController();

  late Concretagem _concretagemAtual;
  late List<Lancamento> _lancamentos;
  late List<ConcretagemRastreioTraco> _tracos;
  _ModoRastreio _modo = _ModoRastreio.spray;
  double _brushSize = 18;
  double _imageAspectRatio = 1.3;
  bool _carregandoAspectRatio = false;
  bool _salvando = false;
  bool _selecionandoPlanta = false;
  bool _temAlteracoesPendentes = false;
  int? _lancamentoSelecionadoId;
  int? _activePointerId;
  List<Offset> _activePoints = [];
  double _activeCanvasMinSide = 0;
  int _rastreioRevision = 0;
  Future<void>? _salvamentoPendente;

  List<Lancamento> get _lancamentosComId =>
      _lancamentos.where((item) => item.id != null).toList(growable: false);

  bool get _temLancamentos => _lancamentosComId.isNotEmpty;

  File? get _plantaFile {
    final path = _concretagemAtual.plantaPath.trim();
    if (path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file;
  }

  bool get _temPlanta => _plantaFile != null;

  bool get _podeMarcarNaPlanta =>
      _modo == _ModoRastreio.spray &&
      _temPlanta &&
      _temLancamentos &&
      _lancamentoSelecionadoId != null;

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
    WidgetsBinding.instance.addObserver(this);
    _concretagemAtual = widget.concretagem;
    _lancamentos = _ordenarLancamentos(widget.lancamentos);
    _tracos = _filtrarTracosValidos(widget.concretagem.rastreioTracos);
    _lancamentoSelecionadoId =
        _primeiroLancamentoPendenteId() ??
        (_temLancamentos ? _lancamentosComId.first.id : null);
    if (_tracos.isNotEmpty) {
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
    WidgetsBinding.instance.removeObserver(this);
    _viewerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (_temAlteracoesPendentes) {
          unawaited(_salvarRastreioPendente(silent: true));
        }
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }

  List<Lancamento> _ordenarLancamentos(List<Lancamento> origem) {
    final ordenados = List<Lancamento>.from(origem);
    ordenados.sort((a, b) {
      final byDate = a.dataHora.compareTo(b.dataHora);
      if (byDate != 0) return byDate;
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });
    return ordenados;
  }

  List<ConcretagemRastreioTraco> _filtrarTracosValidosParaLancamentos(
    List<ConcretagemRastreioTraco> origem,
    List<Lancamento> lancamentos,
  ) {
    final idsValidos = lancamentos
        .where((item) => item.id != null)
        .map((item) => item.id!)
        .toSet();
    return origem
        .where((item) => idsValidos.contains(item.lancamentoId))
        .where((item) => item.points.length >= 2)
        .toList(growable: false);
  }

  List<ConcretagemRastreioTraco> _filtrarTracosValidos(
    List<ConcretagemRastreioTraco> origem,
  ) => _filtrarTracosValidosParaLancamentos(origem, _lancamentos);

  int? _primeiroLancamentoPendenteIdFrom(
    List<Lancamento> lancamentos,
    List<ConcretagemRastreioTraco> tracos,
  ) {
    final marcados = tracos.map((item) => item.lancamentoId).toSet();
    for (final item in lancamentos) {
      final id = item.id;
      if (id == null || marcados.contains(id)) continue;
      return id;
    }
    return null;
  }

  int? _primeiroLancamentoPendenteId() {
    return _primeiroLancamentoPendenteIdFrom(_lancamentosComId, _tracos);
  }

  int? _resolverSelecaoLancamento({
    List<Lancamento>? lancamentos,
    List<ConcretagemRastreioTraco>? tracos,
    int? preferredId,
  }) {
    final itens = (lancamentos ?? _lancamentos)
        .where((item) => item.id != null)
        .toList(growable: false);
    if (itens.isEmpty) return null;

    final idsValidos = itens.map((item) => item.id!).toSet();
    if (preferredId != null && idsValidos.contains(preferredId)) {
      return preferredId;
    }

    return _primeiroLancamentoPendenteIdFrom(itens, tracos ?? _tracos) ??
        itens.first.id;
  }

  bool _lancamentoTemMarcacao(int? lancamentoId) {
    if (lancamentoId == null) return false;
    return _tracos.any((item) => item.lancamentoId == lancamentoId);
  }

  int? get _proximoLancamentoPendenteId {
    final itens = _lancamentosComId;
    if (itens.isEmpty) return null;

    final marcados = _lancamentosMarcados;
    final atual = _lancamentoSelecionadoId;
    final indiceAtual = atual == null
        ? -1
        : itens.indexWhere((item) => item.id == atual);

    if (indiceAtual >= 0) {
      for (var index = indiceAtual + 1; index < itens.length; index++) {
        final id = itens[index].id;
        if (id != null && !marcados.contains(id)) return id;
      }
    }

    final limite = indiceAtual >= 0 ? indiceAtual : itens.length;
    for (var index = 0; index < limite; index++) {
      final id = itens[index].id;
      if (id != null && !marcados.contains(id)) return id;
    }

    return null;
  }

  Future<void> _recarregarLancamentos({int? preferredId}) async {
    final concretagemId = _concretagemAtual.id;
    if (concretagemId == null) return;

    final lista = await _lancamentoRepo.listarPorConcretagem(concretagemId);
    final ordenados = _ordenarLancamentos(lista);
    final tracosValidos = _filtrarTracosValidosParaLancamentos(
      _tracos,
      ordenados,
    );
    final removeuTracosInvalidos = tracosValidos.length != _tracos.length;
    final selecionadoId = _resolverSelecaoLancamento(
      lancamentos: ordenados,
      tracos: tracosValidos,
      preferredId: preferredId,
    );

    if (!mounted) return;
    setState(() {
      _lancamentos = ordenados;
      _tracos = tracosValidos;
      _lancamentoSelecionadoId = selecionadoId;
      _activePointerId = null;
      _activePoints = [];
    });

    if (removeuTracosInvalidos) {
      await _persistirRastreio(tracos: tracosValidos, silent: true);
    }
  }

  Future<void> _abrirNovoLancamento({bool primeiro = false}) async {
    if (_concretagemAtual.id == null) return;

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NovoLancamentoPage(
          obraNome: widget.obraNome,
          concretagem: _concretagemAtual,
        ),
      ),
    );

    if (created != true) return;

    await _recarregarLancamentos();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          primeiro
              ? tr('Primeiro lançamento pronto para ser marcado na planta.')
              : tr('Novo lançamento pronto para ser marcado na planta.'),
        ),
      ),
    );
  }

  Future<void> _abrirPrimeiroLancamento() async {
    await _abrirNovoLancamento(primeiro: true);
  }

  void _selecionarLancamento(int lancamentoId) {
    setState(() {
      _lancamentoSelecionadoId = lancamentoId;
      _activePointerId = null;
      _activePoints = [];
      _modo = _ModoRastreio.spray;
    });
  }

  void _irParaProximoLancamento() {
    final proximoId = _proximoLancamentoPendenteId;
    if (proximoId == null) return;
    _selecionarLancamento(proximoId);
  }

  Future<void> _encerrarConcretagem() async {
    if (_salvando) return;

    final pendentes = _lancamentosComId.where((item) {
      final id = item.id;
      return id != null && !_lancamentosMarcados.contains(id);
    }).length;

    if (pendentes > 0) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('Encerrar concretagem')),
          content: Text(
            pendentes == 1
                ? tr(
                    'Ainda resta 1 lançamento sem marcação. Deseja encerrar mesmo assim?',
                  )
                : tr(
                    'Ainda restam {count} lançamentos sem marcação. Deseja encerrar mesmo assim?',
                    params: {'count': pendentes},
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(tr('Continuar marcando')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(tr('Encerrar')),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    }

    Navigator.of(context).pop(true);
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

  void _marcarAlteracoesPendentes() {
    _rastreioRevision++;
    _temAlteracoesPendentes = true;
  }

  Future<bool> _salvarRastreioPendente({required bool silent}) async {
    if (!_temAlteracoesPendentes || _concretagemAtual.id == null) return true;

    final emAndamento = _salvamentoPendente;
    if (emAndamento != null) {
      await emAndamento;
      if (_temAlteracoesPendentes && !silent) {
        return _salvarRastreioPendente(silent: silent);
      }
      return !_temAlteracoesPendentes;
    }

    late final Future<void> salvamento;
    salvamento = _executarFilaSalvamento(silent: silent);
    _salvamentoPendente = salvamento;

    try {
      await salvamento;
    } finally {
      if (identical(_salvamentoPendente, salvamento)) {
        _salvamentoPendente = null;
      }
    }

    return !_temAlteracoesPendentes;
  }

  Future<void> _executarFilaSalvamento({required bool silent}) async {
    while (_temAlteracoesPendentes && _concretagemAtual.id != null) {
      final revision = _rastreioRevision;
      final tracosSnapshot = List<ConcretagemRastreioTraco>.unmodifiable(
        _tracos,
      );
      final plantaPathSnapshot = _concretagemAtual.plantaPath;

      final salvou = await _persistirRastreio(
        tracos: tracosSnapshot,
        plantaPath: plantaPathSnapshot,
        silent: silent,
        revision: revision,
      );
      if (!salvou) break;
    }
  }

  Future<bool> _persistirRastreio({
    List<ConcretagemRastreioTraco>? tracos,
    String? plantaPath,
    bool silent = false,
    int? revision,
  }) async {
    if (_concretagemAtual.id == null) return false;
    final revisionSalva = revision ?? _rastreioRevision;

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
        if (revisionSalva >= _rastreioRevision) {
          _concretagemAtual = salvo;
          _temAlteracoesPendentes = false;
        } else {
          _concretagemAtual = salvo.copyWith(
            plantaPath: _concretagemAtual.plantaPath,
            rastreioTracos: _tracos,
          );
          _temAlteracoesPendentes = true;
        }
      });
    } catch (e) {
      if (!mounted || silent) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Erro ao salvar rastreio da planta: {error}',
              params: {'error': e},
            ),
          ),
        ),
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

    final salvou = await _salvarRastreioPendente(silent: !showFeedback);
    if (salvou && showFeedback && mounted) {
      setState(() {
        _modo = _ModoRastreio.navegar;
        _activePointerId = null;
        _activePoints = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Marcações salvas na concretagem.'))),
      );
    }
    return salvou;
  }

  Future<bool> _confirmarSaida() async {
    if (!_temAlteracoesPendentes) return true;

    final acao = await showDialog<_AcaoSaidaRastreio>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Salvar marcações')),
        content: Text(
          tr(
            'Há marcações pendentes nesta planta. Deseja salvar antes de sair?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_AcaoSaidaRastreio.cancelar),
            child: Text(tr('Cancelar')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_AcaoSaidaRastreio.descartar),
            child: Text(tr('Sair sem salvar')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_AcaoSaidaRastreio.salvar),
            child: Text(tr('Salvar')),
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
          title: Text(tr('Substituir planta')),
          content: Text(
            _tracos.isEmpty
                ? tr('Deseja substituir a planta atual desta concretagem?')
                : tr(
                    'Substituir a planta vai limpar as marcações já feitas. Deseja continuar?',
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(tr('Cancelar')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(tr('Substituir')),
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
                title: Text(tr('Escanear com a câmera')),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(tr('Escolher da galeria')),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;

      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 2400,
        maxHeight: 2400,
      );
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
        _marcarAlteracoesPendentes();
        _modo = _ModoRastreio.spray;
        _viewerController.value = Matrix4.identity();
      });

      await _salvarRastreioPendente(silent: false);
      await _carregarAspectRatio();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Erro ao selecionar a planta: {error}', params: {'error': e}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _selecionandoPlanta = false);
      }
    }
  }

  Future<String> _salvarPlantaSelecionada(XFile picked) async {
    if (_concretagemAtual.id == null) {
      throw Exception(tr('Concretagem sem ID.'));
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
        title: Text(tr('Limpar marcações')),
        content: Text(tr('Deseja apagar todas as marcações desta planta?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('Limpar')),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final novosTracos = <ConcretagemRastreioTraco>[];
    setState(() {
      _tracos = novosTracos;
      _activePoints = [];
      _marcarAlteracoesPendentes();
    });
    unawaited(_salvarRastreioPendente(silent: true));
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
      _marcarAlteracoesPendentes();
    });
    unawaited(_salvarRastreioPendente(silent: true));
  }

  void _mudarModo(_ModoRastreio modo) {
    setState(() {
      _modo = modo;
      _activePointerId = null;
      _activePoints = [];
    });
  }

  void _iniciarTracoPorPonteiro(PointerDownEvent event, Size canvasSize) {
    if (!_podeMarcarNaPlanta || _activePointerId != null) return;
    _activePointerId = event.pointer;
    _iniciarTraco(event.localPosition, canvasSize);
  }

  void _atualizarTracoPorPonteiro(PointerMoveEvent event, Size canvasSize) {
    if (event.pointer != _activePointerId || !_podeMarcarNaPlanta) return;
    _atualizarTraco(event.localPosition, canvasSize);
  }

  void _finalizarTracoPorPonteiro(PointerUpEvent event) {
    if (event.pointer != _activePointerId) return;
    _activePointerId = null;
    unawaited(_finalizarTraco());
  }

  void _cancelarTracoPorPonteiro(PointerCancelEvent event) {
    if (event.pointer != _activePointerId) return;
    _activePointerId = null;
    setState(() {
      _activeCanvasMinSide = 0;
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
      _marcarAlteracoesPendentes();
    });
    unawaited(_salvarRastreioPendente(silent: true));
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
    return tr('Lançamento {id}', params: {'id': lancamento.id});
  }

  String _statusRastreio() {
    if (!_temPlanta) {
      return tr('Escaneie ou importe a planta para começar o rastreio.');
    }
    if (!_temLancamentos) {
      return tr(
        'A planta já foi salva. Agora basta cadastrar o primeiro lançamento desta concretagem para começar a marcação.',
      );
    }
    return tr(
      '{marked} de {total} lançamentos já foram marcados.',
      params: {
        'marked': _lancamentosMarcados.length,
        'total': _lancamentosComId.length,
      },
    );
  }

  String _instrucaoCanvas() {
    if (!_temPlanta) {
      return tr(
        'Use a câmera para fotografar a planta ou escolha uma imagem já escaneada da galeria.',
      );
    }
    if (!_temLancamentos) {
      return tr(
        'Use o botão abaixo para ir ao primeiro lançamento e depois volte para marcar a planta.',
      );
    }
    if (_modo == _ModoRastreio.navegar) {
      return tr(
        'Modo navegar ativo: use pinça e arraste para ampliar e posicionar a planta. Ao voltar para o spray, esse enquadramento é mantido.',
      );
    }
    return tr(
      'Modo spray ativo: a planta fica travada no enquadramento atual para não se mover durante a marcação. Use Navegar para ajustar o zoom; as marcações são salvas automaticamente.',
    );
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
                  ? tr('Estrutura não informada')
                  : _concretagemAtual.estruturaConcretada,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _tag(_temPlanta ? tr('Planta salva') : tr('Sem planta')),
                _tag(
                  tr(
                    'Lançamentos: {count}',
                    params: {'count': _lancamentosComId.length},
                  ),
                ),
                _tag(
                  tr(
                    'Marcados: {count}',
                    params: {'count': _lancamentosMarcados.length},
                  ),
                ),
                _tag(
                  _temAlteracoesPendentes
                      ? tr('Alterações pendentes')
                      : tr('Tudo salvo'),
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
                Expanded(
                  child: Text(
                    tr('Ferramentas de rastreio'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
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
                  label: Text(tr('Spray')),
                  selected: _modo == _ModoRastreio.spray,
                  onSelected: (_) => _mudarModo(_ModoRastreio.spray),
                  avatar: const Icon(Icons.brush_outlined, size: 18),
                ),
                ChoiceChip(
                  label: Text(tr('Navegar')),
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
                  Text(tr('Spray')),
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
                    _temPlanta
                        ? tr('Substituir planta')
                        : tr('Escanear planta'),
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
                  label: Text(tr('Desfazer')),
                ),
                OutlinedButton.icon(
                  onPressed: _tracos.isNotEmpty ? _limparMarcacoes : null,
                  icon: const Icon(Icons.layers_clear_outlined),
                  label: Text(tr('Limpar marcações')),
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
            Text(
              tr('Nenhuma planta carregada'),
              style: const TextStyle(fontWeight: FontWeight.w700),
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
    final canvas = Container(
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
              child: Text(tr('Não foi possível abrir a planta')),
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
    );

    if (!_podeMarcarNaPlanta) return canvas;

    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        EagerGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
              EagerGestureRecognizer.new,
              (_) {},
            ),
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) => _iniciarTracoPorPonteiro(event, canvasSize),
        onPointerMove: (event) => _atualizarTracoPorPonteiro(event, canvasSize),
        onPointerUp: _finalizarTracoPorPonteiro,
        onPointerCancel: _cancelarTracoPorPonteiro,
        child: canvas,
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
            Text(
              tr('Lançamentos para marcar'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (!_temLancamentos)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Nenhum lançamento cadastrado nesta concretagem.')),
                  if (_temPlanta) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _abrirPrimeiroLancamento,
                        icon: const Icon(Icons.playlist_add_outlined),
                        label: Text(tr('Ir para o primeiro lançamento')),
                      ),
                    ),
                  ],
                ],
              )
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
                        onSelected: (_) => _selecionarLancamento(id),
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
                tr(
                  'Selecionado: {value}',
                  params: {'value': _tituloLancamento(_lancamentoSelecionado!)},
                ),
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

  Widget? _buildBottomActions() {
    if (_temAlteracoesPendentes || _salvando) {
      return SafeArea(
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
              _temAlteracoesPendentes
                  ? tr('Salvar marcações')
                  : tr('Tudo salvo'),
            ),
          ),
        ),
      );
    }

    if (!_temLancamentos || !_lancamentoTemMarcacao(_lancamentoSelecionadoId)) {
      return null;
    }

    final proximoId = _proximoLancamentoPendenteId;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: proximoId == null
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _abrirNovoLancamento,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.playlist_add_outlined),
                    label: Text(tr('Novo lançamento')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _encerrarConcretagem,
                    icon: const Icon(Icons.task_alt_outlined),
                    label: Text(tr('Encerrar')),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _abrirNovoLancamento,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.playlist_add_outlined),
                        label: Text(tr('Novo lançamento')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _irParaProximoLancamento,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.skip_next_outlined),
                        label: Text(tr('Próximo')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _encerrarConcretagem,
                    icon: const Icon(Icons.task_alt_outlined),
                    label: Text(tr('Encerrar concretagem')),
                  ),
                ),
              ],
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
        appBar: AppBar(title: Text(context.tr('Rastreio da Planta'))),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildCabecalho(),
              const SizedBox(height: 10),
              _buildCanvas(),
              const SizedBox(height: 10),
              _buildLancamentos(),
              const SizedBox(height: 10),
              _buildControles(),
              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomActions(),
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
