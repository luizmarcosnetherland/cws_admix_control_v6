import 'package:flutter/material.dart';

import '../../../core/services/obra_location_service.dart';
import '../../../data/repositories/obra_repository.dart';

class NovaObraPage extends StatefulWidget {
  const NovaObraPage({super.key});

  @override
  State<NovaObraPage> createState() => _NovaObraPageState();
}

class _NovaObraPageState extends State<NovaObraPage> {
  final _formKey = GlobalKey<FormState>();

  final _nomeCtrl = TextEditingController();
  final _clienteCtrl = TextEditingController();
  final _localCtrl = TextEditingController();
  final _responsavelCtrl = TextEditingController();
  final _emailEngenheiroCtrl = TextEditingController();
  final _localizacaoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  final _repo = ObraRepository();
  final _locationService = ObraLocationService();

  bool _saving = false;
  bool _loadingLocation = false;
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _clienteCtrl.dispose();
    _localCtrl.dispose();
    _responsavelCtrl.dispose();
    _emailEngenheiroCtrl.dispose();
    _localizacaoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  String? get _coordenadasLabel {
    final latitude = _latitude;
    final longitude = _longitude;
    if (latitude == null || longitude == null) return null;
    return _locationService.coordenadasLabel(latitude, longitude);
  }

  Future<void> _mostrarModalErroLocalizacao(
    ObraLocationException exception,
  ) async {
    final settingsTarget = exception.settingsTarget;
    final abriuConfiguracao = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Permissao de localizacao'),
          content: Text(exception.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Fechar'),
            ),
            if (settingsTarget != null)
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Abrir configuracoes'),
              ),
          ],
        );
      },
    );

    if (abriuConfiguracao != true || settingsTarget == null || !mounted) return;

    final opened = await _locationService.abrirConfiguracoes(settingsTarget);
    if (!mounted || opened) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nao foi possivel abrir as configuracoes do aparelho.'),
      ),
    );
  }

  Future<void> _usarLocalizacaoAtual() async {
    if (_loadingLocation || _saving) return;
    setState(() => _loadingLocation = true);

    try {
      final result = await _locationService.obterLocalizacaoAtual();
      if (!mounted) return;
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _localizacaoCtrl.text = result.descricao;
      });
    } on ObraLocationException catch (e) {
      if (!mounted) return;
      if (e.canOpenSettings) {
        await _mostrarModalErroLocalizacao(e);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao obter localizacao: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao obter localizacao: $e')));
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<bool> _gerarLocalizacaoPeloEndereco({bool showFeedback = true}) async {
    final endereco = _localCtrl.text.trim();
    if (endereco.isEmpty) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Informe o endereco da obra para gerar a localizacao.',
            ),
          ),
        );
      }
      return false;
    }

    if (_loadingLocation || _saving) return false;
    setState(() => _loadingLocation = true);

    try {
      final result = await _locationService.obterLocalizacaoPorEndereco(
        endereco,
      );
      if (!mounted) return false;
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _localizacaoCtrl.text = result.descricao;
      });
      return true;
    } on ObraLocationException catch (e) {
      if (!mounted) return false;
      if (showFeedback) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return false;
    } catch (e) {
      if (!mounted) return false;
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao localizar endereco: $e')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  void _limparLocalizacao() {
    setState(() {
      _latitude = null;
      _longitude = null;
      _localizacaoCtrl.clear();
    });
  }

  Future<void> _salvar() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    try {
      final nome = _nomeCtrl.text.trim();
      final endereco = _localCtrl.text.trim();

      if (endereco.isNotEmpty &&
          (_latitude == null ||
              _longitude == null ||
              _localizacaoCtrl.text.trim().isEmpty)) {
        final localizacaoOk = await _gerarLocalizacaoPeloEndereco(
          showFeedback: false,
        );
        if (!localizacaoOk) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Nao foi possivel gerar a localizacao pelo endereco. Revise o endereco ou use a localizacao atual.',
              ),
            ),
          );
          return;
        }
      }

      setState(() => _saving = true);

      final existe = await _repo.nomeJaExiste(nome);
      if (existe) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Já existe uma obra ativa com esse nome.'),
          ),
        );
        setState(() => _saving = false);
        return;
      }

      await _repo.criarObra(
        nome: nome,
        cliente: _clienteCtrl.text,
        local: _localCtrl.text,
        responsavel: _responsavelCtrl.text,
        emailEngenheiro: _emailEngenheiroCtrl.text,
        latitude: _latitude,
        longitude: _longitude,
        localizacaoDescricao: _localizacaoCtrl.text,
        observacoes: _obsCtrl.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Obra criada com sucesso.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar obra: $e')));
      setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Obra'),
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
              TextFormField(
                controller: _nomeCtrl,
                decoration: _dec('Nome da obra *'),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome da obra';
                  }
                  if (value.trim().length < 3) {
                    return 'Use pelo menos 3 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _clienteCtrl,
                decoration: _dec('Cliente'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _localCtrl,
                decoration: _dec('Endereco da obra'),
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  _gerarLocalizacaoPeloEndereco(showFeedback: false);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _responsavelCtrl,
                decoration: _dec('Responsável'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailEngenheiroCtrl,
                decoration: _dec('E-mail do engenheiro *'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) {
                    return 'Informe o e-mail do engenheiro';
                  }
                  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
                  return ok ? null : 'Informe um e-mail válido';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _localizacaoCtrl,
                readOnly: true,
                decoration: _dec('Localizacao da obra').copyWith(
                  hintText:
                      'Gere pelo endereco digitado ou use a localizacao atual',
                ),
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_saving || _loadingLocation)
                          ? null
                          : _usarLocalizacaoAtual,
                      icon: _loadingLocation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      label: Text(
                        _localizacaoCtrl.text.trim().isEmpty
                            ? 'Usar localizacao atual'
                            : 'Atualizar localizacao',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_saving || _loadingLocation)
                          ? null
                          : () => _gerarLocalizacaoPeloEndereco(),
                      icon: const Icon(Icons.pin_drop_outlined),
                      label: const Text('Gerar pelo endereco'),
                    ),
                  ),
                ],
              ),
              if (_localizacaoCtrl.text.trim().isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Limpar localizacao',
                    onPressed: (_saving || _loadingLocation)
                        ? null
                        : _limparLocalizacao,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              if (_coordenadasLabel != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Coordenadas: $_coordenadasLabel',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _obsCtrl,
                decoration: _dec('Observações'),
                minLines: 3,
                maxLines: 5,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _saving ? null : _salvar,
                icon: const Icon(Icons.save),
                label: const Text('Salvar obra'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
