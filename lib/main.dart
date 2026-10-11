import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/tema.dart';
import 'core/sessao/sessao.dart';
import 'widgets/logo.dart';
import 'features/assinatura/loja_inativa_tela.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    // Sem repetição automática: uma consulta que falha não pode ser refeita
    // sozinha (algumas chamam a IA). As telas oferecem "Tentar de novo".
    ProviderScope(retry: (_, _) => null, child: const App()),
  );
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(sessaoProvider.select((s) => s.status));
    return MaterialApp.router(
      title: 'EmplaKey',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(roteadorProvider),
      scaffoldMessengerKey: chaveMensagens,
      theme: tema(Brightness.light),
      darkTheme: tema(Brightness.dark),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Nenhuma tela é montada antes de saber se há sessão (F01, item 4).
      builder: (context, child) => switch (status) {
        StatusSessao.iniciando => const _Abertura(),
        StatusSessao.semConexao => _Abertura(
          aoTentarDeNovo: () => ref.read(sessaoProvider.notifier).restaurar(),
        ),
        _ => FaixaDaLoja(
          aoTocarSuspensa: () =>
              ref.read(roteadorProvider).push('/loja-inativa'),
          aoAbrirAssinatura: () =>
              ref.read(roteadorProvider).push('/admin/loja'),
          child: child!,
        ),
      },
    );
  }
}

class _Abertura extends StatelessWidget {
  const _Abertura({this.aoTentarDeNovo});

  final VoidCallback? aoTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LogoApp(largura: 240),
            const SizedBox(height: 24),
            if (aoTentarDeNovo == null)
              const CircularProgressIndicator()
            else ...[
              const Text('Sem conexão com o servidor.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: aoTentarDeNovo,
                child: const Text('Tentar de novo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
