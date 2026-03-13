import 'package:flutter/material.dart';

import '../../../data/models/obra_model.dart';
import '../../../data/repositories/obra_repository.dart';
import 'nova_obra_page.dart';
import 'obra_detalhe_page.dart';

class ObrasPage extends StatefulWidget {
  const ObrasPage({super.key});

  @override
  State<ObrasPage> createState() => _ObrasPageState();
}

class _ObrasPageState extends State<ObrasPage> {
  final _repo = ObraRepository();

  bool _loading = true;

  List<Obra> _ativas = [];
  List<Obra> _arquivadas = [];

  @override
  void initState() {
    super.initState();
    _carregarTudo();
  }

  Future<void> _carregarTudo() async {
    setState(() => _loading = true);
    try {
      final ativas = await _repo.listarObrasAtivas();
      final arquivadas = await _repo.listarObrasArquivadas();
      if (!mounted) return;
      setState(() {
        _ativas = ativas;
        _arquivadas = arquivadas;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao carregar obras: $e')));
    }
  }

  Future<void> _abrirNovaObra() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const NovaObraPage()));
    if (created == true) await _carregarTudo();
  }

  Future<void> _arquivar(Obra obra) async {
    if (obra.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arquivar obra'),
        content: Text('Deseja arquivar a obra "${obra.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Arquivar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _repo.arquivarObra(obra.id!);
    await _carregarTudo();
  }

  Future<void> _restaurar(Obra obra) async {
    if (obra.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar obra'),
        content: Text('Deseja restaurar a obra "${obra.nome}" para Ativas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _repo.restaurarObra(obra.id!);
    await _carregarTudo();
  }

  Future<void> _abrirDetalhe(Obra obra) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ObraDetalhePage(obra: obra)));
    await _carregarTudo();
  }

  String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Widget _listaObras({required List<Obra> obras, required bool arquivadas}) {
    if (obras.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                arquivadas
                    ? 'Nenhuma obra arquivada.'
                    : 'Nenhuma obra cadastrada ainda.\nToque em "+ Nova Obra".',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: obras.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final obra = obras[index];

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(arquivadas ? Icons.archive : Icons.apartment),
            ),
            title: Text(
              obra.nome,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (obra.cliente.isNotEmpty) Text('Cliente: ${obra.cliente}'),
                if (obra.local.isNotEmpty) Text('Local: ${obra.local}'),
                if (obra.localizacaoDescricao.isNotEmpty)
                  Text('Localizacao: ${obra.localizacaoDescricao}'),
                Text(
                  arquivadas
                      ? 'Arquivada em: ${_fmt(obra.updatedAt)}'
                      : 'Criada em: ${_fmt(obra.createdAt)}',
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'abrir') await _abrirDetalhe(obra);
                if (value == 'arquivar') await _arquivar(obra);
                if (value == 'restaurar') await _restaurar(obra);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'abrir', child: Text('Abrir')),
                if (!arquivadas)
                  const PopupMenuItem(
                    value: 'arquivar',
                    child: Text('Arquivar'),
                  ),
                if (arquivadas)
                  const PopupMenuItem(
                    value: 'restaurar',
                    child: Text('Restaurar'),
                  ),
              ],
            ),
            onTap: () => _abrirDetalhe(obra),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Obras'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ativas'),
              Tab(text: 'Arquivadas'),
            ],
          ),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    RefreshIndicator(
                      onRefresh: _carregarTudo,
                      child: _listaObras(obras: _ativas, arquivadas: false),
                    ),
                    RefreshIndicator(
                      onRefresh: _carregarTudo,
                      child: _listaObras(obras: _arquivadas, arquivadas: true),
                    ),
                  ],
                ),
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tabIndex = DefaultTabController.of(context).index;
            if (tabIndex != 0) return const SizedBox.shrink();
            return FloatingActionButton.extended(
              onPressed: _abrirNovaObra,
              icon: const Icon(Icons.add),
              label: const Text('Nova Obra'),
            );
          },
        ),
      ),
    );
  }
}
