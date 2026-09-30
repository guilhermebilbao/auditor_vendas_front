import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/erros.dart';
import '../../core/sessao/sessao.dart';
import 'login_tela.dart';

class EsqueciSenhaTela extends ConsumerStatefulWidget {
  const EsqueciSenhaTela({super.key});

  @override
  ConsumerState<EsqueciSenhaTela> createState() => _EsqueciSenhaTelaState();
}

class _EsqueciSenhaTelaState extends ConsumerState<EsqueciSenhaTela> {
  final _email = TextEditingController();
  bool _enviando = false;
  bool _enviado = false;
  String? _erro;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    if (!_email.text.contains('@')) {
      return setState(() => _erro = 'Informe o e-mail');
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await ref.read(sessaoProvider.notifier).esqueciSenha(_email.text);
      if (mounted) setState(() => _enviado = true);
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDoErro(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final voltar = TextButton(
      onPressed: () => context.go('/login'),
      child: const Text('Voltar para o login'),
    );
    if (_enviado) {
      // A mesma mensagem, exista ou não o e-mail (F02, item 5).
      return MolduraPublica(
        titulo: 'Confira seu e-mail',
        filhos: [
          const Text(
            'Se o e-mail estiver cadastrado, você vai receber um link em '
            'instantes (válido por 1 hora).',
          ),
          const SizedBox(height: 16),
          voltar,
        ],
      );
    }
    return MolduraPublica(
      titulo: 'Esqueci a senha',
      filhos: [
        const Text('Informe seu e-mail para receber o link de nova senha.'),
        const SizedBox(height: 16),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _enviar(),
          decoration: InputDecoration(labelText: 'E-mail', errorText: _erro),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _enviando ? null : _enviar,
          child: Text(_enviando ? 'Enviando…' : 'Enviar link'),
        ),
        const SizedBox(height: 8),
        voltar,
      ],
    );
  }
}
