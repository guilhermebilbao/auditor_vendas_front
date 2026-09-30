import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/formatos.dart';
import '../../widgets/estados.dart';
import '../../widgets/navegacao.dart';
import '../../widgets/selos.dart';
import 'admin_repo.dart';
import 'dialogo_qr.dart';
import 'modelos.dart';
import 'selo_whatsapp.dart';

/// Vendedores e a conexão do WhatsApp de cada um (F06, itens 1 a 12).
class VendedoresTela extends ConsumerStatefulWidget {
  const VendedoresTela({super.key});

  @override
  ConsumerState<VendedoresTela> createState() => _VendedoresTelaState();
}

class _VendedoresTelaState extends ConsumerState<VendedoresTela> {
  /// Vendedores com uma ação em andamento: os botões ficam desabilitados.
  final _ocupados = <int>{};

  AdminRepo get _repo => ref.read(adminRepoProvider);

  void _recarregar() => ref.invalidate(vendedoresProvider);

  Future<void> _acao(
    Vendedor v,
    Future<void> Function() acao, {
    String? sucesso,
  }) async {
    if (_ocupados.contains(v.id)) return;
    setState(() => _ocupados.add(v.id));
    await executarAcao(context, acao, sucesso: sucesso);
    if (!mounted) return;
    setState(() => _ocupados.remove(v.id));
    _recarregar();
  }

  Future<void> _abrirQr(Vendedor v, String instanciaId) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DialogoQr(
        repo: _repo,
        instanciaId: instanciaId,
        vendedorNome: v.nome,
      ),
    );
    _recarregar();
  }

  Future<void> _conectar(Vendedor v) => _acao(v, () async {
    String instanciaId;
    try {
      instanciaId = (await _repo.criarInstancia(v.id)).id;
    } on ApiException catch (e) {
      // O vendedor já tem uma instância: abre a existente.
      if (e.codigo != 'INSTANCIA_JA_ATIVA') rethrow;
      final existente = (await _repo.buscarVendedor(v.id)).instancia;
      if (existente == null) rethrow;
      instanciaId = existente.id;
    }
    if (mounted) await _abrirQr(v, instanciaId);
  });

  Future<void> _reconectar(Vendedor v) => _acao(v, () async {
    await _repo.reconectar(v.instancia!.id);
    if (mounted) await _abrirQr(v, v.instancia!.id);
  });

  Future<void> _atualizarStatus(Vendedor v) => _acao(v, () async {
    final instancia = await _repo.buscarInstancia(v.instancia!.id);
    if (!mounted) return;
    final erro = instancia.ultimoErro;
    snack(
      context,
      'Status: ${instancia.status}'
      '${erro == null || erro.isEmpty ? '' : ' ($erro)'}',
    );
  });

  Future<void> _removerWhatsApp(Vendedor v) async {
    final ok = await confirmar(
      context,
      titulo: 'Remover WhatsApp',
      mensagem:
          'O número será desvinculado de ${v.nome}; o histórico fica. '
          'Depois, conecte de novo para usar outro número.',
      acao: 'Remover',
      perigoso: true,
    );
    if (!ok) return;
    await _acao(
      v,
      () => _repo.removerInstancia(v.instancia!.id),
      sucesso: 'WhatsApp removido.',
    );
  }

  Future<void> _editar([Vendedor? v]) async {
    final salvou = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogoVendedor(repo: _repo, vendedor: v),
    );
    if (salvou == true) _recarregar();
  }

  Future<void> _alternarAtivo(Vendedor v) async {
    if (v.ativo) {
      final ok = await confirmar(
        context,
        titulo: 'Desativar ${v.nome}',
        mensagem:
            'O WhatsApp do vendedor será desconectado. O histórico continua.',
        acao: 'Desativar',
        perigoso: true,
      );
      if (!ok) return;
    }
    await _acao(
      v,
      () => _repo.editarVendedor(v.id, ativo: !v.ativo),
      sucesso: v.ativo
          ? 'Vendedor desativado.'
          : 'Vendedor reativado. Conecte o WhatsApp de novo.',
    );
  }

  Future<void> _excluir(Vendedor v) async {
    final ok = await confirmar(
      context,
      titulo: 'Excluir ${v.nome}',
      mensagem:
          'Se o vendedor tiver conversas registradas, ele será desativado em '
          'vez de excluído.',
      acao: 'Excluir',
      perigoso: true,
    );
    if (!ok) return;
    await _acao(v, () async {
      final resultado = await _repo.excluirVendedor(v.id);
      if (!mounted) return;
      snack(
        context,
        resultado.desativado == null
            ? 'Vendedor excluído.'
            : 'O vendedor tem conversas registradas e foi desativado em vez '
                  'de excluído.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final vendedores = ref.watch(vendedoresProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const BotaoVoltar(destino: '/mais'),
        title: const Text('Vendedores e WhatsApp'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _editar,
        icon: const Icon(Icons.add),
        label: const Text('Novo vendedor'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref
            .refresh(vendedoresProvider.future)
            .then((_) {}, onError: (_) {}),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            ValorAssincrono(
              valor: vendedores,
              aoTentarDeNovo: _recarregar,
              construir: (itens) => itens.isEmpty
                  ? const Vazio(
                      'Nenhum vendedor cadastrado.',
                      icone: Icons.badge_outlined,
                    )
                  : Column(children: [for (final v in itens) _cartao(v)]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartao(Vendedor v) {
    final tema = Theme.of(context);
    final ocupado = _ocupados.contains(v.id);
    final instancia = v.instancia;
    final (rotulo, cor) = seloDoWhatsApp(instancia);

    // A ação sugerida depende do estado da conexão (F06, item 2).
    final (String, VoidCallback)? acao = switch (instancia?.status) {
      _ when !v.ativo => null,
      null => ('Conectar WhatsApp', () => _conectar(v)),
      'aguardando_qr' ||
      'criada' => ('Mostrar QR code', () => _abrirQr(v, instancia!.id)),
      'desconectada' => ('Reconectar', () => _reconectar(v)),
      _ => null,
    };

    return Padding(
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
                    child: Text(v.nome, style: tema.textTheme.titleMedium),
                  ),
                  PopupMenuButton<VoidCallback>(
                    enabled: !ocupado,
                    tooltip: 'Ações',
                    onSelected: (f) => f(),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: () => _editar(v),
                        child: const Text('Editar'),
                      ),
                      if (instancia != null) ...[
                        PopupMenuItem(
                          value: () => _atualizarStatus(v),
                          child: const Text('Atualizar status'),
                        ),
                        PopupMenuItem(
                          value: () => _removerWhatsApp(v),
                          child: const Text('Remover WhatsApp'),
                        ),
                      ],
                      PopupMenuItem(
                        value: () => _alternarAtivo(v),
                        child: Text(v.ativo ? 'Desativar' : 'Reativar'),
                      ),
                      PopupMenuItem(
                        value: () => _excluir(v),
                        child: const Text('Excluir'),
                      ),
                    ],
                  ),
                ],
              ),
              if (v.telefone.isNotEmpty)
                Text(
                  formatarTelefone(v.telefone),
                  style: tema.textTheme.bodySmall,
                ),
              if (v.email.isNotEmpty)
                Text(v.email, style: tema.textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (!v.ativo) const Selo('inativo', cor: Colors.grey),
                  Selo(rotulo, cor: cor, icone: Icons.chat_outlined),
                ],
              ),
              if (acao != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton.tonal(
                    onPressed: ocupado ? null : acao.$2,
                    child: Text(acao.$1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cadastro e edição de vendedor (F06, itens 3 e 4).
class _DialogoVendedor extends StatefulWidget {
  const _DialogoVendedor({required this.repo, this.vendedor});

  final AdminRepo repo;
  final Vendedor? vendedor;

  @override
  State<_DialogoVendedor> createState() => _DialogoVendedorState();
}

class _DialogoVendedorState extends State<_DialogoVendedor> {
  final _formulario = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.vendedor?.nome);
  late final _telefone = TextEditingController(text: widget.vendedor?.telefone);
  late final _email = TextEditingController(text: widget.vendedor?.email);
  bool _salvando = false;

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_salvando || !_formulario.currentState!.validate()) return;
    setState(() => _salvando = true);
    final v = widget.vendedor;
    final ok = await executarAcao(context, () async {
      if (v == null) {
        await widget.repo.criarVendedor(
          nome: _nome.text.trim(),
          telefone: _telefone.text.trim(),
          email: _email.text.trim(),
        );
      } else {
        await widget.repo.editarVendedor(
          v.id,
          nome: _nome.text.trim(),
          telefone: _telefone.text.trim(),
          email: _email.text.trim(),
        );
      }
    });
    if (!mounted) return;
    if (ok) return Navigator.pop(context, true);
    setState(() => _salvando = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.vendedor == null ? 'Novo vendedor' : 'Editar vendedor',
      ),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefone (opcional)',
                  hintText: '55 48 99999-9999',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'E-mail (opcional)',
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
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
