import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/app_review_service.dart';
import '../../../data/models/obra_model.dart';
import '../../../data/repositories/obra_repository.dart';
import 'nova_obra_page.dart';
import 'obra_detalhe_page.dart';

enum _ReviewPromptAction { rate, feedback }

class ObrasPage extends StatefulWidget {
  const ObrasPage({super.key});

  @override
  State<ObrasPage> createState() => _ObrasPageState();
}

class _ObrasPageState extends State<ObrasPage> {
  final _repo = ObraRepository();
  final _reviewService = AppReviewService();

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Erro ao carregar obras: {error}', params: {'error': e}),
          ),
        ),
      );
    }
  }

  Future<void> _abrirNovaObra() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const NovaObraPage()));
    if (created == true) {
      await _carregarTudo();
      await _maybeAskForReviewAfterCompletedTask();
    }
  }

  Future<void> _maybeAskForReviewAfterCompletedTask() async {
    final shouldPrompt = await _reviewService
        .recordCompletedTaskAndShouldPrompt();
    if (!mounted || !shouldPrompt) return;

    final action = await showDialog<_ReviewPromptAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Como esta sua experiencia?')),
        content: Text(
          tr(
            'Sua avaliacao ajuda outros profissionais a encontrarem o CWS Admix Control. Se preferir, envie um feedback direto para a equipe.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('Agora nao')),
          ),
          TextButton.icon(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ReviewPromptAction.feedback),
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(tr('Enviar feedback')),
          ),
          FilledButton.icon(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ReviewPromptAction.rate),
            icon: const Icon(Icons.star_outline),
            label: Text(tr('Avaliar')),
          ),
        ],
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _ReviewPromptAction.rate:
        final result = await _reviewService.requestReview();
        if (!mounted) return;
        _showReviewResultMessage(result);
      case _ReviewPromptAction.feedback:
        final opened = await _reviewService.openFeedbackEmail();
        if (!mounted || opened) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Nao foi possivel abrir o email de feedback.')),
          ),
        );
    }
  }

  void _showReviewResultMessage(AppReviewRequestResult result) {
    final message = switch (result) {
      AppReviewRequestResult.requested => null,
      AppReviewRequestResult.openedStore => null,
      AppReviewRequestResult.missingAppStoreId =>
        'A avaliacao pela App Store sera ativada quando o app estiver publicado.',
      AppReviewRequestResult.unsupportedPlatform =>
        'A avaliacao direta esta disponivel no Android e no iOS.',
      AppReviewRequestResult.failed =>
        'Nao foi possivel abrir a loja para avaliacao.',
    };

    if (message == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr(message))));
  }

  Future<void> _arquivar(Obra obra) async {
    if (obra.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Arquivar obra')),
        content: Text(
          tr('Deseja arquivar a obra "{nome}"?', params: {'nome': obra.nome}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Cancelar')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Arquivar')),
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
        title: Text(tr('Restaurar obra')),
        content: Text(
          tr(
            'Deseja restaurar a obra "{nome}" para Ativas?',
            params: {'nome': obra.nome},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Cancelar')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Restaurar')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _repo.restaurarObra(obra.id!);
    await _carregarTudo();
  }

  Future<void> _excluir(Obra obra) async {
    if (obra.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Excluir obra')),
        content: Text(
          tr(
            'Deseja excluir permanentemente a obra "{nome}" e todos os seus lancamentos?',
            params: {'nome': obra.nome},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Cancelar')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr('Excluir')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _repo.excluirObra(obra.id!);
    if (!mounted) return;
    await _carregarTudo();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr('Obra "{nome}" excluida.', params: {'nome': obra.nome}),
        ),
      ),
    );
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
                    ? context.tr('Nenhuma obra arquivada.')
                    : context.tr(
                        'Nenhuma obra cadastrada ainda.\nToque em "+ Nova Obra".',
                      ),
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
                if (obra.cliente.isNotEmpty)
                  Text(
                    context.tr(
                      'Cliente: {value}',
                      params: {'value': obra.cliente},
                    ),
                  ),
                if (obra.local.isNotEmpty)
                  Text(
                    context.tr('Local: {value}', params: {'value': obra.local}),
                  ),
                if (obra.localizacaoDescricao.isNotEmpty)
                  Text(
                    context.tr(
                      'Localizacao: {value}',
                      params: {'value': obra.localizacaoDescricao},
                    ),
                  ),
                Text(
                  arquivadas
                      ? context.tr(
                          'Arquivada em: {date}',
                          params: {'date': _fmt(obra.updatedAt)},
                        )
                      : context.tr(
                          'Criada em: {date}',
                          params: {'date': _fmt(obra.createdAt)},
                        ),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'abrir') await _abrirDetalhe(obra);
                if (value == 'arquivar') await _arquivar(obra);
                if (value == 'restaurar') await _restaurar(obra);
                if (value == 'excluir') await _excluir(obra);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'abrir', child: Text(context.tr('Abrir'))),
                if (!arquivadas)
                  PopupMenuItem(
                    value: 'arquivar',
                    child: Text(context.tr('Arquivar')),
                  ),
                if (arquivadas)
                  PopupMenuItem(
                    value: 'restaurar',
                    child: Text(context.tr('Restaurar')),
                  ),
                PopupMenuItem(
                  value: 'excluir',
                  child: Text(context.tr('Excluir')),
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
          title: Text(context.tr('Obras')),
          bottom: TabBar(
            tabs: [
              Tab(text: context.tr('Ativas')),
              Tab(text: context.tr('Arquivadas')),
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
              label: Text(context.tr('Nova Obra')),
            );
          },
        ),
      ),
    );
  }
}
