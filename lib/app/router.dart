import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/sessao/sessao.dart';
import '../features/admin/loja_tela.dart';
import '../features/admin/usuarios_tela.dart';
import '../features/admin/vendedores_tela.dart';
import '../features/auditoria/auditoria_tela.dart';
import '../features/assinatura/loja_inativa_tela.dart';
import '../features/auth/cadastro_tela.dart';
import '../features/auth/conta_tela.dart';
import '../features/auth/definir_senha_tela.dart';
import '../features/auth/esqueci_senha_tela.dart';
import '../features/auth/login_tela.dart';
import '../features/atuacao/atuacao_tela.dart';
import '../features/atuacao/modelos.dart';
import '../features/atuacao/painel_tela.dart';
import '../features/atuacao/vendedor_tela.dart';
import '../features/leads/lead_tela.dart';
import '../features/leads/leads_tela.dart';
import '../features/leads/modelos.dart';
import '../widgets/navegacao.dart';
import 'casca.dart';

final chaveMensagens = GlobalKey<ScaffoldMessengerState>();

const _rotasPublicas = {
  '/login',
  '/esqueci-senha',
  '/definir-senha',
  '/cadastro',
  '/confirmar-cadastro',
};

final roteadorProvider = Provider<GoRouter>((ref) {
  // O roteador reavalia as guardas quando o login, o papel ou o estado da
  // loja mudam.
  final mudouSessao = ValueNotifier(0);
  ref.listen(
    sessaoProvider.select((s) => (s.status, s.usuario?.papel, s.loja?.estado)),
    (_, _) => mudouSessao.value++,
  );

  final roteador = GoRouter(
    refreshListenable: mudouSessao,
    redirect: (context, state) {
      final sessao = ref.read(sessaoProvider);
      if (!sessao.logado && sessao.status != StatusSessao.deslogado) {
        return null;
      }
      final caminho = state.uri.path;

      if (!sessao.logado) {
        if (_rotasPublicas.contains(caminho)) return null;
        final voltar = state.uri.toString();
        return Uri(
          path: '/login',
          queryParameters: voltar == '/' ? null : {'voltar': voltar},
        ).toString();
      }
      if (caminho == '/login') {
        return state.uri.queryParameters['voltar'] ?? '/';
      }
      // Links de e-mail abrem mesmo com alguém logado no aparelho.
      if (_rotasPublicas.contains(caminho)) return null;

      // Loja sem pagamento confirmado ou em análise só vê a tela de loja
      // inativa (spec 19, item 36). Suspensa navega, com a faixa de aviso.
      final loja = sessao.loja;
      if (loja != null && loja.bloqueada) {
        return caminho == '/loja-inativa' ? null : '/loja-inativa';
      }
      if (caminho == '/loja-inativa' && loja != null && !loja.suspensa) {
        return '/';
      }
      if (caminho.startsWith('/admin') && !sessao.admin) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          chaveMensagens.currentState?.showSnackBar(
            const SnackBar(content: Text('Acesso restrito ao administrador')),
          );
        });
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginTela()),
      GoRoute(
        path: '/esqueci-senha',
        builder: (context, state) => const EsqueciSenhaTela(),
      ),
      GoRoute(
        path: '/definir-senha',
        builder: (context, state) =>
            DefinirSenhaTela(token: state.uri.queryParameters['token'] ?? ''),
      ),
      GoRoute(
        path: '/cadastro',
        builder: (context, state) => const CadastroTela(),
      ),
      GoRoute(
        path: '/confirmar-cadastro',
        builder: (context, state) => ConfirmarCadastroTela(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: '/loja-inativa',
        builder: (context, state) => const LojaInativaTela(),
      ),
      // Uma branch por aba, cada uma com o próprio Navigator. As chaves são
      // fixas (criadas uma vez com o roteador) para o Flutter reaproveitar
      // os Navigators — e a pilha de cada aba — entre reconstruções.
      StatefulShellRoute(
        builder: (context, state, navegacao) => navegacao,
        navigatorContainerBuilder: (context, navegacao, abas) =>
            Casca(navegacao: navegacao, abas: abas),
        branches: [
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'painel'),
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: PainelTela(
                    periodo: Periodo.daUrl(state.uri.queryParameters),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'leads'),
            routes: [
              GoRoute(
                path: '/leads',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: LeadsTela(
                    filtros: FiltrosLeads.daUrl(state.uri.queryParameters),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'atuacao'),
            routes: [
              GoRoute(
                path: '/atuacao',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: AtuacaoTela(
                    periodo: Periodo.daUrl(state.uri.queryParameters),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'mais'),
            routes: [
              GoRoute(
                path: '/mais',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: MaisTela()),
              ),
            ],
          ),
        ],
      ),
      // Endereço antigo da aba Atuação: links salvos continuam funcionando.
      GoRoute(
        path: '/desempenho',
        redirect: (context, state) =>
            state.uri.replace(path: '/atuacao').toString(),
      ),
      // Detalhes ficam fora das abas: abrem em tela cheia, por cima da barra.
      GoRoute(
        path: '/leads/:id',
        builder: (context, state) => LeadTela(id: _id(state)),
      ),
      GoRoute(
        path: '/auditorias/:id',
        builder: (context, state) => AuditoriaTela(id: _id(state)),
      ),
      GoRoute(
        path: '/vendedores/:id',
        builder: (context, state) => VendedorTela(
          id: _id(state),
          periodo: Periodo.daUrl(state.uri.queryParameters),
        ),
      ),
      GoRoute(path: '/conta', builder: (context, state) => const ContaTela()),
      GoRoute(
        path: '/admin/vendedores',
        builder: (context, state) => const VendedoresTela(),
      ),
      GoRoute(
        path: '/admin/usuarios',
        builder: (context, state) => const UsuariosTela(),
      ),
      GoRoute(
        path: '/admin/loja',
        builder: (context, state) => const LojaTela(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(leading: const BotaoVoltar()),
      body: const Center(child: Text('Página não encontrada.')),
    ),
  );

  ref
    ..onDispose(roteador.dispose)
    ..onDispose(mudouSessao.dispose);
  return roteador;
});

int _id(GoRouterState state) => int.tryParse(state.pathParameters['id']!) ?? 0;
