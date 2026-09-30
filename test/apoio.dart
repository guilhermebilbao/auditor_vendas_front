import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Servidor falso para o `dio`: responde pelo [responder] e guarda as chamadas.
class AdaptadorFalso implements HttpClientAdapter {
  AdaptadorFalso(this.responder);

  final FutureOr<ResponseBody> Function(RequestOptions) responder;
  final chamadas = <RequestOptions>[];

  int vezes(String caminho) =>
      chamadas.where((c) => c.uri.path.endsWith(caminho)).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    chamadas.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody respostaJson(
  int status,
  Object? corpo, {
  Map<String, String> headers = const {},
}) => ResponseBody.fromString(
  corpo == null ? '' : jsonEncode(corpo),
  status,
  headers: {
    'content-type': ['application/json'],
    for (final h in headers.entries) h.key: [h.value],
  },
);

ResponseBody respostaErro(int status, String codigo, {String erro = ''}) =>
    respostaJson(status, {'erro': erro, 'codigo': codigo, 'detalhes': {}});

Map<String, dynamic> sessaoJson(String token, DateTime expiraEm) => {
  'access_token': 'acesso-$token',
  'refresh_token': 'refresh-$token',
  'token_type': 'Bearer',
  'expira_em': expiraEm.toUtc().toIso8601String(),
  'usuario': {
    'id': 1,
    'nome': 'Ana',
    'email': 'ana@loja.com',
    'papel': 'admin',
    'ativo': true,
    'senha_definida': true,
    'ultimo_login_em': null,
    'criado_em': '2026-09-01T10:00:00-03:00',
  },
  'loja': {
    'id': 'loja_centro',
    'nome': 'Loja Centro',
    'retencao_meses': 12,
    'sla_resposta_min': 15,
    'horario_comercial': {
      'seg': [
        ['08:00', '12:00'],
        ['13:00', '18:00'],
      ],
      'dom': [],
    },
    'pesos_criterios': {'agilidade': 2},
  },
};

/// Envolve um widget no mínimo que as telas do app esperam.
Widget app(Widget filho) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(body: filho),
  ),
);

/// PNG transparente de 1x1, para os testes que exibem uma imagem.
final pngMinimo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);
