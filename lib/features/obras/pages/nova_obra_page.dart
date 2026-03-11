import 'package:flutter/material.dart';

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
  final _obsCtrl = TextEditingController();

  final _repo = ObraRepository();

  bool _saving = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _clienteCtrl.dispose();
    _localCtrl.dispose();
    _responsavelCtrl.dispose();
    _emailEngenheiroCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final nome = _nomeCtrl.text.trim();

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
        observacoes: _obsCtrl.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obra criada com sucesso.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar obra: $e')),
      );
      setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      );

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
                decoration: _dec('Local'),
                textInputAction: TextInputAction.next,
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
                decoration: _dec('E-mail do engenheiro'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return null;
                  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
                  return ok ? null : 'Informe um e-mail válido';
                },
              ),
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
