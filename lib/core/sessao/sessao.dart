import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../api/cliente_api.dart';
import '../api/pagina.dart';
import 'armazenamento_token.dart';
import 'modelos.dart';

enum StatusSessao { iniciando, semConexao, deslogado, logado }

class EstadoSessao {
  const EstadoSessao(this.status, {this.usuario, this.loja});

  final StatusSessao status;
  final Usuario? usuario;
  final Loja? loja;

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
      ..aoPerder = () => state = const EstadoSessao(StatusSessao.deslogado);
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

  Future<void> definirSenha(String token, String senha) => _api.post(
    '/auth/definir-senha',
    corpo: {'token': token, 'senha': senha},
    publica: true,
  );
}
