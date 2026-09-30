import 'dart:convert';

import 'package:dio/dio.dart';

/// Erro único da camada de API (F01, item 10). As telas decidem o que mostrar
/// pelo [codigo], nunca pela [mensagem].
class ApiException implements Exception {
  const ApiException({
    required this.codigo,
    this.status,
    this.mensagem = '',
    this.detalhes = const {},
    this.requestId,
  });

  static const semConexao = 'SEM_CONEXAO';
  static const tempoEsgotado = 'TEMPO_ESGOTADO';
  static const cancelada = 'CANCELADA';
  static const desconhecido = 'ERRO_DESCONHECIDO';

  final int? status;
  final String codigo;
  final String mensagem;
  final Map<String, dynamic> detalhes;
  final String? requestId;

  bool get deRede => codigo == semConexao || codigo == tempoEsgotado;

  factory ApiException.deDio(DioException e) {
    final original = e.error;
    if (original is ApiException) return original;

    final requestId =
        e.response?.headers.value('x-request-id') ??
        e.requestOptions.headers['X-Request-ID']?.toString();

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(codigo: tempoEsgotado, requestId: requestId);
      case DioExceptionType.cancel:
        return ApiException(codigo: cancelada, requestId: requestId);
      case DioExceptionType.connectionError:
        return ApiException(codigo: semConexao, requestId: requestId);
      default:
        break;
    }

    final resposta = e.response;
    if (resposta == null) {
      return ApiException(codigo: semConexao, requestId: requestId);
    }

    var corpo = resposta.data;
    if (corpo is String && corpo.isNotEmpty) {
      try {
        corpo = jsonDecode(corpo);
      } on FormatException {
        // corpo que não é JSON: cai no código genérico abaixo
      }
    }
    if (corpo is Map && corpo['codigo'] is String) {
      final detalhes = corpo['detalhes'];
      return ApiException(
        status: resposta.statusCode,
        codigo: corpo['codigo'] as String,
        mensagem: corpo['erro']?.toString() ?? '',
        detalhes: detalhes is Map
            ? Map<String, dynamic>.from(detalhes)
            : const {},
        requestId: requestId,
      );
    }
    return ApiException(
      status: resposta.statusCode,
      codigo: desconhecido,
      requestId: requestId,
    );
  }

  @override
  String toString() => 'ApiException($status, $codigo, $mensagem)';
}
