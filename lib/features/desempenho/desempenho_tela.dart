import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatos.dart';
import '../../widgets/estados.dart';
import '../../widgets/selos.dart';
import 'componentes.dart';
import 'desempenho_repo.dart';
import 'modelos.dart';

/// Ranking da equipe (F05, itens 6 a 8).
class DesempenhoTela extends ConsumerWidget {
  const DesempenhoTela({super.key, required this.periodo});

  final Periodo periodo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consulta = (desde: periodo.desde, ate: periodo.ate);
    final ranking = ref.watch(rankingProvider(consulta));
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Desempenho da equipe')),
      body: RefreshIndicator(
        onRefresh: () => ref
            .refresh(rankingProvider(consulta).future)
            .then((_) {}, onError: (_) {}),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            SeletorPeriodo(
              periodo: periodo,
              aoMudar: (p) => context.go(
                Uri(
                  path: '/desempenho',
                  queryParameters: p.paraQuery(),
                ).toString(),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tema.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'O ranking considera a última auditoria de cada negociação '
                'no período. Negociações sem auditoria não entram: audite '
                'para incluí-las.',
                style: TextStyle(color: tema.colorScheme.onSecondaryContainer),
              ),
            ),
            const SizedBox(height: 12),
            ValorAssincrono(
              valor: ranking,
              aoTentarDeNovo: () => ref.invalidate(rankingProvider(consulta)),
              construir: (itens) => itens.isEmpty
                  ? const Vazio('Nenhum vendedor cadastrado.')
                  : Column(
                      children: [
                        for (final item in itens)
                          ItemRankingCartao(
                            item,
                            aoTocar: () => context.push(
                              Uri(
                                path: '/vendedores/${item.vendedorId}',
                                queryParameters: periodo.paraQuery(),
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
}

class ItemRankingCartao extends StatefulWidget {
  const ItemRankingCartao(this.item, {super.key, this.aoTocar});

  final ItemRanking item;
  final VoidCallback? aoTocar;

  @override
  State<ItemRankingCartao> createState() => _ItemRankingCartaoState();
}

class _ItemRankingCartaoState extends State<ItemRankingCartao> {
  bool _aberto = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final tema = Theme.of(context);
    final atendimento = item.atendimento;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: widget.aoTocar,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        // Sem auditoria com nota no período: sem posição.
                        item.posicao == null ? '—' : '${item.posicao}º',
                        style: tema.textTheme.titleLarge,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                item.vendedorNome,
                                style: tema.textTheme.titleSmall,
                              ),
                              if (!item.ativo)
                                const Selo('inativo', cor: Colors.grey),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.leadsAuditados} lead(s) auditado(s) · '
                            'conversão média '
                            '${formatarProbabilidade(item.probabilidadeMedia)}',
                            style: tema.textTheme.bodySmall,
                          ),
                          if (atendimento != null && atendimento.respostas > 0)
                            Text(
                              'resposta típica '
                              '${formatarDuracao(atendimento.tempoResposta.p50Seg)}'
                              ' · ${formatarPercentual(atendimento.percentualForaSla)}'
                              ' fora do SLA',
                              style: tema.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    NotaDestaque(item.notaMedia),
                    IconButton(
                      tooltip: _aberto
                          ? 'Ocultar os critérios'
                          : 'Mostrar os critérios',
                      icon: Icon(
                        _aberto ? Icons.expand_less : Icons.expand_more,
                      ),
                      onPressed: () => setState(() => _aberto = !_aberto),
                    ),
                  ],
                ),
              ),
            ),
            if (_aberto)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  children: [
                    for (final c in criterios.entries)
                      BarraNota(
                        rotulo: c.value,
                        nota: item.notasCriterios[c.key],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
