import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/config.dart';
import '../../core/documento.dart';
import '../../core/erros.dart';
import '../../core/sessao/sessao.dart';
import '../../widgets/estados.dart';
import 'definir_senha_tela.dart';
import 'login_tela.dart';

/// Autocadastro de uma loja nova (spec 19, item 34). Nada é criado agora: a
/// pessoa recebe um link por e-mail para criar a senha.
class CadastroTela extends ConsumerStatefulWidget {
  const CadastroTela({super.key});

  @override
  ConsumerState<CadastroTela> createState() => _CadastroTelaState();
}

class _CadastroTelaState extends ConsumerState<CadastroTela> {
  final _formulario = GlobalKey<FormState>();
  final _nomeLoja = TextEditingController();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _documento = TextEditingController();
  bool _aceite = false;
  bool _mostrarErroAceite = false;
  bool _enviando = false;
  bool _enviado = false;
  String? _erro;
  late final _toqueTermos = TapGestureRecognizer()
    ..onTap = () => _abrir(urlTermos);
  late final _toquePrivacidade = TapGestureRecognizer()
    ..onTap = () => _abrir(urlPrivacidade);

  Future<void> _abrir(String url) async {
    final abriu = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!abriu && mounted) snack(context, 'Não foi possível abrir $url');
  }

  @override
  void dispose() {
    _toqueTermos.dispose();
    _toquePrivacidade.dispose();
    _nomeLoja.dispose();
    _nome.dispose();
    _email.dispose();
    _documento.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final valido = _formulario.currentState!.validate();
    setState(() => _mostrarErroAceite = !_aceite);
    if (_enviando || !valido || !_aceite) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await ref
          .read(sessaoProvider.notifier)
          .cadastrar(
            nomeLoja: _nomeLoja.text,
            nome: _nome.text,
            email: _email.text,
            cpfCnpj: soDigitos(_documento.text),
            versaoTermos: versaoTermos,
          );
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
      // A mesma mensagem, exista ou não o e-mail (spec 19, item 2).
      return MolduraPublica(
        titulo: 'Confira seu e-mail',
        filhos: [
          const Text(
            'Se o e-mail for válido, você vai receber um link para continuar '
            '(válido por 48 horas).',
          ),
          const SizedBox(height: 16),
          voltar,
        ],
      );
    }

    final tema = Theme.of(context);
    String? obrigatorio(String? v, String rotulo) =>
        (v ?? '').trim().isEmpty ? 'Informe $rotulo' : null;

    return MolduraPublica(
      titulo: 'Criar conta',
      filhos: [
        const Text(
          'Cadastre a sua loja. Depois de confirmar o e-mail, você recebe o '
          'link para pagar a assinatura.',
        ),
        const SizedBox(height: 16),
        Form(
          key: _formulario,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nomeLoja,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.organizationName],
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'Nome da loja',
                    counterText: '',
                  ),
                  validator: (v) => obrigatorio(v, 'o nome da loja'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nome,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'Seu nome',
                    counterText: '',
                  ),
                  validator: (v) => obrigatorio(v, 'o seu nome'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  validator: (v) =>
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch((v ?? '').trim())
                      ? null
                      : 'Informe um e-mail válido',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _documento,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: const [MascaraDocumento()],
                  decoration: const InputDecoration(
                    labelText: 'CPF ou CNPJ',
                    helperText: 'De quem paga a assinatura.',
                  ),
                  validator: (v) =>
                      documentoValido(v ?? '') ? null : 'CPF ou CNPJ inválido',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _aceite,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (v) => setState(() {
            _aceite = v ?? false;
            if (_aceite) _mostrarErroAceite = false;
          }),
          title: Text.rich(
            TextSpan(
              text: 'Li e aceito os ',
              children: [
                _link('termos de uso', _toqueTermos, tema),
                const TextSpan(text: ' e a '),
                _link('política de privacidade', _toquePrivacidade, tema),
              ],
            ),
          ),
          subtitle: _mostrarErroAceite
              ? Text(
                  'É preciso aceitar para continuar',
                  style: TextStyle(color: tema.colorScheme.error),
                )
              : null,
        ),
        if (_erro != null) ...[
          const SizedBox(height: 4),
          Text(_erro!, style: TextStyle(color: tema.colorScheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _enviando ? null : _enviar,
          child: Text(_enviando ? 'Enviando…' : 'Criar conta'),
        ),
        const SizedBox(height: 8),
        voltar,
      ],
    );
  }

  TextSpan _link(String rotulo, GestureRecognizer toque, ThemeData tema) =>
      TextSpan(
        text: rotulo,
        style: TextStyle(
          color: tema.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        recognizer: toque,
      );
}

/// Aberta pelo link do e-mail: `auditorvendas://app/confirmar-cadastro?token=`
/// (spec 19, item 35). Define a senha e já entra.
class ConfirmarCadastroTela extends ConsumerStatefulWidget {
  const ConfirmarCadastroTela({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ConfirmarCadastroTela> createState() =>
      _ConfirmarCadastroTelaState();
}

class _ConfirmarCadastroTelaState extends ConsumerState<ConfirmarCadastroTela> {
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
      // Se outra pessoa estava logada neste aparelho, a sessão nova substitui
      // a dela: quem abriu o link é o dono da loja criada.
      await ref
          .read(sessaoProvider.notifier)
          .confirmarCadastro(widget.token, _senha.text);
      // Logado, com a loja aguardando pagamento: o roteador leva à tela certa.
      if (mounted) context.go('/');
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

    if (widget.token.isEmpty || _linkInvalido) {
      return MolduraPublica(
        titulo: 'Link expirado',
        filhos: [
          Text(
            widget.token.isEmpty
                ? 'Este link não tem o código de confirmação. Abra de novo o '
                      'link recebido por e-mail.'
                : 'Este link expirou ou já foi usado. Faça o cadastro de novo '
                      'ou, se a loja já foi criada, entre com a sua senha.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/cadastro'),
            child: const Text('Fazer o cadastro de novo'),
          ),
          irParaLogin,
        ],
      );
    }

    return MolduraPublica(
      titulo: 'Criar a sua senha',
      filhos: [
        const Text('Último passo: crie a senha para entrar no app.'),
        const SizedBox(height: 16),
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
                decoration: const InputDecoration(labelText: 'Senha'),
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
          child: Text(_enviando ? 'Criando a loja…' : 'Criar conta'),
        ),
        const SizedBox(height: 8),
        irParaLogin,
      ],
    );
  }
}
