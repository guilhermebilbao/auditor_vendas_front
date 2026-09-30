import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/formatos.dart';
import '../../core/sessao/modelos.dart';
import '../../core/sessao/sessao.dart';
import '../../widgets/estados.dart';
import '../../widgets/navegacao.dart';
import '../../widgets/selos.dart';
import 'admin_repo.dart';

const _papeis = {'gerente': 'Gerente', 'admin': 'Administrador'};

/// Usuários do painel (F06, itens 13 a 16).
class UsuariosTela extends ConsumerStatefulWidget {
  const UsuariosTela({super.key});

  @override
  ConsumerState<UsuariosTela> createState() => _UsuariosTelaState();
}

class _UsuariosTelaState extends ConsumerState<UsuariosTela> {
  final _ocupados = <int>{};

  AdminRepo get _repo => ref.read(adminRepoProvider);

  Future<void> _acao(
    Usuario u,
    Future<void> Function() acao, {
    String? sucesso,
  }) async {
    if (_ocupados.contains(u.id)) return;
    setState(() => _ocupados.add(u.id));
    await executarAcao(context, acao, sucesso: sucesso);
    if (!mounted) return;
    setState(() => _ocupados.remove(u.id));
    ref.invalidate(usuariosProvider);
  }

  Future<void> _formulario([Usuario? u, bool proprio = false]) async {
    final salvou = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _DialogoUsuario(repo: _repo, usuario: u, proprio: proprio),
    );
    if (salvou == true) ref.invalidate(usuariosProvider);
  }

  Future<void> _reenviar(Usuario u) => _acao(u, () async {
    try {
      await _repo.reenviarConvite(u.id);
      if (mounted) snack(context, 'Convite reenviado para ${u.email}.');
    } on ApiException catch (e) {
      if (e.status != 409) rethrow;
      if (!mounted) return;
      snack(
        context,
        'O usuário já definiu a senha; ele pode usar "Esqueci a senha".',
      );
    }
  });

  Future<void> _desativar(Usuario u) async {
    final ok = await confirmar(
      context,
      titulo: 'Desativar ${u.nome}',
      mensagem:
          'O usuário perde o acesso em até 1 hora (o tempo de vida do token '
          'de acesso).',
      acao: 'Desativar',
      perigoso: true,
    );
    if (!ok) return;
    await _acao(
      u,
      () => _repo.desativarUsuario(u.id),
      sucesso: 'Usuário desativado.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuarios = ref.watch(usuariosProvider);
    final meuId = ref.watch(usuarioAtualProvider);
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const BotaoVoltar(destino: '/mais'),
        title: const Text('Usuários do painel'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _formulario,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Convidar'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.refresh(usuariosProvider.future).then((_) {}, onError: (_) {}),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            ValorAssincrono(
              valor: usuarios,
              aoTentarDeNovo: () => ref.invalidate(usuariosProvider),
              construir: (itens) => Column(
                children: [
                  for (final u in itens)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 4, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      u.id == meuId
                                          ? '${u.nome} (você)'
                                          : u.nome,
                                      style: tema.textTheme.titleMedium,
                                    ),
                                  ),
                                  _menu(u, proprio: u.id == meuId),
                                ],
                              ),
                              Text(u.email, style: tema.textTheme.bodySmall),
                              Text(
                                u.ultimoLoginEm == null
                                    ? 'Nunca entrou'
                                    : 'Último acesso: '
                                          '${formatarDataHora(u.ultimoLoginEm)}',
                                style: tema.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Selo(
                                    _papeis[u.papel] ?? u.papel,
                                    cor: tema.colorScheme.primary,
                                  ),
                                  if (!u.senhaDefinida)
                                    const Selo(
                                      'Convite pendente',
                                      cor: corAlerta,
                                      icone: Icons.mail_outline,
                                    ),
                                  if (!u.ativo)
                                    const Selo('inativo', cor: Colors.grey),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu(Usuario u, {required bool proprio}) {
    return PopupMenuButton<VoidCallback>(
      enabled: !_ocupados.contains(u.id),
      tooltip: 'Ações',
      onSelected: (f) => f(),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: () => _formulario(u, proprio),
          child: const Text('Editar'),
        ),
        if (!u.senhaDefinida)
          PopupMenuItem(
            value: () => _reenviar(u),
            child: const Text('Reenviar convite'),
          ),
        // O backend impede o admin de desativar ou rebaixar a si mesmo.
        if (!proprio && u.ativo)
          PopupMenuItem(
            value: () => _desativar(u),
            child: const Text('Desativar'),
          ),
        if (!proprio && !u.ativo)
          PopupMenuItem(
            value: () => _acao(
              u,
              () => _repo.editarUsuario(u.id, ativo: true),
              sucesso: 'Usuário reativado.',
            ),
            child: const Text('Reativar'),
          ),
      ],
    );
  }
}

/// Convite (usuário novo) e edição de nome e papel.
class _DialogoUsuario extends StatefulWidget {
  const _DialogoUsuario({
    required this.repo,
    required this.proprio,
    this.usuario,
  });

  final AdminRepo repo;
  final Usuario? usuario;

  /// O admin não pode mudar o próprio papel.
  final bool proprio;

  @override
  State<_DialogoUsuario> createState() => _DialogoUsuarioState();
}

class _DialogoUsuarioState extends State<_DialogoUsuario> {
  final _formulario = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.usuario?.nome);
  final _email = TextEditingController();
  late String _papel = widget.usuario?.papel ?? 'gerente';
  bool _salvando = false;
  String? _erroEmail;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    _erroEmail = null;
    if (_salvando || !_formulario.currentState!.validate()) return;
    setState(() => _salvando = true);
    final u = widget.usuario;
    try {
      if (u == null) {
        await widget.repo.convidar(
          nome: _nome.text.trim(),
          email: _email.text.trim(),
          papel: _papel,
        );
      } else {
        await widget.repo.editarUsuario(
          u.id,
          nome: _nome.text.trim(),
          papel: widget.proprio ? null : _papel,
        );
      }
      if (!mounted) return;
      if (u == null) snack(context, 'Convite enviado por e-mail.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.codigo == 'JA_EXISTE') {
        _erroEmail = 'Já existe um usuário com esse e-mail.';
        _formulario.currentState!.validate();
      } else {
        snackErro(context, e);
      }
      setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final novo = widget.usuario == null;
    return AlertDialog(
      title: Text(novo ? 'Convidar usuário' : 'Editar usuário'),
      content: Form(
        key: _formulario,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nome,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Informe o nome' : null,
              ),
              if (novo) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  onChanged: (_) => _erroEmail = null,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  validator: (v) => !(v ?? '').contains('@')
                      ? 'Informe o e-mail'
                      : _erroEmail,
                ),
              ],
              if (!widget.proprio) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _papel,
                  decoration: const InputDecoration(labelText: 'Papel'),
                  items: [
                    for (final p in _papeis.entries)
                      DropdownMenuItem(value: p.key, child: Text(p.value)),
                  ],
                  onChanged: (p) => setState(() => _papel = p ?? _papel),
                ),
              ],
              if (novo)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'O usuário recebe por e-mail um link para definir a '
                    'senha, válido por 48 horas.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: Text(novo ? 'Convidar' : 'Salvar'),
        ),
      ],
    );
  }
}
