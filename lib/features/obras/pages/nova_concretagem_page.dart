import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../data/models/concretagem_model.dart';
import '../../../data/repositories/concretagem_repository.dart';

class NovaConcretagemPage extends StatefulWidget {
  final int obraId;
  final String obraNome;
  final Concretagem? concretagem;

  const NovaConcretagemPage({
    super.key,
    required this.obraId,
    required this.obraNome,
    this.concretagem,
  });

  @override
  State<NovaConcretagemPage> createState() => _NovaConcretagemPageState();
}

class _NovaConcretagemPageState extends State<NovaConcretagemPage> {
  final _repo = ConcretagemRepository();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _estruturaCtrl;
  late final TextEditingController _concreteiraCtrl;
  late final TextEditingController _empresaTecnologiaCtrl;

  bool _saving = false;
  String _controleTecnologico = '';

  bool get _isEdicao => widget.concretagem != null;
  bool get _mostrarEmpresaTecnologia => _controleTecnologico == 'sim';

  @override
  void initState() {
    super.initState();
    _estruturaCtrl = TextEditingController(
      text: widget.concretagem?.estruturaConcretada ?? '',
    );
    _concreteiraCtrl = TextEditingController(
      text: widget.concretagem?.concreteira ?? '',
    );
    _empresaTecnologiaCtrl = TextEditingController(
      text: widget.concretagem?.empresaTecnologiaConcreto ?? '',
    );
    _controleTecnologico = widget.concretagem?.controleTecnologico ?? '';
  }

  @override
  void dispose() {
    _estruturaCtrl.dispose();
    _concreteiraCtrl.dispose();
    _empresaTecnologiaCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label) =>
      InputDecoration(labelText: tr(label), border: const OutlineInputBorder());

  Future<void> _salvar() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final empresaTecnologia = _mostrarEmpresaTecnologia
        ? _empresaTecnologiaCtrl.text.trim()
        : '';

    try {
      final concretagem = _isEdicao
          ? await _repo.atualizarConcretagem(
              widget.concretagem!.copyWith(
                estruturaConcretada: _estruturaCtrl.text.trim(),
                concreteira: _concreteiraCtrl.text.trim(),
                controleTecnologico: _controleTecnologico,
                empresaTecnologiaConcreto: empresaTecnologia,
              ),
            )
          : await _repo.criarConcretagem(
              obraId: widget.obraId,
              estruturaConcretada: _estruturaCtrl.text.trim(),
              concreteira: _concreteiraCtrl.text.trim(),
              controleTecnologico: _controleTecnologico,
              empresaTecnologiaConcreto: empresaTecnologia,
            );

      if (!mounted) return;
      Navigator.of(context).pop(concretagem);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Erro ao salvar concretagem: {error}', params: {'error': e}),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _isEdicao
        ? context.tr('Editar Concretagem')
        : context.tr('Nova Concretagem');
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
                : Text(context.tr('Salvar')),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    widget.obraNome,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _estruturaCtrl,
                decoration: _dec('Estrutura a ser concretada'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _concreteiraCtrl,
                decoration: _dec('Concreteira'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _controleTecnologico,
                decoration: _dec('Controle tecnológico?'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('')),
                  DropdownMenuItem(
                    value: 'sim',
                    child: Text(context.tr('Sim')),
                  ),
                  DropdownMenuItem(
                    value: 'nao',
                    child: Text(context.tr('Não')),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _controleTecnologico = value ?? '';
                    if (!_mostrarEmpresaTecnologia) {
                      _empresaTecnologiaCtrl.clear();
                    }
                  });
                },
              ),
              if (_mostrarEmpresaTecnologia) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _empresaTecnologiaCtrl,
                  decoration: _dec('Empresa de tecnologia do concreto'),
                  textInputAction: TextInputAction.done,
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _saving ? null : _salvar,
                icon: const Icon(Icons.save),
                label: Text(
                  _isEdicao
                      ? context.tr('Salvar alterações')
                      : context.tr('Salvar concretagem'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
