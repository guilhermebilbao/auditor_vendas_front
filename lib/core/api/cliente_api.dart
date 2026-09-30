import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import '../sessao/armazenamento_token.dart';
import '../sessao/servico_sessao.dart';
import 'api_exception.dart';

/// Tempo de resposta das rotas que chamam a IA (F01, item 2).
const timeoutIA = Duration(seconds: 120);

/// Camada única de acesso à API (F01). As telas usam os repositórios, que usam
/// esta classe; todo erro sai daqui como [ApiException].
class ClienteApi {
  ClienteApi({
    required ArmazenamentoToken armazenamento,
    String? urlBase,
    HttpClientAdapter? adaptador,
    DateTime Function()? agora,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: '${urlBase ?? apiUrl}/api/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
    if (adaptador != null) dio.httpClientAdapter = adaptador;
    sessao = ServicoSessao(
      dio: dio,
      armazenamento: armazenamento,
      agora: agora,
    );
    dio.interceptors.addAll([
      _RequestIdInterceptor(),
      AuthInterceptor(sessao, dio),
      if (kDebugMode) _ObsoletaInterceptor(),
    ]);
  }

  late final Dio dio;
  late final ServicoSessao sessao;

  Future<Response<dynamic>> get(
    String caminho, {
    Map<String, dynamic>? query,
    Duration? timeout,
    bool publica = false,
  }) => _executar(
    () => dio.get<dynamic>(
      caminho,
      queryParameters: _limpar(query),
      options: _opcoes(timeout, publica),
    ),
  );

  Future<Response<dynamic>> post(
    String caminho, {
    Object? corpo,
    Map<String, dynamic>? query,
    Duration? timeout,
    bool publica = false,
  }) => _executar(
    () => dio.post<dynamic>(
      caminho,
      data: corpo,
      queryParameters: _limpar(query),
      options: _opcoes(timeout, publica),
    ),
  );

  Future<Response<dynamic>> patch(String caminho, {Object? corpo}) =>
      _executar(() => dio.patch<dynamic>(caminho, data: corpo));

  Future<Response<dynamic>> delete(String caminho) =>
      _executar(() => dio.delete<dynamic>(caminho));

  Options _opcoes(Duration? timeout, bool publica) =>
      Options(receiveTimeout: timeout, extra: {if (publica) rotaPublica: true});

  // Filtros vazios não vão para a URL.
  Map<String, dynamic>? _limpar(Map<String, dynamic>? query) {
    if (query == null) return null;
    return {
      for (final e in query.entries)
        if (e.value != null && e.value.toString().isNotEmpty) e.key: e.value,
    };
  }

  Future<Response<dynamic>> _executar(
    Future<Response<dynamic>> Function() chamada,
  ) async {
    try {
      return await chamada();
    } on DioException catch (e) {
      throw ApiException.deDio(e);
    }
  }
}

class _RequestIdInterceptor extends Interceptor {
  final _aleatorio = Random();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-Request-ID'] ??= List.generate(
      16,
      (_) => _aleatorio.nextInt(16).toRadixString(16),
    ).join();
    handler.next(options);
  }
}

/// Injeta o token, renova antes de expirar e repete uma vez no
/// `401 TOKEN_EXPIRADO` (F01, itens 5 a 7).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._sessao, this._dio);

  final ServicoSessao _sessao;
  final Dio _dio;

  static const _token = '_token';
  static const _repetida = '_repetida';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[rotaPublica] == true) return handler.next(options);
    try {
      final token = await _sessao.tokenValido();
      options.headers['Authorization'] = 'Bearer $token';
      options.extra[_token] = token;
      handler.next(options);
    } on ApiException catch (e) {
      handler.reject(DioException(requestOptions: options, error: e), true);
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (options.extra[rotaPublica] == true || err.response?.statusCode != 401) {
      return handler.next(err);
    }

    final codigo = ApiException.deDio(err).codigo;
    final jaRepetida = options.extra[_repetida] == true;

    if (codigo == 'TOKEN_EXPIRADO' && !jaRepetida) {
      try {
        final sessao = await _sessao.renovar(
          tokenUsado: options.extra[_token] as String?,
        );
        options.headers['Authorization'] = 'Bearer ${sessao.accessToken}';
        options.extra[_repetida] = true;
        return handler.resolve(await _dio.fetch<dynamic>(options));
      } on DioException catch (e) {
        return handler.next(e);
      } on ApiException catch (e) {
        return handler.next(DioException(requestOptions: options, error: e));
      }
    }

    // `CREDENCIAIS_INVALIDAS` também é 401 (troca de senha) e não desloga.
    if (codigo == 'NAO_AUTENTICADO' || codigo == 'TOKEN_EXPIRADO') {
      await _sessao.perder();
    }
    handler.next(err);
  }
}

/// Em debug, avisa quando alguma chamada caiu numa rota sem `/v1` (F01, item 15).
class _ObsoletaInterceptor extends Interceptor {
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (response.headers.value('deprecation') != null) {
      debugPrint('Rota obsoleta (sem /v1): ${response.requestOptions.uri}');
    }
    handler.next(response);
  }
}
