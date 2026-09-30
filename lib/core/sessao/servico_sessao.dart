import 'package:dio/dio.dart';

import '../api/api_exception.dart';
import '../api/pagina.dart';
import 'armazenamento_token.dart';
import 'modelos.dart';

/// Marca, em `Options.extra`, as rotas que não levam o token de acesso
/// (`/auth/*`).
const rotaPublica = 'publica';

/// Tokens da sessão (F01, itens 3 a 8): o token de acesso fica em memória, o
/// refresh token no [armazenamento], e a renovação passa por uma fila única.
class ServicoSessao {
  ServicoSessao({
    required this._dio,
    required this.armazenamento,
    DateTime Function()? agora,
  }) : _agora = agora ?? DateTime.now;

  final Dio _dio;
  final ArmazenamentoToken armazenamento;
  final DateTime Function() _agora;

  Sessao? _sessao;
  Future<Sessao>? _renovando;

  /// Chamado a cada sessão nova (login ou renovação).
  void Function(Sessao sessao)? aoAtualizar;

  /// Chamado quando a sessão deixa de valer (refresh recusado, `NAO_AUTENTICADO`).
  void Function()? aoPerder;

  static final _publica = Options(extra: {rotaPublica: true});

  bool get _expiraLogo {
    final sessao = _sessao;
    if (sessao == null) return true;
    return sessao.expiraEm.difference(_agora()) < const Duration(seconds: 60);
  }

  /// Token de acesso pronto para uso; renova antes se faltar menos de 60s.
  Future<String> tokenValido() async {
    if (!_expiraLogo) return _sessao!.accessToken;
    return (await renovar()).accessToken;
  }

  /// Renova a sessão. Por causa da rotação do refresh token, duas renovações
  /// simultâneas derrubariam a sessão: todas as chamadas esperam a mesma.
  ///
  /// [tokenUsado] é o token da requisição que recebeu `TOKEN_EXPIRADO`: se
  /// outra requisição já renovou nesse meio tempo, reaproveita o resultado.
  Future<Sessao> renovar({String? tokenUsado}) {
    final atual = _sessao;
    if (tokenUsado != null &&
        atual != null &&
        atual.accessToken != tokenUsado &&
        !_expiraLogo) {
      return Future.value(atual);
    }
    return _renovando ??= _renovar().whenComplete(() => _renovando = null);
  }

  Future<Sessao> _renovar() async {
    final refresh = await armazenamento.ler();
    if (refresh == null) {
      await perder();
      throw const ApiException(status: 401, codigo: 'NAO_AUTENTICADO');
    }
    try {
      final resposta = await _dio.post<dynamic>(
        '/auth/refresh',
        data: {'refresh_token': refresh},
        options: _publica,
      );
      return await _aplicar(Sessao.deJson(mapa(resposta.data)));
    } on DioException catch (e) {
      final erro = ApiException.deDio(e);
      // Sem rede não invalida a sessão: só o `401` do refresh.
      if (erro.status == 401) await perder();
      throw erro;
    }
  }

  Future<Sessao> _aplicar(Sessao sessao) async {
    _sessao = sessao;
    await armazenamento.gravar(sessao.refreshToken);
    aoAtualizar?.call(sessao);
    return sessao;
  }

  /// Ao abrir o app: entra com o refresh token guardado, se houver.
  Future<Sessao?> restaurar() async {
    if (await armazenamento.ler() == null) return null;
    return renovar();
  }

  Future<Sessao> entrar(String email, String senha) async {
    try {
      final resposta = await _dio.post<dynamic>(
        '/auth/login',
        data: {'email': email.trim(), 'senha': senha},
        options: _publica,
      );
      return await _aplicar(Sessao.deJson(mapa(resposta.data)));
    } on DioException catch (e) {
      throw ApiException.deDio(e);
    }
  }

  Future<void> sair() async {
    final refresh = await armazenamento.ler();
    _sessao = null;
    await armazenamento.apagar();
    if (refresh == null) return;
    try {
      await _dio.post<dynamic>(
        '/auth/logout',
        data: {'refresh_token': refresh},
        options: _publica,
      );
    } on DioException {
      // O logout no servidor é o melhor esforço (F01, item 8).
    }
  }

  Future<void> perder() async {
    _sessao = null;
    await armazenamento.apagar();
    aoPerder?.call();
  }
}
