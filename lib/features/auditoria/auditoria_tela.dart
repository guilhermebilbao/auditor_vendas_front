import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatos.dart';
import '../../widgets/estados.dart';
import '../../widgets/navegacao.dart';
import 'analise_view.dart';
import 'auditoria_repo.dart';
import 'modelos.dart';

/// Auditoria completa, com o registro do feedback (F04, itens 10 e 14 a 16).
class AuditoriaTela extends ConsumerStatefulWidget {
  const AuditoriaTela({super.key, required this.id});

  final int id;

  @override
  ConsumerState<AuditoriaTela> createState() => _AuditoriaTelaState();
}

class _AuditoriaTelaState extends ConsumerState<AuditoriaTela> {
  final _observacao = TextEditingController();
  Timer? _espera;

  /// A resposta mais recente de um `PATCH`; substitui o que veio do `GET`.
  Auditoria? _atualizada;
  bool _observacaoCarregada = false;
  bool _salvando = false;
  String _estadoObservacao = '';

  late final _repo = ref.read(auditoriaRepoProvider);

  @override
  void initState() {
    super.initState();
    _repo; // lido aqui porque o `ref` não pode ser usado no dispose
  }

  @override
  void dispose() {
    // Saiu antes do salvamento automático: salva o que foi digitado.
    if (_espera?.isActive ?? false) {
      _repo
          .atualizar(widget.id, observacaoGerente: _observacao.text.trim())
          .then((_) {}, onError: (_) {});
    }
    _espera?.cancel();
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _salvar({bool? feedbackEntregue, String? observacao}) async {
    setState(() => _salvando = true);
    try {
      final auditoria = await _repo.atualizar(
        widget.id,
        feedbackEntregue: feedbackEntregue,
        observacaoGerente: observacao,
      );
      if (!mounted) return;
      setState(() {
        _atualizada = auditoria;
        if (observacao != null) _estadoObservacao = 'Observação salva';
      });
      // O histórico do lead mostra o selo "feedback entregue".
      ref.invalidate(historicoAuditoriasProvider(auditoria.leadId));
    } catch (e) {
      if (!mounted) return;
      if (observacao != null) setState(() => _estadoObservacao = '');
      snackErro(context, e);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // Salva sozinho depois de 1s sem digitar (F04, item 15).
  void _aoDigitar(String texto) {
    _espera?.cancel();
    setState(() => _estadoObservacao = 'Salvando…');
    _espera = Timer(
      const Duration(seconds: 1),
      () => _salvar(observacao: texto.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final valor = ref.watch(auditoriaProvider(widget.id));
    final auditoria = _atualizada ?? valor.value;

    if (auditoria != null && !_observacaoCarregada) {
      _observacaoCarregada = true;
      _observacao.text = auditoria.observacaoGerente;
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BotaoVoltar(destino: '/leads'),
        title: const Text('Auditoria'),
        actions: [
          if (auditoria != null)
            TextButton(
              onPressed: () => context.push('/leads/${auditoria.leadId}'),
              child: const Text('Ver conversa'),
            ),
        ],
      ),
      body: auditoria == null
          ? (valor.hasError
                ? ErroTela(
                    valor.error!,
                    aoTentarDeNovo: () =>
                        ref.invalidate(auditoriaProvider(widget.id)),
                  )
                : const Carregando())
          : _conteudo(auditoria),
    );
  }

  Widget _conteudo(Auditoria a) {
    final tema = Theme.of(context);
    final entregueEm = a.resumo.feedbackEntregueEm;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Vendedor: ${a.resumo.vendedorNome}',
          style: tema.textTheme.titleMedium,
        ),
        Text(
          'Auditada em ${formatarDataHora(a.resumo.criadoEm)}',
          style: tema.textTheme.bodySmall,
        ),
        if (a.transcricoesPendentes > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${a.transcricoesPendentes} áudio(s) ainda sem transcrição '
              'ficaram de fora desta análise.',
              style: TextStyle(color: tema.colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        AnaliseView(a.analise),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Feedback ao vendedor', style: tema.textTheme.titleMedium),
                const SizedBox(height: 10),
                if (entregueEm == null)
                  FilledButton.icon(
                    onPressed: _salvando
                        ? null
                        : () => _salvar(feedbackEntregue: true),
                    icon: const Icon(Icons.check),
                    label: const Text('Marcar feedback como entregue'),
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: corDentroDoSla),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Feedback entregue em '
                          '${formatarData(entregueEm).substring(0, 5)} '
                          '${formatarHora(entregueEm)}',
                        ),
                      ),
                      TextButton(
                        onPressed: _salvando
                            ? null
                            : () => _salvar(feedbackEntregue: false),
                        child: const Text('Desmarcar'),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _observacao,
                  onChanged: _aoDigitar,
                  minLines: 3,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: 'Observação do gerente',
                    alignLabelWithHint: true,
                    helperText: _estadoObservacao.isEmpty
                        ? 'Salva sozinha ao parar de digitar'
                        : _estadoObservacao,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Rodapé técnico (F04, item 10).
        Text(
          [
            formatarDataHora(a.resumo.criadoEm),
            if (a.modelo.isNotEmpty) 'modelo ${a.modelo}',
            if (a.promptVersao.isNotEmpty) 'prompt ${a.promptVersao}',
            if (a.resumo.solicitadaPorNome case final nome?) 'pedida por $nome',
          ].join(' · '),
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
