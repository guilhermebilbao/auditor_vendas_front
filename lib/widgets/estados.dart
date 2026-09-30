import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/erros.dart';

/// Esqueleto de lista para o carregamento (F07, item 1).
class Carregando extends StatelessWidget {
  const Carregando({super.key, this.linhas = 6});

  final int linhas;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget barra(double largura, double altura) => Container(
      width: largura,
      height: altura,
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Semantics(
      label: 'Carregando',
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        itemCount: linhas,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              barra(160, 14),
              const SizedBox(height: 8),
              barra(double.infinity, 12),
            ],
          ),
        ),
      ),
    );
  }
}

class Vazio extends StatelessWidget {
  const Vazio(this.mensagem, {super.key, this.icone, this.acao, this.aoAgir});

  final String mensagem;
  final IconData? icone;
  final String? acao;
  final VoidCallback? aoAgir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icone ?? Icons.inbox_outlined,
              size: 48,
              color: tema.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyLarge,
            ),
            if (acao != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: aoAgir, child: Text(acao!)),
            ],
          ],
        ),
      ),
    );
  }
}

class ErroTela extends StatelessWidget {
  const ErroTela(this.erro, {super.key, this.aoTentarDeNovo});

  final Object erro;
  final VoidCallback? aoTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    final repetir = aoTentarDeNovo != null && podeTentarDeNovo(erro);
    return Vazio(
      mensagemDoErro(erro),
      icone: Icons.error_outline,
      acao: repetir ? 'Tentar de novo' : null,
      aoAgir: aoTentarDeNovo,
    );
  }
}

/// Aviso discreto de que a atualização automática falhou (F07, item 2).
class AvisoConexao extends StatelessWidget {
  const AvisoConexao({super.key, required this.visivel});

  final bool visivel;

  @override
  Widget build(BuildContext context) {
    if (!visivel) return const SizedBox.shrink();
    final cores = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: cores.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        'Sem conexão; tentando de novo…',
        style: TextStyle(color: cores.onErrorContainer, fontSize: 13),
      ),
    );
  }
}

void snackErro(BuildContext context, Object erro) =>
    snack(context, mensagemDoErro(erro));

void snack(BuildContext context, String mensagem) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensagem)));
}

/// Mostra um valor assíncrono sem apagar o que já está na tela quando uma
/// atualização falha (F07, item 2).
class ValorAssincrono<T> extends StatelessWidget {
  const ValorAssincrono({
    super.key,
    required this.valor,
    required this.construir,
    this.aoTentarDeNovo,
    this.linhas = 4,
  });

  final AsyncValue<T> valor;
  final Widget Function(T dados) construir;
  final VoidCallback? aoTentarDeNovo;
  final int linhas;

  @override
  Widget build(BuildContext context) {
    final v = valor;
    if (v.hasValue) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AvisoConexao(visivel: v.hasError),
          construir(v.requireValue),
        ],
      );
    }
    if (v.hasError) {
      return ErroTela(v.error!, aoTentarDeNovo: aoTentarDeNovo);
    }
    return Carregando(linhas: linhas);
  }
}

/// Executa uma ação de botão e mostra o erro num snack, se houver.
Future<bool> executarAcao(
  BuildContext context,
  Future<void> Function() acao, {
  String? sucesso,
}) async {
  try {
    await acao();
    if (sucesso != null && context.mounted) snack(context, sucesso);
    return true;
  } catch (e) {
    if (context.mounted) snackErro(context, e);
    return false;
  }
}

Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String acao = 'Confirmar',
  bool perigoso = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: perigoso
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(acao),
        ),
      ],
    ),
  );
  return ok ?? false;
}
