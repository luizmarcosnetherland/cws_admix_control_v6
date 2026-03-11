import 'package:flutter/material.dart';

import '../../../data/models/obra_model.dart';
import '../../../data/repositories/obra_repository.dart';

class EditarObraPage extends StatefulWidget {
  final Obra obra;

  const EditarObraPage({super.key, required this.obra});

  @override
  State<EditarObraPage> createState() => _EditarObraPageState();
}

class _EditarObraPageState extends State<EditarObraPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ObraRepository();

  late final TextEditingController _nomeCtrl;
  late final TextEditingController _clienteCtrl;
  late final TextEditingController _localCtrl;
  late final TextEditingController _responsavelCtrl;
  late final TextEditingController _emailEngenheiroCtrl;
  late final TextEditingController _obsCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.obra.nome);
    _clienteCtrl = TextEditingController(text: widget.obra.cliente);
    _localCtrl = TextEditingController(text: widget.obra.local);
    _responsavelCtrl = TextEditingController(text: widget.obra.responsavel);
    _emailEngenheiroCtrl = TextEditingController(
      text: widget.obra.emailEngenheiro,
    );
    _obsCtrl = TextEditingController(text: widget.obra.observacoes);
  }

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

  InputDecoration _dec(String label) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder());

  Future<void> _salvar() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final obraAtualizada = widget.obra.copyWith(
      nome: _nomeCtrl.text.trim(),
      cliente: _clienteCtrl.text.trim(),
      local: _localCtrl.text.trim(),
      responsavel: _responsavelCtrl.text.trim(),
      emailEngenheiro: _emailEngenheiroCtrl.text.trim(),
      observacoes: _obsCtrl.text.trim(),
    );

    try {
      await _repo.atualizarObra(obraAtualizada);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obra atualizada com sucesso.')),
      );
      Navigator.of(context).pop(obraAtualizada);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao atualizar obra: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Obra'),
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
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Informe o nome da obra';
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
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return null;
                  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
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
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _saving ? null : _salvar,
                icon: const Icon(Icons.save),
                label: const Text('Salvar alterações'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
