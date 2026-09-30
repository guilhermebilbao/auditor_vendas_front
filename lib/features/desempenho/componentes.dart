import 'package:flutter/material.dart';

import '../../core/formatos.dart';
import '../../widgets/selos.dart';
import 'modelos.dart';

/// Hoje, 7 dias, 30 dias ou personalizado (F05, item 1).
class SeletorPeriodo extends StatelessWidget {
  const SeletorPeriodo({
    super.key,
    required this.periodo,
    required this.aoMudar,
  });

  final Periodo periodo;
  final ValueChanged<Periodo> aoMudar;

  Future<void> _personalizar(BuildContext context) async {
    final hoje = hojeNaLoja();
    final escolhido = await showDateRangePicker(
      context: context,
      firstDate: DateTime(hoje.year - 3),
      lastDate: hoje,
      initialDateRange: DateTimeRange(
        start: DateTime.tryParse(periodo.desde) ?? hoje,
        end: DateTime.tryParse(periodo.ate) ?? hoje,
      ),
    );
    if (escolhido == null) return;
    aoMudar(
      Periodo(
        'personalizado',
        dataIso(escolhido.start),
        dataIso(escolhido.end),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final personalizado = periodo.tipo == 'personalizado';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final e in Periodo.rotulos.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(e.value),
                selected: periodo.tipo == e.key,
                onSelected: (_) => aoMudar(Periodo.deTipo(e.key)),
              ),
            ),
          ChoiceChip(
            avatar: personalizado
                ? null
                : const Icon(Icons.date_range, size: 18),
            label: Text(personalizado ? periodo.rotulo : 'Personalizado'),
            selected: personalizado,
            onSelected: (_) => _personalizar(context),
          ),
        ],
      ),
    );
  }
}

/// Distribui os cartões em colunas conforme a largura disponível.
class GradeCartoes extends StatelessWidget {
  const GradeCartoes({super.key, required this.filhos});

  final List<Widget> filhos;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, limites) {
        final largura = limites.maxWidth;
        final colunas = largura >= 900 ? 5 : (largura >= 560 ? 3 : 2);
        const espaco = 8.0;
        final larguraCartao = (largura - espaco * (colunas - 1)) / colunas;
        return Wrap(
          spacing: espaco,
          runSpacing: espaco,
          children: [
            for (final filho in filhos)
              SizedBox(width: larguraCartao.floorToDouble(), child: filho),
          ],
        );
      },
    );
  }
}

/// Os cartões de atendimento do painel e da tela do vendedor (F05, itens 2 e 11).
class CartoesMetricas extends StatelessWidget {
  const CartoesMetricas(this.metricas, {super.key, this.aoTocarSemResposta});

  final MetricasAgregadas metricas;
  final VoidCallback? aoTocarSemResposta;

  @override
  Widget build(BuildContext context) {
    final t = metricas.total;
    final foraSla = t.percentualForaSla;
    return GradeCartoes(
      filhos: [
        CartaoIndicador(
          titulo: 'Clientes sem resposta agora',
          valor: '${t.leadsAguardandoResposta}',
          cor: t.leadsAguardandoResposta > 0 ? corAlerta : null,
          aoTocar: aoTocarSemResposta,
        ),
        CartaoIndicador(
          titulo: 'Tempo de resposta típico',
          valor: formatarDuracao(t.tempoResposta.p50Seg),
          detalhe: t.tempoResposta.p90Seg == null
              ? null
              : '9 em cada 10 respostas em até '
                    '${formatarDuracao(t.tempoResposta.p90Seg)}',
        ),
        CartaoIndicador(
          titulo: 'Primeira resposta típica',
          valor: formatarDuracao(t.tempoPrimeiraResposta.p50Seg),
        ),
        CartaoIndicador(
          titulo: 'Respostas fora do SLA',
          valor: formatarPercentual(foraSla),
          detalhe: 'SLA: ${formatarDuracao(metricas.slaRespostaSeg)}',
          cor: foraSla == null
              ? null
              : (foraSla > 0 ? corForaDoSla : corDentroDoSla),
        ),
        CartaoIndicador(titulo: 'Leads com atividade', valor: '${t.leads}'),
      ],
    );
  }
}
