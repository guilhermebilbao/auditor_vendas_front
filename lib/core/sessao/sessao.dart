import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../api/cliente_api.dart';
import '../api/pagina.dart';
import 'armazenamento_token.dart';
import 'modelos.dart';

enum StatusSessao { iniciando, semConexao, deslogado, logado }

class EstadoSessao {
  const EstadoSessao(this.status, {this.usuario, this.loja, this.aviso});

  final StatusSessao status;
  final Usuario? usuario;
  final Loja? loja;

  /// Por que a sessão terminou sem o usuário pedir (ex.: loja cancelada).
  /// A tela de login mostra.
  final String? aviso;

  bool get logado => status == StatusSessao.logado;
  bool get admin => usuario?.admin ?? false;
}

final armazenamentoTokenProvider = Provider<ArmazenamentoToken>(
  (ref) => const ArmazenamentoSeguro(),
);

final clienteApiProvider = Provider<ClienteApi>(
  (ref) => ClienteApi(armazenamento: ref.watch(armazenamentoTokenProvider)),
);

final sessaoProvider = NotifierProvider<SessaoNotifier, EstadoSessao>(
  SessaoNotifier.new,
);

/// Muda a cada troca de usuário. Os repositórios observam este valor, então o
/// cache de uma loja nunca aparece para outro usuário (F01, item 8).
final usuarioAtualProvider = Provider<int?>(
  (ref) => ref.watch(sessaoProvider.select((s) => s.usuario?.id)),
);

class SessaoNotifier extends Notifier<EstadoSessao> {
  late ClienteApi _api;

  @override
  EstadoSessao build() {
    _api = ref.watch(clienteApiProvider);
    _api.sessao
      ..aoAtualizar = ((s) {
        state = EstadoSessao(
          StatusSessao.logado,
          usuario: s.usuario,
          loja: s.loja,
        );
      })
      ..aoPerder = (() => state = const EstadoSessao(StatusSessao.deslogado))
      ..aoLojaInativa = _lojaInativa;
    Future.microtask(restaurar);
    return const EstadoSessao(StatusSessao.iniciando);
  }

  /// Ao abrir o app (F01, item 4).
  Future<void> restaurar() async {
    state = const EstadoSessao(StatusSessao.iniciando);
    try {
      final sessao = await _api.sessao.restaurar();
      if (sessao == null) {
        state = const EstadoSessao(StatusSessao.deslogado);
      } else {
        unawaited(recarregar().catchError((_) {}));
      }
    } on ApiException catch (e) {
      state = EstadoSessao(
        e.status == 401 ? StatusSessao.deslogado : StatusSessao.semConexao,
      );
    }
  }

  Future<void> entrar(String email, String senha) =>
      _api.sessao.entrar(email, senha);

  Future<void> sair() async {
    await _api.sessao.sair();
    state = const EstadoSessao(StatusSessao.deslogado);
  }

  Future<void>? _relendoEstado;

  /// A loja mudou de estado no meio do uso (spec 19, item 37): relê o `/me`
  /// para o roteador levar à tela certa. Loja cancelada encerra a sessão.
  void _lojaInativa(String codigo) {
    if (codigo == 'LOJA_CANCELADA') {
      unawaited(
        _api.sessao.sair().whenComplete(
          () => state = const EstadoSessao(
            StatusSessao.deslogado,
            aviso: 'A assinatura desta loja foi cancelada.',
          ),
        ),
      );
      return;
    }
    // Várias telas podem receber o 403 juntas: uma releitura basta.
    _relendoEstado ??= recarregar()
        .catchError((_) {})
        .whenComplete(() => _relendoEstado = null);
  }

  /// `GET /me`: usuário e loja atuais (F01, item 9).
  Future<void> recarregar() async {
    final resposta = await _api.get('/me');
    final json = mapa(resposta.data);
    if (!state.logado) return;
    state = EstadoSessao(
      StatusSessao.logado,
      usuario: Usuario.deJson(mapa(json['usuario'])),
      loja: Loja.deJson(mapa(json['loja'])),
    );
  }

  Future<void> trocarSenha(String atual, String nova) => _api.patch(
    '/me/senha',
    corpo: {'senha_atual': atual, 'senha_nova': nova},
  );

  Future<void> esqueciSenha(String email) => _api.post(
    '/auth/esqueci-senha',
    corpo: {'email': email.trim()},
    publica: true,
  );

  /// `POST /cadastro`: a resposta é sempre a mesma, exista ou não o e-mail
  /// (spec 19, item 2).
  Future<void> cadastrar({
    required String nomeLoja,
    required String nome,
    required String email,
    required String cpfCnpj,
    required String versaoTermos,
  }) => _api.post(
    '/cadastro',
    corpo: {
      'nome_loja': nomeLoja.trim(),
      'nome': nome.trim(),
      'email': email.trim(),
      'cpf_cnpj': cpfCnpj,
      'aceite_termos': true,
      'versao_termos': versaoTermos,
    },
    publica: true,
  );

  /// Cria a loja e já entra; o roteador leva à tela de pagamento pendente.
  Future<void> confirmarCadastro(String token, String senha) =>
      _api.sessao.confirmarCadastro(token, senha);

  Future<void> definirSenha(String token, String senha) => _api.post(
    '/auth/definir-senha',
    corpo: {'token': token, 'senha': senha},
    publica: true,
  );
}
