import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Volta para a tela anterior; aberta direto por um link, vai para [destino].
class BotaoVoltar extends StatelessWidget {
  const BotaoVoltar({super.key, this.destino = '/'});

  final String destino;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Voltar',
      onPressed: () => context.canPop() ? context.pop() : context.go(destino),
    );
  }
}

/// Se a rota no topo da navegação é [caminho]. Os ciclos de atualização usam
/// isto para pausar quando a tela está coberta por outra.
bool rotaNoTopo(BuildContext context, String caminho) =>
    GoRouter.of(context).state.uri.path == caminho;
