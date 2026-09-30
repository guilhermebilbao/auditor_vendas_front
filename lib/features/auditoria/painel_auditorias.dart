import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/erros.dart';
import '../../core/formatos.dart';
import '../../widgets/estados.dart';
import '../../widgets/selos.dart';
import 'analise_view.dart';
import 'auditoria_repo.dart';
import 'modelos.dart';

/// Na tela do lead: pedir a auditoria, ver o resultado e o histórico
/// (F04, itens 1 a 4 e 11 a 13).
class PainelAuditorias extends ConsumerWidget {
  const PainelAuditorias({super.key, required this.leadId});

  final int leadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(auditarProvider(leadId));
    final pedido = ref.read(auditarProvider(leadId).notifier);
    final historico = ref.watch(historicoAuditoriasProvider(leadId));
    final tema = Theme.of(context);
    final resultado = estado.resultado;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // A IA só roda quando alguém pede: a auditoria nasce deste botão.
        FilledButton.icon(
          onPressed: estado.emAndamento ? null : pedido.auditar,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Auditar conversa'),
        ),
        if (estado.emAndamento) _Progresso(estado.iniciadaEm!),
        if (estado.erro != null)
          _Aviso(
            mensagemDoErro(estado.erro!),
            cor: tema.colorScheme.error,
            acao: podeTentarDeNovo(estado.erro!) ? 'Tentar de novo' : null,
            aoAgir: pedido.auditar,
          ),
        if (resultado != null) ...[
          if (resultado.reutilizada)
            _Aviso(
              'Nenhuma mensagem nova desde a última auditoria. Este é o '
              'resultado anterior.',
              cor: corAlerta,
              acao: 'Refazer mesmo assim',
              aoAgir: () => pedido.auditar(forcar: true),
            ),
          if (resultado.transcricoesPendentes > 0)
            _Aviso(
              '${resultado.transcricoesPendentes} áudio(s) ainda sem '
              'transcrição ficaram de fora.',
              cor: corAlerta,
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('Resultado', style: tema.textTheme.titleMedium),
              ),
              if (resultado.auditoriaId case final id?)
                TextButton(
                  onPressed: () => context.push('/auditorias/$id'),
                  child: const Text('Registrar feedback'),
                ),
              IconButton(
                tooltip: 'Fechar o resultado',
                onPressed: pedido.limpar,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          AnaliseView(resultado.analise),
        ],
        const TituloSecao('Histórico de auditorias'),
        ValorAssincrono(
          valor: historico,
          aoTentarDeNovo: () =>
              ref.invalidate(historicoAuditoriasProvider(leadId)),
          linhas: 2,
          construir: (itens) => itens.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Esta conversa ainda não foi auditada.'),
                )
              : Column(
                  children: [
                    for (var i = 0; i < itens.length; i++)
                      ItemHistorico(
                        itens[i],
                        anterior: i + 1 < itens.length ? itens[i + 1] : null,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Mensagens em sequência durante a espera, que pode passar de um minuto.
class _Progresso extends StatefulWidget {
  const _Progresso(this.iniciadaEm);

  final DateTime iniciadaEm;

  @override
  State<_Progresso> createState() => _ProgressoState();
}

class _ProgressoState extends State<_Progresso> {
  late final Timer _relogio;

  @override
  void initState() {
    super.initState();
    _relogio = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _relogio.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final segundos = DateTime.now().difference(widget.iniciadaEm).inSeconds;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(
            segundos < 20
                ? 'Analisando a conversa…'
                : 'A IA está avaliando o atendimento…',
          ),
          Text(
            'Pode levar mais de um minuto. Você pode sair desta tela: o '
            'resultado aparece no histórico.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto, {required this.cor, this.acao, this.aoAgir});

  final String texto;
  final Color cor;
  final String? acao;
  final VoidCallback? aoAgir;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(texto),
          if (acao != null) TextButton(onPressed: aoAgir, child: Text(acao!)),
        ],
      ),
    );
  }
}

class ItemHistorico extends StatelessWidget {
  const ItemHistorico(this.auditoria, {super.key, this.anterior});

  final ResumoAuditoria auditoria;

  /// A auditoria imediatamente anterior, para mostrar a variação da nota.
  final ResumoAuditoria? anterior;

  @override
  Widget build(BuildContext context) {
    final a = auditoria;
    final tema = Theme.of(context);
    final notaAnterior = anterior?.notaGeral;
    final variacao = a.notaGeral != null && notaAnterior != null
        ? a.notaGeral! - notaAnterior
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/auditorias/${a.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                NotaDestaque(a.notaGeral),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatarDataHora(a.criadoEm),
                        style: tema.textTheme.titleSmall,
                      ),
                      if (a.notaGeral == null)
                        Text(
                          'sem nota (auditoria antiga)',
                          style: tema.textTheme.bodySmall,
                        ),
                      if (variacao != null)
                        Text(
                          '${formatarVariacao(variacao)} desde a anterior',
                          style: tema.textTheme.bodySmall,
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          SeloTemperatura(a.temperatura),
                          Selo(
                            formatarProbabilidade(a.probabilidadeConversao),
                            cor: tema.colorScheme.primary,
                          ),
                          if (a.feedbackEntregueEm != null)
                            const Selo(
                              'feedback entregue',
                              cor: corDentroDoSla,
                              icone: Icons.check,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
