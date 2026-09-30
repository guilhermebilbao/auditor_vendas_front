import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/casca.dart';
import '../../core/api/api_exception.dart';
import '../../core/erros.dart';
import '../../core/sessao/sessao.dart';
import '../../widgets/estados.dart';
import '../../widgets/navegacao.dart';
import 'definir_senha_tela.dart';

class ContaTela extends ConsumerStatefulWidget {
  const ContaTela({super.key});

  @override
  ConsumerState<ContaTela> createState() => _ContaTelaState();
}

class _ContaTelaState extends ConsumerState<ContaTela> {
  final _formulario = GlobalKey<FormState>();
  final _atual = TextEditingController();
  final _nova = TextEditingController();
  bool _enviando = false;
  String? _erroAtual;
  String? _erroNova;

  @override
  void initState() {
    super.initState();
    // `GET /me`: os dados mais recentes do usuário e da loja.
    ref.read(sessaoProvider.notifier).recarregar().catchError((_) {});
  }

  @override
  void dispose() {
    _atual.dispose();
    _nova.dispose();
    super.dispose();
  }

  Future<void> _trocar() async {
    _erroAtual = _erroNova = null;
    if (_enviando || !_formulario.currentState!.validate()) return;
    setState(() => _enviando = true);
    final sessao = ref.read(sessaoProvider.notifier);
    try {
      await sessao.trocarSenha(_atual.text, _nova.text);
      if (!mounted) return;
      // O backend encerrou todas as sessões: entra de novo com a senha nova.
      snack(context, 'Senha alterada. Entre de novo com a senha nova.');
      await sair(context, ref);
    } on ApiException catch (e) {
      if (!mounted) return;
      // Senha atual errada também é 401, mas não desloga (F02, item 11).
      if (e.codigo == 'CREDENCIAIS_INVALIDAS') {
        _erroAtual = 'Senha atual incorreta.';
      } else if (e.codigo == 'SENHA_FRACA') {
        _erroNova = mensagemDoErro(e);
      } else {
        snackErro(context, e);
      }
      _formulario.currentState!.validate();
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider);
    final usuario = sessao.usuario;
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const BotaoVoltar(destino: '/mais'),
        title: const Text('Minha conta'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Nome'),
                  subtitle: Text(usuario?.nome ?? ''),
                ),
                ListTile(
                  title: const Text('E-mail'),
                  subtitle: Text(usuario?.email ?? ''),
                ),
                ListTile(
                  title: const Text('Papel'),
                  subtitle: Text(sessao.admin ? 'Administrador' : 'Gerente'),
                ),
                ListTile(
                  title: const Text('Loja'),
                  subtitle: Text(sessao.loja?.nome ?? ''),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Trocar a senha', style: tema.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Ao trocar, todas as suas sessões são encerradas e você entra de '
            'novo com a senha nova.',
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Form(
            key: _formulario,
            child: Column(
              children: [
                TextFormField(
                  controller: _atual,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _erroAtual = null,
                  decoration: const InputDecoration(labelText: 'Senha atual'),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Informe a senha atual'
                      : _erroAtual,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nova,
                  obscureText: true,
                  onChanged: (_) => setState(() => _erroNova = null),
                  decoration: const InputDecoration(labelText: 'Senha nova'),
                  validator: (v) => validarSenhaNova(v) ?? _erroNova,
                ),
                IndicadorForca(_nova.text),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _enviando ? null : _trocar,
            child: Text(_enviando ? 'Salvando…' : 'Trocar a senha'),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () => sair(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}
