import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/sessao/sessao.dart';
import '../widgets/barra_pilula.dart';
import '../widgets/estados.dart';
import 'tema.dart';

const _destinos = <DestinoBarra>[
  (
    rotulo: 'Painel',
    icone: Icons.dashboard_outlined,
    iconeAtivo: Icons.dashboard,
  ),
  (rotulo: 'Leads', icone: Icons.forum_outlined, iconeAtivo: Icons.forum),
  (
    rotulo: 'Atuação',
    icone: Icons.leaderboard_outlined,
    iconeAtivo: Icons.leaderboard,
  ),
  (rotulo: 'Mais', icone: Icons.menu, iconeAtivo: Icons.menu),
];

/// Navegação principal: barra em pílula no celular e menu lateral no desktop
/// (F07, item 6).
///
/// Cada aba é uma branch do `StatefulShellRoute`, com o próprio Navigator
/// (e a própria `GlobalKey<NavigatorState>`, ver o router). As [abas] ficam
/// todas montadas num Stack e só a ativa aparece, então trocar de aba não
/// perde rolagem, campos digitados nem filtros da URL.
class Casca extends StatelessWidget {
  const Casca({super.key, required this.navegacao, required this.abas});

  final StatefulNavigationShell navegacao;
  final List<Widget> abas;

  void _irPara(int i) {
    // Tocar de novo na aba ativa volta para a raiz dela; nas outras, volta
    // para onde o usuário estava naquela aba.
    navegacao.goBranch(i, initialLocation: i == navegacao.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final indice = navegacao.currentIndex;
    final conteudo = Stack(
      children: [
        for (final (i, aba) in abas.indexed)
          Offstage(
            offstage: i != indice,
            // Offstage esconde mas não pausa animações; sem o TickerMode, os
            // indicadores de carregamento das abas escondidas continuariam
            // pedindo quadros.
            child: TickerMode(enabled: i == indice, child: aba),
          ),
      ],
    );

    return PopScope(
      // A aba ativa já tentou voltar dentro dela antes de chegar aqui (o
      // go_router consulta primeiro o Navigator da branch). Então este é o
      // voltar "na raiz da aba": vai para o Painel e, no Painel, confirma a
      // saída. Só no Android: no iOS não há voltar do sistema e o
      // SystemNavigator.pop é ignorado.
      canPop: indice == 0 && !_ehAndroid,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (indice != 0) return _irPara(0);
        final sair = await confirmar(
          context,
          titulo: 'Sair do aplicativo',
          mensagem: 'Deseja mesmo sair do Auditor de Vendas?',
          acao: 'Sair',
        );
        if (sair) await SystemNavigator.pop();
      },
      child: ehDesktop(context)
          ? Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    extended: true,
                    selectedIndex: indice,
                    onDestinationSelected: _irPara,
                    destinations: [
                      for (final d in _destinos)
                        NavigationRailDestination(
                          icon: Icon(d.icone),
                          selectedIcon: Icon(d.iconeAtivo),
                          label: Text(d.rotulo),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: conteudo),
                ],
              ),
            )
          : Scaffold(
              // O conteúdo passa por trás da pílula; é isso que dá sentido ao
              // vidro. As listas das abas compensam com
              // BarraPilula.folgaInferior.
              extendBody: true,
              body: EscopoBarraPilula(child: conteudo),
              bottomNavigationBar: BarraPilula(
                destinos: _destinos,
                indiceAtual: indice,
                aoSelecionar: _irPara,
              ),
            ),
    );
  }
}

bool get _ehAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Aba "Mais": conta, administração (só para admin) e sair.
class MaisTela extends ConsumerWidget {
  const MaisTela({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider);
    final tema = Theme.of(context);

    Widget item(IconData icone, String titulo, String rota, [String? detalhe]) {
      return ListTile(
        leading: Icon(icone),
        title: Text(titulo),
        subtitle: detalhe == null ? null : Text(detalhe),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(rota),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListView(
        padding: EdgeInsets.only(bottom: BarraPilula.folgaInferior(context)),
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text(
                (sessao.usuario?.nome ?? '?').characters.first.toUpperCase(),
              ),
            ),
            title: Text(sessao.usuario?.nome ?? ''),
            subtitle: Text(
              '${sessao.loja?.nome ?? ''} · '
              '${sessao.admin ? 'Administrador' : 'Gerente'}',
            ),
          ),
          const Divider(),
          item(Icons.person_outline, 'Minha conta', '/conta', 'Trocar a senha'),
          if (sessao.admin) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Administração', style: tema.textTheme.labelLarge),
            ),
            item(
              Icons.badge_outlined,
              'Vendedores e WhatsApp',
              '/admin/vendedores',
            ),
            item(Icons.group_outlined, 'Usuários do painel', '/admin/usuarios'),
            item(
              Icons.storefront_outlined,
              'Configuração da loja',
              '/admin/loja',
              'SLA, horário comercial, pesos e retenção',
            ),
          ],
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: tema.colorScheme.error),
            title: const Text('Sair'),
            onTap: () => sair(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Logout (F01, item 8): encerra a sessão e volta ao login.
Future<void> sair(BuildContext context, WidgetRef ref) async {
  final roteador = GoRouter.of(context);
  await ref.read(sessaoProvider.notifier).sair();
  roteador.go('/login');
}
