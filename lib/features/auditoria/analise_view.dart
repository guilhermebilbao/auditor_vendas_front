import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatos.dart';
import '../../widgets/estados.dart';
import '../../widgets/selos.dart';
import 'modelos.dart';

/// Análise da IA (F04, itens 5 a 9). Não rola sozinha: entra numa lista.
class AnaliseView extends StatelessWidget {
  const AnaliseView(this.analise, {super.key});

  final AnaliseIA analise;

  @override
  Widget build(BuildContext context) {
    final a = analise;
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Bloco(
          titulo: 'Nota do vendedor',
          filhos: [
            Row(
              children: [
                NotaDestaque(a.notaGeral, tamanho: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    a.notaGeral == null
                        ? 'Sem nota (auditoria antiga). Refaça a auditoria '
                              'para ter a nota por critério.'
                        : 'Nota geral de 0 a 10, ponderada pelos pesos da loja.',
                    style: tema.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            for (final c in criterios.entries)
              if (a.avaliacao[c.key] case final criterio?)
                _LinhaCriterio(c.value, criterio),
          ],
        ),
        _Bloco(
          titulo: 'Lead',
          filhos: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                SeloTemperatura(a.temperatura),
                if (a.probabilidadeConversao != null)
                  Selo(
                    '${formatarProbabilidade(a.probabilidadeConversao)} '
                    'de conversão',
                    cor: tema.colorScheme.primary,
                  ),
              ],
            ),
            _Dado('Estágio da jornada', a.estagioJornada),
            _Dado('Urgência de compra', a.urgenciaCompra),
          ],
        ),
        _Bloco(
          titulo: 'Negócio',
          filhos: [
            _Dado('Veículo de interesse', a.veiculoInteresse),
            _Dado('Carro na troca', switch (a.temCarroNaTroca) {
              true => 'Sim',
              false => 'Não',
              null => 'Não mencionado',
            }),
            _Dado('Forma de pagamento', a.formaPagamento),
          ],
        ),
        _Bloco(
          titulo: 'Análise técnica',
          filhos: [
            _Lista(
              'Pontos fortes',
              a.pontosFortes,
              Icons.check_circle,
              corDentroDoSla,
            ),
            _Lista(
              'Falhas e gargalos',
              a.falhas,
              Icons.warning_amber,
              corAlerta,
            ),
            _Lista(
              'Objeções levantadas',
              a.objecoes,
              Icons.help_outline,
              tema.colorScheme.outline,
            ),
          ],
        ),
        _Bloco(
          titulo: 'Plano de ação',
          acao: a.feedbackVendedor.isEmpty
              ? null
              : TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: a.feedbackVendedor),
                    );
                    if (context.mounted) snack(context, 'Feedback copiado');
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copiar'),
                ),
          filhos: [
            Text('Feedback para o vendedor', style: tema.textTheme.labelLarge),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tema.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                a.feedbackVendedor.isEmpty ? '—' : a.feedbackVendedor,
              ),
            ),
            _Lista(
              'Próximos passos sugeridos',
              a.proximosPassos,
              Icons.check_box_outline_blank,
              tema.colorScheme.primary,
            ),
          ],
        ),
      ],
    );
  }
}

class _Bloco extends StatelessWidget {
  const _Bloco({required this.titulo, required this.filhos, this.acao});

  final String titulo;
  final List<Widget> filhos;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      titulo,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ?acao,
                ],
              ),
              const SizedBox(height: 10),
              ...filhos,
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhaCriterio extends StatelessWidget {
  const _LinhaCriterio(this.rotulo, this.criterio);

  final String rotulo;
  final Criterio criterio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final nota = criterio.nota;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(rotulo, style: tema.textTheme.titleSmall)),
              Text(
                formatarCriterio(nota),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: nota == null
                      ? tema.colorScheme.outline
                      : corDaNota(nota.toDouble()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Critério sem nota não vira zero: a barra fica vazia e cinza.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (nota ?? 0) / 10,
              minHeight: 8,
              color: corDaNota(nota?.toDouble()),
              backgroundColor: tema.colorScheme.surfaceContainerHighest,
            ),
          ),
          if (criterio.justificativa.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(criterio.justificativa, style: tema.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _Dado extends StatelessWidget {
  const _Dado(this.rotulo, this.valor);

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: tema.textTheme.labelMedium),
          Text(valor.isEmpty ? '—' : valor),
        ],
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista(this.titulo, this.itens, this.icone, this.cor);

  final String titulo;
  final List<String> itens;
  final IconData icone;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: tema.textTheme.labelLarge),
          if (itens.isEmpty)
            Text('Nenhum item.', style: tema.textTheme.bodySmall),
          for (final item in itens)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icone, size: 18, color: cor),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
