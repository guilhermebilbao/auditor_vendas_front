import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ciclo.dart';
import '../../core/formatos.dart';
import '../../core/sessao/sessao.dart';
import '../../widgets/barra_pilula.dart';
import '../../widgets/estados.dart';
import '../../widgets/navegacao.dart';
import '../../widgets/selos.dart';
import '../leads/modelos.dart';
import 'componentes.dart';
import 'desempenho_repo.dart';
import 'modelos.dart';

/// Painel inicial (F05, itens 1 a 5). Nenhuma chamada daqui usa IA.
class PainelTela extends ConsumerStatefulWidget {
  const PainelTela({super.key, required this.periodo});

  final Periodo periodo;

  @override
  ConsumerState<PainelTela> createState() => _PainelTelaState();
}

class _PainelTelaState extends ConsumerState<PainelTela> {
  String _limiteEsquecidos = '2h';

  ConsultaMetricas get _consulta =>
      (desde: widget.periodo.desde, ate: widget.periodo.ate, vendedorId: null);

  late final _ciclo = Ciclo(
    intervalo: const Duration(seconds: 60),
    ativo: () => mounted && rotaNoTopo(context, '/'),
    tarefa: _recarregar,
  );

  Future<void> _recarregar() async {
    await Future.wait([
      ref.refresh(metricasProvider(_consulta).future),
      ref.refresh(esquecidosProvider(_limiteEsquecidos).future),
    ]);
  }

  @override
  void initState() {
    super.initState();
    _ciclo.iniciar();
  }

  @override
  void dispose() {
    _ciclo.parar();
    super.dispose();
  }

  // O período fica na URL e vale para todos os blocos da tela.
  void _mudarPeriodo(Periodo periodo) => context.go(
    Uri(path: '/', queryParameters: periodo.paraQuery()).toString(),
  );

  @override
  Widget build(BuildContext context) {
    final loja = ref.watch(sessaoProvider.select((s) => s.loja?.nome));
    final metricas = ref.watch(metricasProvider(_consulta));
    final esquecidos = ref.watch(esquecidosProvider(_limiteEsquecidos));

    return Scaffold(
      appBar: AppBar(title: Text(loja ?? 'Painel')),
      body: RefreshIndicator(
        onRefresh: () => _recarregar().catchError((_) {}),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            24 + BarraPilula.folgaInferior(context),
          ),
          children: [
            SeletorPeriodo(periodo: widget.periodo, aoMudar: _mudarPeriodo),
            const SizedBox(height: 12),
            ValorAssincrono(
              valor: metricas,
              aoTentarDeNovo: () => ref.invalidate(metricasProvider(_consulta)),
              construir: (m) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CartoesMetricas(
                    m,
                    aoTocarSemResposta: () => context.go(
                      const FiltrosLeads(aguardandoResposta: true).paraRota(),
                    ),
                  ),
                  _filaDeEsquecidos(esquecidos),
                  const TituloSecao('Por vendedor'),
                  TabelaVendedores(
                    m.porVendedor,
                    aoTocar: (id) => context.push(
                      Uri(
                        path: '/vendedores/$id',
                        queryParameters: widget.periodo.paraQuery(),
                      ).toString(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaDeEsquecidos(AsyncValue<List<Lead>> esquecidos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloSecao(
          'Sem resposta há mais de',
          acao: SegmentedButton<String>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: '30m', label: Text('30min')),
              ButtonSegment(value: '2h', label: Text('2h')),
              ButtonSegment(value: '1d', label: Text('1d')),
            ],
            selected: {_limiteEsquecidos},
            onSelectionChanged: (s) =>
                setState(() => _limiteEsquecidos = s.first),
          ),
        ),
        ValorAssincrono(
          valor: esquecidos,
          linhas: 2,
          aoTentarDeNovo: () =>
              ref.invalidate(esquecidosProvider(_limiteEsquecidos)),
          construir: (leads) => leads.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Ninguém esperando há tanto tempo. 👏'),
                )
              : Card(
                  child: Column(
                    children: [
                      for (final lead in leads)
                        ListTile(
                          dense: true,
                          title: Text(
                            lead.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('Vendedor: ${lead.vendedorNome}'),
                          trailing: Text(
                            formatarRelativo(lead.ultimaMensagemEm),
                            style: const TextStyle(
                              color: corAlerta,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () => context.push('/leads/${lead.id}'),
                        ),
                      TextButton(
                        onPressed: () => context.go(
                          FiltrosLeads(haMaisDe: _limiteEsquecidos).paraRota(),
                        ),
                        child: const Text('Ver todos'),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Métricas por vendedor, ordenável por coluna (F05, item 4).
class TabelaVendedores extends StatefulWidget {
  const TabelaVendedores(this.linhas, {super.key, this.aoTocar});

  final List<MetricasGrupo> linhas;
  final ValueChanged<int>? aoTocar;

  @override
  State<TabelaVendedores> createState() => _TabelaVendedoresState();
}

class _TabelaVendedoresState extends State<TabelaVendedores> {
  int _coluna = 0;
  bool _crescente = true;

  static const _colunas = [
    'Vendedor',
    'Leads',
    'Resposta',
    'Fora SLA',
    'Aguard.',
  ];

  Comparable<dynamic> _valor(MetricasGrupo g) => switch (_coluna) {
    0 => g.vendedorNome.toLowerCase(),
    1 => g.leads,
    // Sem dado vai para o fim, em qualquer ordem.
    2 => g.tempoResposta.p50Seg ?? (_crescente ? 1 << 40 : -1),
    3 => g.percentualForaSla ?? (_crescente ? double.infinity : -1.0),
    _ => g.leadsAguardandoResposta,
  };

  @override
  Widget build(BuildContext context) {
    if (widget.linhas.isEmpty) {
      return const Text('Sem atividade de vendedores no período.');
    }
    final tema = Theme.of(context);
    final linhas = [...widget.linhas]
      ..sort((a, b) {
        final ordem = Comparable.compare(_valor(a), _valor(b));
        return _crescente ? ordem : -ordem;
      });
    const pequeno = TextStyle(fontSize: 13);

    Widget cabecalho(int i) => InkWell(
      onTap: () => setState(() {
        _crescente = _coluna == i ? !_crescente : i == 0;
        _coluna = i;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: i == 0
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                _colunas[i],
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.labelSmall,
              ),
            ),
            if (_coluna == i)
              Icon(
                _crescente ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 16,
              ),
          ],
        ),
      ),
    );

    Widget celula(String texto, {Color? cor}) => Text(
      texto,
      textAlign: TextAlign.end,
      style: pequeno.copyWith(color: cor),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(1.4),
            2: FlexColumnWidth(2.2),
            3: FlexColumnWidth(2),
            4: FlexColumnWidth(1.8),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(children: [for (var i = 0; i < 5; i++) cabecalho(i)]),
            for (final g in linhas)
              TableRow(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: tema.colorScheme.outlineVariant),
                  ),
                ),
                children: [
                  InkWell(
                    onTap: g.vendedorId == null
                        ? null
                        : () => widget.aoTocar?.call(g.vendedorId!),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        g.vendedorNome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: pequeno.copyWith(
                          color: tema.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  celula('${g.leads}'),
                  celula(formatarDuracao(g.tempoResposta.p50Seg)),
                  celula(
                    formatarPercentual(g.percentualForaSla),
                    cor: (g.percentualForaSla ?? 0) > 0 ? corForaDoSla : null,
                  ),
                  celula(
                    '${g.leadsAguardandoResposta}',
                    cor: g.leadsAguardandoResposta > 0 ? corAlerta : null,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
