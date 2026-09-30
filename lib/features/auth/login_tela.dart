import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/erros.dart';
import '../../core/sessao/sessao.dart';

/// Moldura das telas públicas: formulário centralizado e estreito.
class MolduraPublica extends StatelessWidget {
  const MolduraPublica({super.key, required this.titulo, required this.filhos});

  final String titulo;
  final List<Widget> filhos;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.fact_check,
                    size: 48,
                    color: tema.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Auditor de Vendas',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  Text(titulo, style: tema.textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  ...filhos,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginTela extends ConsumerStatefulWidget {
  const LoginTela({super.key});

  @override
  ConsumerState<LoginTela> createState() => _LoginTelaState();
}

class _LoginTelaState extends ConsumerState<LoginTela> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _ocultar = true;
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_enviando || !_formulario.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      // Com a sessão criada, a guarda de rotas leva para `?voltar=` ou `/`.
      await ref.read(sessaoProvider.notifier).entrar(_email.text, _senha.text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = mensagemDoErro(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _abrirLink() async {
    final link = await showDialog<String>(
      context: context,
      builder: (context) => const _DialogoLink(),
    );
    if (link == null || !mounted) return;
    // Aceita o link inteiro do e-mail ou só o token.
    final token = Uri.tryParse(link)?.queryParameters['token'] ?? link;
    context.push(
      Uri(path: '/definir-senha', queryParameters: {'token': token}).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return MolduraPublica(
      titulo: 'Entrar',
      filhos: [
        Form(
          key: _formulario,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Informe o e-mail'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _senha,
                  obscureText: _ocultar,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _entrar(),
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    suffixIcon: IconButton(
                      tooltip: _ocultar ? 'Mostrar a senha' : 'Ocultar a senha',
                      icon: Icon(
                        _ocultar ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _ocultar = !_ocultar),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Informe a senha' : null,
                ),
              ],
            ),
          ),
        ),
        if (_erro != null) ...[
          const SizedBox(height: 12),
          Text(_erro!, style: TextStyle(color: cores.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _enviando ? null : _entrar,
          child: Text(_enviando ? 'Entrando…' : 'Entrar'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.push('/esqueci-senha'),
          child: const Text('Esqueci a senha'),
        ),
        TextButton(
          onPressed: _abrirLink,
          child: const Text('Recebi um link de convite ou de senha'),
        ),
      ],
    );
  }
}

class _DialogoLink extends StatefulWidget {
  const _DialogoLink();

  @override
  State<_DialogoLink> createState() => _DialogoLinkState();
}

class _DialogoLinkState extends State<_DialogoLink> {
  final _link = TextEditingController();

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Link do e-mail'),
      content: TextField(
        controller: _link,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'Cole aqui o link que você recebeu por e-mail',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final link = _link.text.trim();
            Navigator.pop(context, link.isEmpty ? null : link);
          },
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
