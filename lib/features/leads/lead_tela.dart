import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tema.dart';
import '../../core/ciclo.dart';
import '../../core/compartilhar_arquivo.dart';
import '../../core/formatos.dart';
import '../../core/sessao/sessao.dart';
import '../../widgets/estados.dart';
import '../../widgets/navegacao.dart';
import '../../widgets/selos.dart';
import '../auditoria/painel_auditorias.dart';
import '../conversa/conversa_controller.dart';
import '../conversa/conversa_view.dart';
import 'leads_repo.dart';
import 'modelos.dart';

/// Lead: conversa, métricas e auditorias (F03 e F04). No celular, em abas; no
/// desktop, a conversa à esquerda e o painel à direita.
class LeadTela extends ConsumerStatefulWidget {
  const LeadTela({super.key, required this.id});

  final int id;

  @override
  ConsumerState<LeadTela> createState() => _LeadTelaState();
}

class _LeadTelaState extends ConsumerState<LeadTela> {
  // A conversa vive aqui, acima das abas: trocar de aba não reabre a conversa
  // (cada abertura é registrada como leitura no backend).
  late final _conversa = ConversaController(
    ref.read(leadsRepoProvider),
    widget.id,
  );
  bool _semConexao = false;

  bool _visivel() => mounted && rotaNoTopo(context, '/leads/${widget.id}');

  void _aoMudarFalha(bool falhando) {
    if (mounted) setState(() => _semConexao = falhando);
  }

  late final _novas = Ciclo(
    intervalo: const Duration(seconds: 5),
    tarefa: () async {
      // Mensagem nova muda o cabeçalho ("Sem resposta") e as métricas.
      if (await _conversa.buscarNovas() && mounted) {
        ref.invalidate(leadProvider(widget.id));
        ref.invalidate(metricasLeadProvider(widget.id));
      }
    },
    ativo: _visivel,
    aoMudarFalha: _aoMudarFalha,
  );
  late final _pendentes = Ciclo(
    intervalo: const Duration(seconds: 10),
    tarefa: _conversa.atualizarPendentes,
    ativo: _visivel,
  );

  @override
  void initState() {
    super.initState();
    _conversa.abrir();
    _novas.iniciar();
    _pendentes.iniciar();
  }

  @override
  void dispose() {
    _novas.parar();
    _pendentes.parar();
    _conversa.dispose();
    super.dispose();
  }

  Future<void> _exportar() async {
    await executarAcao(context, () async {
      final json = await ref.read(leadsRepoProvider).exportar(widget.id);
      await compartilharArquivo(
        nome: 'lead-${widget.id}.json',
        conteudo: json,
        tipo: 'application/json',
        assunto: 'Dados do cliente (lead ${widget.id})',
      );
    });
  }

  Future<void> _excluir(LeadDetalhe detalhe) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogoExcluir(detalhe),
    );
    if (confirmou != true || !mounted) return;
    final ok = await executarAcao(
      context,
      () => ref.read(leadsRepoProvider).excluir(widget.id),
      sucesso: 'Dados do cliente excluídos.',
    );
    if (!ok || !mounted) return;
    context.canPop() ? context.pop('excluido') : context.go('/leads');
  }

  @override
  Widget build(BuildContext context) {
    final valor = ref.watch(leadProvider(widget.id));
    final detalhe = valor.value;
    final admin = ref.watch(sessaoProvider.select((s) => s.admin));

    if (detalhe == null) {
      return Scaffold(
        appBar: AppBar(leading: const BotaoVoltar(destino: '/leads')),
        body: valor.hasError
            ? ErroTela(
                valor.error!,
                aoTentarDeNovo: () => ref.invalidate(leadProvider(widget.id)),
              )
            : const Carregando(),
      );
    }

    final lead = detalhe.lead;
    final conversa = Column(
      children: [
        AvisoConexao(visivel: _semConexao),
        Expanded(child: ConversaView(controle: _conversa)),
      ],
    );
    final metricas = _PainelMetricas(leadId: widget.id);
    final auditorias = PainelAuditorias(leadId: widget.id);
    final desktop = ehDesktop(context);

    return DefaultTabController(
      length: desktop ? 2 : 3,
      child: Scaffold(
        appBar: AppBar(
          leading: const BotaoVoltar(destino: '/leads'),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lead.nome, overflow: TextOverflow.ellipsis),
              Text(
                'Vendedor: ${lead.vendedorNome}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            // LGPD: exportar e excluir são só do admin (F06, itens 22 e 23).
            if (admin)
              PopupMenuButton<String>(
                tooltip: 'Dados do cliente (LGPD)',
                onSelected: (acao) =>
                    acao == 'exportar' ? _exportar() : _excluir(detalhe),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'exportar',
                    child: Text('Exportar dados do cliente'),
                  ),
                  PopupMenuItem(
                    value: 'excluir',
                    child: Text('Excluir dados do cliente'),
                  ),
                ],
              ),
          ],
          bottom: desktop
              ? null
              : const TabBar(
                  tabs: [
                    Tab(text: 'Conversa'),
                    Tab(text: 'Métricas'),
                    Tab(text: 'Auditorias'),
                  ],
                ),
        ),
        body: Column(
          children: [
            _Cabecalho(detalhe),
            Expanded(
              child: desktop
                  ? Row(
                      children: [
                        Expanded(flex: 3, child: conversa),
                        const VerticalDivider(width: 1),
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              const TabBar(
                                tabs: [
                                  Tab(text: 'Auditorias'),
                                  Tab(text: 'Métricas'),
                                ],
                              ),
                              Expanded(
                                child: TabBarView(
                                  children: [auditorias, metricas],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : TabBarView(children: [conversa, metricas, auditorias]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho(this.detalhe);

  final LeadDetalhe detalhe;

  @override
  Widget build(BuildContext context) {
    final lead = detalhe.lead;
    final tema = Theme.of(context);
    final ultima = detalhe.ultimaAuditoria;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (lead.telefone.isNotEmpty)
                Text(
                  formatarTelefone(lead.telefone),
                  style: tema.textTheme.bodySmall,
                ),
              SeloTemperatura(lead.temperatura),
              if (lead.probabilidadeConversao != null)
                Selo(
                  '${formatarProbabilidade(lead.probabilidadeConversao)} '
                  'de conversão',
                  cor: tema.colorScheme.primary,
                ),
              if (ultima != null)
                Selo(
                  ultima.notaGeral == null
                      ? 'sem nota'
                      : 'nota ${formatarNota(ultima.notaGeral)}',
                  cor: corDaNota(ultima.notaGeral),
                  icone: Icons.star,
                ),
              if (lead.aguardandoResposta)
                const Selo(
                  'Sem resposta',
                  cor: corAlerta,
                  icone: Icons.schedule,
                ),
            ],
          ),
          if (detalhe.outrosLeads.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Este cliente também está negociando com: ',
                    style: tema.textTheme.bodySmall,
                  ),
                  for (final outro in detalhe.outrosLeads)
                    InkWell(
                      onTap: () => context.push('/leads/${outro.id}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Text(
                          '${outro.vendedorNome} (ver)',
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Métricas de atendimento do lead (F03, itens 13 e 14).
class _PainelMetricas extends ConsumerWidget {
  const _PainelMetricas({required this.leadId});

  final int leadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ValorAssincrono(
          valor: ref.watch(metricasLeadProvider(leadId)),
          aoTentarDeNovo: () => ref.invalidate(metricasLeadProvider(leadId)),
          construir: (m) {
            Color? cor(int? segundos) => segundos == null
                ? null
                : (segundos <= m.slaRespostaSeg
                      ? corDentroDoSla
                      : corForaDoSla);
            String situacao(int? segundos) => segundos == null
                ? 'ainda sem resposta do vendedor'
                : (segundos <= m.slaRespostaSeg
                      ? 'dentro do SLA'
                      : 'fora do SLA');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SLA de resposta: ${formatarDuracao(m.slaRespostaSeg)}',
                        style: tema.textTheme.titleSmall,
                      ),
                    ),
                    const Tooltip(
                      message: 'Contado só no horário comercial da loja',
                      triggerMode: TooltipTriggerMode.tap,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.help_outline, size: 20),
                      ),
                    ),
                  ],
                ),
                if (m.aguardandoResposta)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Selo(
                      'Sem resposta há '
                      '${formatarDuracao(m.tempoSemRespostaSeg)}',
                      cor: cor(m.tempoSemRespostaSeg) ?? corAlerta,
                      icone: Icons.schedule,
                    ),
                  ),
                if (m.vendedorFezFollowup)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Selo(
                      'fez follow-up',
                      cor: corDentroDoSla,
                      icone: Icons.replay,
                    ),
                  ),
                CartaoIndicador(
                  titulo: 'Primeira resposta',
                  valor: formatarDuracao(m.tempoPrimeiraRespostaSeg),
                  detalhe: situacao(m.tempoPrimeiraRespostaSeg),
                  cor: cor(m.tempoPrimeiraRespostaSeg),
                ),
                const SizedBox(height: 8),
                CartaoIndicador(
                  titulo: 'Tempo médio de resposta',
                  valor: formatarDuracao(m.tempoMedioRespostaSeg),
                  detalhe: situacao(m.tempoMedioRespostaSeg),
                  cor: cor(m.tempoMedioRespostaSeg),
                ),
                const SizedBox(height: 8),
                CartaoIndicador(
                  titulo: 'Maior espera',
                  valor: formatarDuracao(m.tempoMaxRespostaSeg),
                  detalhe: situacao(m.tempoMaxRespostaSeg),
                  cor: cor(m.tempoMaxRespostaSeg),
                ),
                const SizedBox(height: 8),
                CartaoIndicador(
                  titulo: 'Respostas fora do SLA',
                  valor: '${m.respostasForaSla} de ${m.respostas}',
                  cor: m.respostasForaSla > 0 ? corForaDoSla : corDentroDoSla,
                ),
                const SizedBox(height: 8),
                CartaoIndicador(
                  titulo: 'Mensagens',
                  valor: '${m.totalMensagensLead + m.totalMensagensVendedor}',
                  detalhe:
                      '${m.totalMensagensLead} do cliente · '
                      '${m.totalMensagensVendedor} do vendedor',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Confirmação dupla da exclusão definitiva (F06, item 23).
class _DialogoExcluir extends StatefulWidget {
  const _DialogoExcluir(this.detalhe);

  final LeadDetalhe detalhe;

  @override
  State<_DialogoExcluir> createState() => _DialogoExcluirState();
}

class _DialogoExcluirState extends State<_DialogoExcluir> {
  bool _liberado = false;

  @override
  Widget build(BuildContext context) {
    final outros = widget.detalhe.outrosLeads;
    final cores = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Excluir dados do cliente'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A conversa e as auditorias desta negociação serão apagadas. '
              'A exclusão é definitiva.',
            ),
            if (outros.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Este cliente também negocia com '
                '${outros.map((o) => o.vendedorNome).join(', ')}. Os outros '
                'leads não são apagados: cada um precisa ser excluído '
                'separadamente.',
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Digite EXCLUIR para confirmar',
              ),
              onChanged: (v) =>
                  setState(() => _liberado = v.trim() == 'EXCLUIR'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: cores.error),
          onPressed: _liberado ? () => Navigator.pop(context, true) : null,
          child: const Text('Excluir definitivamente'),
        ),
      ],
    );
  }
}
