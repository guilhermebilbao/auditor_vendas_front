import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/erros.dart';
import '../../core/formatos.dart';
import '../../widgets/estados.dart';
import '../../widgets/navegacao.dart';
import '../../widgets/selos.dart';
import '../admin/selo_whatsapp.dart';
import '../leads/modelos.dart';
import 'componentes.dart';
import 'atuacao_repo.dart';
import 'modelos.dart';

/// Vendedor: evolução, métricas e pontos de melhoria (F05, itens 9 a 13).
class VendedorTela extends ConsumerStatefulWidget {
  const VendedorTela({super.key, required this.id, required this.periodo});

  final int id;
  final Periodo periodo;

  @override
  ConsumerState<VendedorTela> createState() => _VendedorTelaState();
}

class _VendedorTelaState extends ConsumerState<VendedorTela> {
  late Periodo _periodo = widget.periodo;
  String _agrupamento = 'semana';
  bool _mostrarCriterios = false;

  // Pontos de melhoria: só carregam por ação do usuário, porque chamam a IA.
  bool _gerando = false;
  PontosMelhoria? _pontos;
  Object? _erroPontos;

  Future<void> _gerarPontos() async {
    setState(() {
      _gerando = true;
      _erroPontos = null;
    });
    try {
      final pontos = await ref
          .read(atuacaoRepoProvider)
          .pontosDeMelhoria(
            widget.id,
            desde: _periodo.desde,
            ate: _periodo.ate,
          );
      if (mounted) setState(() => _pontos = pontos);
    } catch (e) {
      if (mounted) setState(() => _erroPontos = e);
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendedor = ref.watch(vendedorProvider(widget.id));
    final consultaEvolucao = (vendedorId: widget.id, agrupamento: _agrupamento);
    final ConsultaMetricas consultaMetricas = (
      desde: _periodo.desde,
      ate: _periodo.ate,
      vendedorId: widget.id,
    );
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const BotaoVoltar(destino: '/desempenho'),
        title: Text(vendedor.value?.nome ?? 'Vendedor'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          ValorAssincrono(
            valor: vendedor,
            linhas: 1,
            aoTentarDeNovo: () => ref.invalidate(vendedorProvider(widget.id)),
            construir: (v) {
              final (rotulo, cor) = seloDoWhatsApp(v.instancia);
              return Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Selo(
                    v.ativo ? 'ativo' : 'inativo',
                    cor: v.ativo ? corDentroDoSla : Colors.grey,
                  ),
                  Selo(rotulo, cor: cor, icone: Icons.chat_outlined),
                ],
              );
            },
          ),
          TituloSecao(
            'Evolução da nota',
            acao: SegmentedButton<String>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: 'semana', label: Text('Semana')),
                ButtonSegment(value: 'mes', label: Text('Mês')),
              ],
              selected: {_agrupamento},
              onSelectionChanged: (s) => setState(() => _agrupamento = s.first),
            ),
          ),
          ValorAssincrono(
            valor: ref.watch(evolucaoProvider(consultaEvolucao)),
            aoTentarDeNovo: () =>
                ref.invalidate(evolucaoProvider(consultaEvolucao)),
            construir: (pontos) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GraficoEvolucao(pontos, mostrarCriterios: _mostrarCriterios),
                if (pontos.any((p) => p.notaMedia != null))
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Mostrar os critérios'),
                    value: _mostrarCriterios,
                    onChanged: (v) => setState(() => _mostrarCriterios = v),
                  ),
              ],
            ),
          ),
          const TituloSecao('Atendimento'),
          SeletorPeriodo(
            periodo: _periodo,
            aoMudar: (p) => setState(() {
              _periodo = p;
              _pontos = null;
              _erroPontos = null;
            }),
          ),
          const SizedBox(height: 12),
          ValorAssincrono(
            valor: ref.watch(metricasProvider(consultaMetricas)),
            aoTentarDeNovo: () =>
                ref.invalidate(metricasProvider(consultaMetricas)),
            construir: (m) => CartoesMetricas(
              m,
              aoTocarSemResposta: () => context.go(
                FiltrosLeads(
                  vendedorId: widget.id,
                  aguardandoResposta: true,
                ).paraRota(),
              ),
            ),
          ),
          const TituloSecao('Pontos de melhoria'),
          Text(
            'A IA resume os temas que mais aparecem nas auditorias do '
            'vendedor no período (${_periodo.rotulo}).',
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _gerando ? null : _gerarPontos,
            icon: const Icon(Icons.auto_awesome),
            label: Text(
              _gerando ? 'Gerando…' : 'Gerar pontos de melhoria do período',
            ),
          ),
          if (_gerando)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          if (_erroPontos != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                mensagemDoErro(_erroPontos!) +
                    (podeTentarDeNovo(_erroPontos!)
                        ? ' Toque no botão para tentar de novo.'
                        : ''),
                style: TextStyle(color: tema.colorScheme.error),
              ),
            ),
          if (_pontos != null) PontosMelhoriaView(_pontos!),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () =>
                context.go(FiltrosLeads(vendedorId: widget.id).paraRota()),
            icon: const Icon(Icons.forum_outlined),
            label: const Text('Ver os leads do vendedor'),
          ),
        ],
      ),
    );
  }
}

class PontosMelhoriaView extends StatelessWidget {
  const PontosMelhoriaView(this.resultado, {super.key});

  final PontosMelhoria resultado;

  @override
  Widget build(BuildContext context) {
    final r = resultado;
    final tema = Theme.of(context);
    if (r.auditoriasConsideradas == 0) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text('Não há auditorias do vendedor no período.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            [
              if (r.geradoEm != null)
                'Gerado em ${formatarDataHora(r.geradoEm)}',
              if (r.doCache)
                'resultado salvo; não houve auditoria nova desde então',
            ].join(' · '),
            style: tema.textTheme.bodySmall,
          ),
        ),
        if (r.pontos.isEmpty)
          const Text('A IA não encontrou temas recorrentes no período.'),
        for (final p in r.pontos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.titulo, style: tema.textTheme.titleSmall),
                    Text(
                      'apareceu em ${p.ocorrencias} de '
                      '${r.auditoriasConsideradas} auditorias',
                      style: tema.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(p.descricao),
                    if (p.sugestao.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 18,
                            color: tema.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(p.sugestao)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

const _coresCriterios = [
  Color(0xFF1976D2),
  Color(0xFF8E24AA),
  Color(0xFF00897B),
  Color(0xFFEF6C00),
  Color(0xFF5D4037),
  Color(0xFFC2185B),
];

/// Nota média por semana ou mês. Períodos sem nota quebram a linha: não são
/// ligados como se fossem zero (F05, item 10).
class GraficoEvolucao extends StatelessWidget {
  const GraficoEvolucao(
    this.pontos, {
    super.key,
    this.mostrarCriterios = false,
  });

  final List<PontoEvolucao> pontos;
  final bool mostrarCriterios;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    if (pontos.every((p) => p.notaMedia == null)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('Ainda não há auditorias com nota neste intervalo.'),
      );
    }

    List<FlSpot> serie(double? Function(PontoEvolucao) nota) => [
      for (var i = 0; i < pontos.length; i++)
        if (nota(pontos[i]) case final valor?)
          FlSpot(i.toDouble(), valor)
        else
          FlSpot.nullSpot,
    ];

    LineChartBarData linha(List<FlSpot> spots, Color cor, double largura) =>
        LineChartBarData(
          spots: spots,
          color: cor,
          barWidth: largura,
          dotData: FlDotData(show: largura > 2),
        );

    final nomes = criterios.entries.toList();
    String dia(String iso) {
      final partes = iso.split('-');
      return partes.length == 3 ? '${partes[2]}/${partes[1]}' : iso;
    }

    final passo = (pontos.length / 4).ceil().clamp(1, 12).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 220,
          child: Padding(
            padding: const EdgeInsets.only(top: 12, right: 12),
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 10,
                minX: 0,
                maxX: (pontos.length - 1).clamp(1, 1000).toDouble(),
                gridData: const FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 2,
                      reservedSize: 28,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: passo,
                      reservedSize: 28,
                      getTitlesWidget: (valor, meta) {
                        final i = valor.round();
                        if (i != valor || i < 0 || i >= pontos.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            dia(pontos[i].inicio),
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (tocados) => [
                      for (final t in tocados)
                        if (t.barIndex == 0)
                          LineTooltipItem(
                            '${dia(pontos[t.x.round()].inicio)}\n'
                            'nota ${formatarNota(t.y)}\n'
                            '${pontos[t.x.round()].auditorias} auditoria(s)',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          )
                        else
                          LineTooltipItem(
                            '${nomes[t.barIndex - 1].value}: '
                            '${formatarNota(t.y)}',
                            const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                    ],
                  ),
                ),
                lineBarsData: [
                  linha(serie((p) => p.notaMedia), tema.colorScheme.primary, 3),
                  if (mostrarCriterios)
                    for (var i = 0; i < nomes.length; i++)
                      linha(
                        serie((p) => p.notasCriterios[nomes[i].key]),
                        _coresCriterios[i],
                        1.5,
                      ),
                ],
              ),
            ),
          ),
        ),
        if (mostrarCriterios)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Legenda('Nota média', tema.colorScheme.primary),
                for (var i = 0; i < nomes.length; i++)
                  _Legenda(nomes[i].value, _coresCriterios[i]),
              ],
            ),
          ),
      ],
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda(this.texto, this.cor);

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 3, color: cor),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
