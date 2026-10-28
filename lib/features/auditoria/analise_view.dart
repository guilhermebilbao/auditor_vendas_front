import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatos.dart';
import '../../widgets/estados.dart';
import '../../widgets/selos.dart';
import 'modelos.dart';

enum _Aba { vendedor, cliente }

/// Análise da IA (F04, itens 5 a 9, e spec 21, etapa 2): o resumo lado a lado
/// e as abas Vendedor e Cliente. Não rola sozinha: entra numa lista.
class AnaliseView extends StatefulWidget {
  const AnaliseView(this.analise, {super.key, this.aoRefazer});

  final AnaliseIA analise;

  /// Refaz a auditoria (`?forcar=true`); oferecido quando a análise do cliente
  /// não existe (auditoria anterior ao prompt v3).
  final VoidCallback? aoRefazer;

  @override
  State<AnaliseView> createState() => _AnaliseViewState();
}

class _AnaliseViewState extends State<AnaliseView> {
  var _aba = _Aba.vendedor;

  @override
  Widget build(BuildContext context) {
    final a = widget.analise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (a.cliente != null) _ResumoLadoALado(a),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SegmentedButton<_Aba>(
            segments: const [
              ButtonSegment(
                value: _Aba.vendedor,
                label: Text('Vendedor'),
                icon: Icon(Icons.badge_outlined),
              ),
              ButtonSegment(
                value: _Aba.cliente,
                label: Text('Cliente'),
                icon: Icon(Icons.person_outline),
              ),
            ],
            selected: {_aba},
            onSelectionChanged: (s) => setState(() => _aba = s.first),
          ),
        ),
        if (_aba == _Aba.vendedor)
          _AbaVendedor(a)
        else if (a.cliente case final cliente?)
          _AbaCliente(cliente, a.indiceDificuldadeCliente)
        else
          _SemAnaliseDoCliente(widget.aoRefazer),
      ],
    );
  }
}

/// Nota do vendedor e dificuldade do cliente lado a lado (spec 21, etapa 2, item 1).
class _ResumoLadoALado extends StatelessWidget {
  const _ResumoLadoALado(this.analise);

  final AnaliseIA analise;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final indice = analise.indiceDificuldadeCliente;
    final faixa =
        analise.faixaDificuldadeCliente ??
        (indice == null ? null : faixaDificuldade(indice));
    return _Bloco(
      titulo: 'Resumo',
      filhos: [
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  NotaDestaque(analise.notaGeral, tamanho: 28),
                  const SizedBox(height: 4),
                  Text('Nota do vendedor', style: tema.textTheme.labelMedium),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  DificuldadeDestaque(indice, tamanho: 28),
                  const SizedBox(height: 4),
                  Text(
                    'Dificuldade do cliente',
                    style: tema.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _fraseDeContexto(analise.notaGeral, faixa),
          textAlign: TextAlign.center,
          style: tema.textTheme.bodyMedium,
        ),
        if (analise.cliente!.perfil.isNotEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: Selo(
              analise.cliente!.perfil,
              cor: corDaDificuldade(indice),
              icone: Icons.person_outline,
            ),
          ),
        ],
      ],
    );
  }

  static String _fraseDeContexto(double? nota, String? faixa) {
    final notaTexto = nota == null
        ? 'Vendedor sem nota'
        : 'Nota ${formatarNota(nota)}';
    if (faixa == null) return '$notaTexto; dificuldade do cliente não avaliada';
    return '$notaTexto com um cliente de dificuldade ${faixa.toLowerCase()}';
  }
}

class _AbaVendedor extends StatelessWidget {
  const _AbaVendedor(this.a);

  final AnaliseIA a;

  @override
  Widget build(BuildContext context) {
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

/// Aba Cliente (spec 21, etapa 2, item 3).
class _AbaCliente extends StatelessWidget {
  const _AbaCliente(this.cliente, this.indice);

  final AvaliacaoCliente cliente;
  final double? indice;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Bloco(
          titulo: 'Comportamento do cliente',
          filhos: [
            Row(
              children: [
                DificuldadeDestaque(indice, tamanho: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Quanto o cliente dificultou a negociação, de 0 '
                    '(facilitou) a 10 (dificultou muito). Não é uma nota '
                    'do cliente nem do vendedor.',
                    style: tema.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            for (final c in criteriosCliente.entries)
              if (cliente.criterios[c.key] case final criterio?)
                _LinhaDificuldade(c.value, criterio),
          ],
        ),
        _Bloco(
          titulo: 'Comportamentos observados',
          filhos: [
            if (cliente.comportamentos.isEmpty)
              Text('Nenhum item.', style: tema.textTheme.bodySmall),
            for (final c in cliente.comportamentos)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      c.dificultou ? Icons.trending_down : Icons.trending_up,
                      size: 18,
                      color: c.dificultou ? corAlerta : corDentroDoSla,
                      semanticLabel: c.dificultou ? 'dificultou' : 'facilitou',
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(c.descricao)),
                  ],
                ),
              ),
            if (cliente.fatoresExternos.isNotEmpty)
              _Lista(
                'Fatores externos (não dependiam de ninguém na conversa)',
                cliente.fatoresExternos,
                Icons.public,
                tema.colorScheme.outline,
              ),
          ],
        ),
        _Bloco(
          titulo: 'Leitura imparcial',
          filhos: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tema.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                cliente.leituraImparcial.isEmpty
                    ? '—'
                    : cliente.leituraImparcial,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use esta análise só para entender o contexto do atendimento, '
              'nunca para decisões sobre o cliente.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.outline,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Auditoria anterior ao prompt v3 (spec 21, etapa 2, item 5).
class _SemAnaliseDoCliente extends StatelessWidget {
  const _SemAnaliseDoCliente(this.aoRefazer);

  final VoidCallback? aoRefazer;

  @override
  Widget build(BuildContext context) {
    return _Bloco(
      titulo: 'Análise do cliente',
      filhos: [
        const Text(
          'A análise do cliente não existe nesta auditoria, que foi feita '
          'antes desse recurso.',
        ),
        if (aoRefazer != null) ...[
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: aoRefazer,
            icon: const Icon(Icons.refresh),
            label: const Text('Refazer auditoria'),
          ),
        ],
      ],
    );
  }
}

class _LinhaDificuldade extends StatelessWidget {
  const _LinhaDificuldade(this.rotulo, this.criterio);

  final String rotulo;
  final CriterioCliente criterio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final valor = criterio.dificuldade?.toDouble();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(rotulo, style: tema.textTheme.titleSmall)),
              Text(
                formatarDificuldade(criterio.dificuldade),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: valor == null
                      ? tema.colorScheme.outline
                      : corDaDificuldade(valor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Critério sem valor não vira zero: a barra fica vazia e cinza.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (valor ?? 0) / 10,
              minHeight: 8,
              color: corDaDificuldade(valor),
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
