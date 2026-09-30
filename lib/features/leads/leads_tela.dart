import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ciclo.dart';
import '../../core/formatos.dart';
import '../../widgets/estados.dart';
import '../../widgets/navegacao.dart';
import '../../widgets/selos.dart';
import '../admin/admin_repo.dart';
import 'leads_controller.dart';
import 'leads_repo.dart';
import 'modelos.dart';

class LeadsTela extends ConsumerStatefulWidget {
  const LeadsTela({super.key, required this.filtros});

  final FiltrosLeads filtros;

  @override
  ConsumerState<LeadsTela> createState() => _LeadsTelaState();
}

class _LeadsTelaState extends ConsumerState<LeadsTela> {
  late LeadsController _controle;
  late final _busca = TextEditingController(text: widget.filtros.q);
  final _rolagem = ScrollController();
  Timer? _espera;
  bool _semConexao = false;

  late final _ciclo = Ciclo(
    intervalo: const Duration(seconds: 30),
    tarefa: () => _controle.atualizar(),
    ativo: () => mounted && rotaNoTopo(context, '/leads'),
    aoMudarFalha: (falhando) {
      if (mounted) setState(() => _semConexao = falhando);
    },
  );

  @override
  void initState() {
    super.initState();
    _criarControle();
    _rolagem.addListener(_aoRolar);
    _ciclo.iniciar();
  }

  void _criarControle() {
    _controle = LeadsController(ref.read(leadsRepoProvider), widget.filtros)
      ..carregar();
  }

  @override
  void didUpdateWidget(LeadsTela antiga) {
    super.didUpdateWidget(antiga);
    if (antiga.filtros == widget.filtros) return;
    _controle.dispose();
    _criarControle();
    if (_busca.text != widget.filtros.q) _busca.text = widget.filtros.q;
  }

  @override
  void dispose() {
    _ciclo.parar();
    _espera?.cancel();
    _controle.dispose();
    _busca.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  void _aoRolar() {
    if (_rolagem.position.extentAfter < 600) {
      _controle.carregarMais().catchError((_) {});
    }
  }

  // Os filtros ficam na URL (F03, item 2).
  void _aplicar(FiltrosLeads filtros) => context.go(filtros.paraRota());

  void _aoBuscar(String valor) {
    setState(() {}); // mostra ou esconde o botão de limpar
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _aplicar(widget.filtros.comBusca(valor.trim()));
    });
  }

  Future<void> _abrirFiltros() async {
    final novos = await showModalBottomSheet<FiltrosLeads>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _FolhaFiltros(widget.filtros),
    );
    if (novos != null && mounted) _aplicar(novos);
  }

  Future<void> _abrirLead(Lead lead) async {
    final resultado = await context.push<String>('/leads/${lead.id}');
    if (resultado == 'excluido') _controle.remover(lead.id);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.filtros;
    final atalho = FiltrosLeads(q: f.q, vendedorId: f.vendedorId);

    Widget chip(String rotulo, bool ligado, FiltrosLeads destino) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(rotulo),
        selected: ligado,
        onSelected: (_) => _aplicar(destino),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leads'),
        actions: [
          IconButton(
            tooltip: 'Filtros',
            onPressed: _abrirFiltros,
            icon: Badge(
              isLabelVisible: f.avancados > 0,
              label: Text('${f.avancados}'),
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _busca,
              onChanged: _aoBuscar,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por nome ou telefone',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _busca.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar a busca',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busca.clear();
                          _aplicar(f.comBusca(''));
                        },
                      ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                chip(
                  'Todos',
                  !f.aguardandoResposta &&
                      f.haMaisDe.isEmpty &&
                      f.temperatura.isEmpty,
                  atalho,
                ),
                chip(
                  'Sem resposta',
                  f.aguardandoResposta,
                  FiltrosLeads(
                    q: f.q,
                    vendedorId: f.vendedorId,
                    aguardandoResposta: true,
                  ),
                ),
                chip(
                  'Sem resposta há mais de 2h',
                  f.haMaisDe == '2h',
                  FiltrosLeads(
                    q: f.q,
                    vendedorId: f.vendedorId,
                    haMaisDe: '2h',
                  ),
                ),
                chip(
                  'Nunca auditados',
                  f.temperatura == 'sem_auditoria',
                  FiltrosLeads(
                    q: f.q,
                    vendedorId: f.vendedorId,
                    temperatura: 'sem_auditoria',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          AvisoConexao(visivel: _semConexao),
          Expanded(
            child: ListenableBuilder(
              listenable: _controle,
              builder: (context, _) => _lista(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lista() {
    final c = _controle;
    if (c.carregando && c.itens.isEmpty) return const Carregando();
    if (c.erro != null && c.itens.isEmpty) {
      return ErroTela(c.erro!, aoTentarDeNovo: c.carregar);
    }
    if (c.itens.isEmpty) {
      return Vazio(
        'Nenhum lead encontrado com esses filtros',
        acao: widget.filtros.vazio ? null : 'Limpar filtros',
        aoAgir: () {
          _busca.clear();
          _aplicar(const FiltrosLeads());
        },
      );
    }
    return RefreshIndicator(
      onRefresh: c.carregar,
      child: ListView.separated(
        controller: _rolagem,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: c.itens.length + (c.temMais ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i == c.itens.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final lead = c.itens[i];
          return ItemLead(lead, aoTocar: () => _abrirLead(lead));
        },
      ),
    );
  }
}

class ItemLead extends StatelessWidget {
  const ItemLead(this.lead, {super.key, this.aoTocar});

  final Lead lead;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return InkWell(
      onTap: aoTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    lead.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tema.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatarRelativo(lead.ultimaMensagemEm),
                  style: tema.textTheme.bodySmall,
                ),
              ],
            ),
            Text(
              'Vendedor: ${lead.vendedorNome}',
              style: tema.textTheme.bodySmall,
            ),
            if (lead.ultimaMensagem.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                lead.ultimaMensagem,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (lead.aguardandoResposta)
                  const Selo(
                    'Sem resposta',
                    cor: corAlerta,
                    icone: Icons.schedule,
                  ),
                SeloTemperatura(lead.temperatura),
                if (lead.probabilidadeConversao != null)
                  Selo(
                    '${formatarProbabilidade(lead.probabilidadeConversao)} '
                    'de conversão',
                    cor: tema.colorScheme.primary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Filtros além da busca e dos atalhos: vendedor, temperatura, tempo sem
/// resposta e período da última mensagem.
class _FolhaFiltros extends ConsumerStatefulWidget {
  const _FolhaFiltros(this.filtros);

  final FiltrosLeads filtros;

  @override
  ConsumerState<_FolhaFiltros> createState() => _FolhaFiltrosState();
}

class _FolhaFiltrosState extends ConsumerState<_FolhaFiltros> {
  late int? _vendedorId = widget.filtros.vendedorId;
  late String _temperatura = widget.filtros.temperatura;
  late String _haMaisDe = widget.filtros.haMaisDe;
  late String _desde = widget.filtros.desde;
  late String _ate = widget.filtros.ate;

  Future<void> _escolherPeriodo() async {
    final hoje = hojeNaLoja();
    final inicial = DateTime.tryParse(_desde);
    final fim = DateTime.tryParse(_ate);
    final periodo = await showDateRangePicker(
      context: context,
      firstDate: DateTime(hoje.year - 3),
      lastDate: hoje,
      initialDateRange: inicial != null && fim != null
          ? DateTimeRange(start: inicial, end: fim)
          : null,
    );
    if (periodo == null) return;
    setState(() {
      _desde = dataIso(periodo.start);
      _ate = dataIso(periodo.end);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vendedores = ref.watch(vendedoresProvider).value ?? const [];
    String br(String iso) => iso.split('-').reversed.join('/');

    Widget opcoes(
      String titulo,
      Map<String, String> valores,
      String atual,
      ValueChanged<String> aoMudar,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(titulo, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            for (final e in valores.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: atual == e.key,
                onSelected: (ligar) => aoMudar(ligar ? e.key : ''),
              ),
          ],
        ),
      ],
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filtros', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: vendedores.any((v) => v.id == _vendedorId)
                  ? _vendedorId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Vendedor'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final v in vendedores)
                  DropdownMenuItem(value: v.id, child: Text(v.nome)),
              ],
              onChanged: (id) => setState(() => _vendedorId = id),
            ),
            opcoes(
              'Temperatura (última auditoria)',
              const {
                'Quente': 'Quente',
                'Morno': 'Morno',
                'Frio': 'Frio',
                'sem_auditoria': 'Nunca auditados',
              },
              _temperatura,
              (v) => setState(() => _temperatura = v),
            ),
            opcoes(
              'Sem resposta há mais de',
              const {'30m': '30 min', '2h': '2 horas', '1d': '1 dia'},
              _haMaisDe,
              (v) => setState(() => _haMaisDe = v),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _escolherPeriodo,
              icon: const Icon(Icons.date_range),
              label: Text(
                _desde.isEmpty
                    ? 'Período da última mensagem'
                    : 'Última mensagem: ${br(_desde)} a ${br(_ate)}',
              ),
            ),
            if (_desde.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _desde = _ate = ''),
                child: const Text('Limpar o período'),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      FiltrosLeads(q: widget.filtros.q),
                    ),
                    child: const Text('Limpar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      FiltrosLeads(
                        q: widget.filtros.q,
                        vendedorId: _vendedorId,
                        temperatura: _temperatura,
                        desde: _desde,
                        ate: _ate,
                        aguardandoResposta:
                            widget.filtros.aguardandoResposta &&
                            _haMaisDe.isEmpty,
                        haMaisDe: _haMaisDe,
                      ),
                    ),
                    child: const Text('Aplicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
