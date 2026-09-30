import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/pagina.dart';
import '../../core/sessao/sessao.dart';
import 'modelos.dart';

final leadsRepoProvider = Provider<LeadsRepo>((ref) {
  ref.watch(usuarioAtualProvider);
  return LeadsRepo(ref.watch(clienteApiProvider));
});

final leadProvider = FutureProvider.autoDispose.family<LeadDetalhe, int>(
  (ref, id) => ref.watch(leadsRepoProvider).detalhe(id),
);

final metricasLeadProvider = FutureProvider.autoDispose
    .family<MetricasLead, int>(
      (ref, id) => ref.watch(leadsRepoProvider).metricas(id),
    );

// RFC 3339 em UTC, sem fração de segundo.
String _rfc3339(DateTime instante) =>
    '${instante.toUtc().toIso8601String().split('.').first}Z';

class LeadsRepo {
  const LeadsRepo(this._api);

  final ClienteApi _api;

  /// `GET /leads`. Com [atualizadosDesde], traz só os leads com mensagem ou
  /// auditoria nova desde aquele instante.
  Future<Pagina<Lead>> listar(
    FiltrosLeads filtros, {
    String? cursor,
    int limite = 50,
    DateTime? atualizadosDesde,
  }) async {
    final resposta = await _api.get(
      '/leads',
      query: {
        ...filtros.paraQuery(),
        'limit': limite,
        'cursor': cursor,
        'atualizados_desde': atualizadosDesde == null
            ? null
            : _rfc3339(atualizadosDesde),
      },
    );
    return Pagina.deJson(mapa(resposta.data), Lead.deJson);
  }

  Future<LeadDetalhe> detalhe(int id) async =>
      LeadDetalhe.deJson(mapa((await _api.get('/leads/$id')).data));

  /// `GET /leads/{id}/mensagens`.
  ///
  /// Sem parâmetros é a abertura da conversa, que o backend registra como
  /// leitura (LGPD). [antes], [depois] e [ids] não geram esse registro.
  Future<PaginaMensagens> mensagens(
    int leadId, {
    int? limite,
    String? antes,
    String? depois,
    List<int>? ids,
  }) async {
    final resposta = await _api.get(
      '/leads/$leadId/mensagens',
      query: {
        'limit': limite,
        'antes': antes,
        'depois': depois,
        'ids': ids?.join(','),
      },
    );
    return PaginaMensagens.deJson(mapa(resposta.data));
  }

  Future<MetricasLead> metricas(int id) async =>
      MetricasLead.deJson(mapa((await _api.get('/leads/$id/metricas')).data));

  /// `GET /leads/{id}/export` (admin): o JSON com todos os dados do cliente.
  Future<String> exportar(int id) async {
    final resposta = await _api.get('/leads/$id/export');
    return const JsonEncoder.withIndent('  ').convert(resposta.data);
  }

  /// `DELETE /leads/{id}` (admin): exclusão definitiva.
  Future<void> excluir(int id) => _api.delete('/leads/$id');
}
