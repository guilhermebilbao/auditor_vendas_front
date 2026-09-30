import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/erros.dart';
import '../../core/sessao/sessao.dart';
import '../../widgets/estados.dart';
import 'login_tela.dart';

/// Regra do backend: mínimo de 10 caracteres.
const tamanhoMinimoSenha = 10;

String? validarSenhaNova(String? senha) =>
    (senha ?? '').length < tamanhoMinimoSenha
    ? 'Mínimo de $tamanhoMinimoSenha caracteres'
    : null;

/// Força da senha, de 0 a 4. É só informativa.
int forcaDaSenha(String senha) {
  if (senha.length < tamanhoMinimoSenha) return 0;
  var pontos = 1;
  if (senha.length >= 14) pontos++;
  if (senha.contains(RegExp('[a-z]')) && senha.contains(RegExp('[A-Z]'))) {
    pontos++;
  }
  if (senha.contains(RegExp(r'\d')) &&
      senha.contains(RegExp(r'[^A-Za-z0-9]'))) {
    pontos++;
  }
  return pontos;
}

class IndicadorForca extends StatelessWidget {
  const IndicadorForca(this.senha, {super.key});

  final String senha;

  @override
  Widget build(BuildContext context) {
    if (senha.isEmpty) return const SizedBox.shrink();
    final forca = forcaDaSenha(senha);
    final (rotulo, cor) = switch (forca) {
      0 => ('curta demais', Colors.red),
      1 => ('fraca', Colors.orange),
      2 => ('razoável', Colors.amber),
      3 => ('boa', Colors.lightGreen),
      _ => ('forte', Colors.green),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: (forca + 1) / 5,
              color: cor,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Text('Senha $rotulo', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// A mesma tela serve para o convite e para a recuperação (F02, item 6).
class DefinirSenhaTela extends ConsumerStatefulWidget {
  const DefinirSenhaTela({super.key, required this.token});

  final String token;

  @override
  ConsumerState<DefinirSenhaTela> createState() => _DefinirSenhaTelaState();
}

class _DefinirSenhaTelaState extends ConsumerState<DefinirSenhaTela> {
  final _formulario = GlobalKey<FormState>();
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _enviando = false;
  bool _linkInvalido = false;
  String? _erroSenha;
  String? _erro;

  @override
  void dispose() {
    _senha.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    _erroSenha = null;
    if (_enviando || !_formulario.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await ref
          .read(sessaoProvider.notifier)
          .definirSenha(widget.token, _senha.text);
      if (!mounted) return;
      snack(context, 'Senha definida! Entre com a senha nova.');
      // Se outro usuário estava logado neste aparelho, sai: quem abriu o link
      // vai entrar com a senha que acabou de definir.
      final roteador = GoRouter.of(context);
      if (ref.read(sessaoProvider).logado) {
        await ref.read(sessaoProvider.notifier).sair();
      }
      roteador.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.codigo == 'TOKEN_SENHA_INVALIDO') {
          _linkInvalido = true;
        } else if (e.codigo == 'SENHA_FRACA') {
          _erroSenha = mensagemDoErro(e);
          _formulario.currentState!.validate();
        } else {
          _erro = mensagemDoErro(e);
        }
      });
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final irParaLogin = TextButton(
      onPressed: () => context.go('/login'),
      child: const Text('Ir para o login'),
    );

    if (widget.token.isEmpty) {
      return MolduraPublica(
        titulo: 'Link inválido',
        filhos: [
          const Text(
            'Este link não tem o código de acesso. Abra de novo o '
            'link recebido por e-mail.',
          ),
          const SizedBox(height: 16),
          irParaLogin,
        ],
      );
    }
    if (_linkInvalido) {
      return MolduraPublica(
        titulo: 'Link expirado',
        filhos: [
          const Text('Este link expirou ou já foi usado.'),
          const SizedBox(height: 8),
          const Text(
            'Se era um convite, peça ao administrador da loja para reenviar. '
            'Se você já tem acesso, peça um novo link de senha.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/esqueci-senha'),
            child: const Text('Pedir novo link'),
          ),
          irParaLogin,
        ],
      );
    }

    return MolduraPublica(
      titulo: 'Definir senha',
      filhos: [
        Form(
          key: _formulario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _senha,
                obscureText: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() => _erroSenha = null),
                decoration: const InputDecoration(labelText: 'Nova senha'),
                validator: (v) => validarSenhaNova(v) ?? _erroSenha,
              ),
              IndicadorForca(_senha.text),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmacao,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _enviar(),
                decoration: const InputDecoration(
                  labelText: 'Confirmar a senha',
                ),
                validator: (v) =>
                    v != _senha.text ? 'As senhas não conferem' : null,
              ),
            ],
          ),
        ),
        if (_erro != null) ...[
          const SizedBox(height: 12),
          Text(
            _erro!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _enviando ? null : _enviar,
          child: Text(_enviando ? 'Salvando…' : 'Definir senha'),
        ),
        const SizedBox(height: 8),
        irParaLogin,
      ],
    );
  }
}
