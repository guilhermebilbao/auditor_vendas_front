import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/sessao/sessao.dart';
import 'tema.dart';

const _destinos = [
  (rota: '/', rotulo: 'Painel', icone: Icons.dashboard_outlined),
  (rota: '/leads', rotulo: 'Leads', icone: Icons.forum_outlined),
  (
    rota: '/desempenho',
    rotulo: 'Desempenho',
    icone: Icons.leaderboard_outlined,
  ),
  (rota: '/mais', rotulo: 'Mais', icone: Icons.menu),
];

/// Navegação principal: barra inferior no celular e menu lateral no desktop
/// (F07, item 6).
class Casca extends StatelessWidget {
  const Casca({super.key, required this.caminho, required this.child});

  final String caminho;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final indice = switch (caminho) {
      '/' => 0,
      final c when c.startsWith('/leads') => 1,
      final c when c.startsWith('/desempenho') => 2,
      _ => 3,
    };
    void irPara(int i) => context.go(_destinos[i].rota);

    if (ehDesktop(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: true,
              selectedIndex: indice,
              onDestinationSelected: irPara,
              destinations: [
                for (final d in _destinos)
                  NavigationRailDestination(
                    icon: Icon(d.icone),
                    label: Text(d.rotulo),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: indice,
        onDestinationSelected: irPara,
        destinations: [
          for (final d in _destinos)
            NavigationDestination(icon: Icon(d.icone), label: d.rotulo),
        ],
      ),
    );
  }
}

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
