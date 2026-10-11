import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/casca.dart';
import '../../core/sessao/modelos.dart';
import '../../core/sessao/sessao.dart';
import '../../widgets/estados.dart';
import '../auth/login_tela.dart';
import 'assinatura_repo.dart';

/// O que dizer em cada estado (tabelas de estados das specs 19 e 20).
(String titulo, String texto) textoDoEstado(
  String estado, {
  String? motivoSuspensao,
}) => switch (estado) {
  EstadoLoja.aguardandoPagamento => (
    'Pagamento pendente',
    'Enviamos o link de pagamento para o seu e-mail. Assim que o pagamento '
        'for confirmado, a loja é liberada automaticamente.',
  ),
  EstadoLoja.emRevisao => (
    'Loja em análise',
    'Pagamento recebido. Sua loja está em análise e será liberada em breve.',
  ),
  EstadoLoja.suspensa => (
    'Assinatura suspensa',
    '${_motivo(motivoSuspensao)} Enquanto isso, os dados ficam disponíveis só '
        'para consulta.',
  ),
  EstadoLoja.trialEncerrado => (
    'Seu teste grátis terminou',
    'Seu período de teste grátis terminou. Para voltar a usar o Auditor de '
        'Vendas, conclua a assinatura.',
  ),
  _ => ('Loja inativa', 'Fale com o suporte.'),
};

String _motivo(String? motivoSuspensao) => switch (motivoSuspensao) {
  'inadimplencia' =>
    'O pagamento está em atraso. Pague pelo link enviado por e-mail para '
        'liberar a loja.',
  'estorno' => 'O pagamento foi estornado. Fale com o suporte.',
  'cancelada_pelo_cliente' =>
    'A assinatura foi cancelada. Fale com o suporte para reativar.',
  _ => 'Fale com o suporte para reativar a loja.',
};

/// Para onde o roteador leva a loja que não está ativa (spec 19, item 36).
class LojaInativaTela extends ConsumerStatefulWidget {
  const LojaInativaTela({super.key});

  @override
  ConsumerState<LojaInativaTela> createState() => _LojaInativaTelaState();
}

class _LojaInativaTelaState extends ConsumerState<LojaInativaTela> {
  bool _atualizando = false;

  /// "Já paguei": relê o `/me`. Se a loja foi liberada, o roteador sai daqui.
  Future<void> _atualizar() async {
    setState(() => _atualizando = true);
    final ok = await executarAcao(
      context,
      () => ref.read(sessaoProvider.notifier).recarregar(),
    );
    ref.invalidate(assinaturaProvider);
    if (!mounted) return;
    setState(() => _atualizando = false);
    if (ok && ref.read(sessaoProvider).loja?.bloqueada == true) {
      snack(context, 'O pagamento ainda não foi confirmado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider);
    final loja = sessao.loja;
    if (loja == null) return const Scaffold(body: Carregando());
    final motivo = loja.suspensa
        ? ref.watch(assinaturaProvider).value?.motivoSuspensao
        : null;
    final (titulo, texto) = textoDoEstado(loja.estado, motivoSuspensao: motivo);
    final trialEncerrado = loja.estado == EstadoLoja.trialEncerrado;
    final pagamentoPendente =
        loja.estado == EstadoLoja.aguardandoPagamento ||
        trialEncerrado ||
        loja.inadimplenteDesde != null;

    return MolduraPublica(
      titulo: titulo,
      filhos: [
        Text(loja.nome, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(texto),
        if (pagamentoPendente && !sessao.admin) ...[
          const SizedBox(height: 8),
          Text(
            trialEncerrado
                ? 'Peça ao administrador da loja para concluir a assinatura.'
                : 'O link de pagamento vai para o e-mail do administrador da '
                      'loja.',
          ),
        ],
        const SizedBox(height: 24),
        if (pagamentoPendente && sessao.admin) ...[
          BotaoLinkPagamento(
            rotulo: trialEncerrado
                ? 'Quero assinar'
                : 'Reenviar link de pagamento',
          ),
          const SizedBox(height: 8),
        ],
        if (loja.suspensa)
          FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Consultar os dados'),
          )
        else
          FilledButton(
            onPressed: _atualizando ? null : _atualizar,
            child: Text(_atualizando ? 'Verificando…' : 'Já paguei: atualizar'),
          ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => sair(context, ref),
          child: const Text('Sair'),
        ),
      ],
    );
  }
}

/// Pede o link de pagamento por e-mail (`POST /assinatura/reenviar-link`).
/// O app nunca abre a página de pagamento (spec 19, item 22; spec 20, item 9).
class BotaoLinkPagamento extends ConsumerStatefulWidget {
  const BotaoLinkPagamento({super.key, required this.rotulo});

  final String rotulo;

  @override
  ConsumerState<BotaoLinkPagamento> createState() => _BotaoLinkPagamentoState();
}

class _BotaoLinkPagamentoState extends ConsumerState<BotaoLinkPagamento> {
  bool _enviando = false;

  Future<void> _enviar() async {
    final email = ref.read(sessaoProvider).usuario?.email;
    setState(() => _enviando = true);
    await executarAcao(
      context,
      () => ref.read(assinaturaRepoProvider).reenviarLink(),
      sucesso: email == null
          ? 'Link enviado. Confira o seu e-mail (e a caixa de spam).'
          : 'Enviamos o link de pagamento para $email. Lá você pode pagar com '
                'Pix, cartão ou boleto.',
    );
    if (mounted) setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
    onPressed: _enviando ? null : _enviar,
    child: Text(_enviando ? 'Enviando…' : widget.rotulo),
  );
}

/// Faixa fixa no topo de todas as telas enquanto a loja está suspensa (spec 19,
/// item 36) ou no teste grátis (spec 20, item 30). Na suspensão, tocar abre a
/// tela com o motivo e o reenvio do link; no trial, o admin vai para a seção
/// "Assinatura" e, para os outros papéis, a faixa só informa.
///
/// Fica acima do Navigator (no `builder` do MaterialApp), então não alcança o
/// GoRouter pelo context: quem monta passa os callbacks.
class FaixaDaLoja extends ConsumerWidget {
  const FaixaDaLoja({
    super.key,
    required this.aoTocarSuspensa,
    required this.aoAbrirAssinatura,
    required this.child,
  });

  final VoidCallback aoTocarSuspensa;
  final VoidCallback aoAbrirAssinatura;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (loja, admin) = ref.watch(
      sessaoProvider.select((s) => (s.logado ? s.loja : null, s.admin)),
    );
    final cores = Theme.of(context).colorScheme;
    final trialAte = loja?.trialAte;
    final (
      String texto,
      IconData icone,
      Color fundo,
      Color frente,
      VoidCallback? aoTocar,
    ) = switch (loja) {
      final l? when l.suspensa => (
        'Assinatura suspensa: dados só para consulta.',
        Icons.lock_clock,
        cores.errorContainer,
        cores.onErrorContainer,
        aoTocarSuspensa,
      ),
      final l? when l.emTrial && trialAte != null => (
        textoDiasDeTrial(trialAte),
        Icons.hourglass_bottom,
        cores.primaryContainer,
        cores.onPrimaryContainer,
        admin ? aoAbrirAssinatura : null,
      ),
      _ => ('', Icons.info, cores.surface, cores.onSurface, null),
    };
    if (texto.isEmpty) return child;
    return Column(
      children: [
        Material(
          color: fundo,
          child: SafeArea(
            bottom: false,
            child: InkWell(
              onTap: aoTocar,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(icone, size: 18, color: frente),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        texto,
                        style: TextStyle(color: frente, fontSize: 13),
                      ),
                    ),
                    if (aoTocar != null)
                      Icon(Icons.chevron_right, size: 18, color: frente),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          // A faixa já ocupa a área do relógio do sistema.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
