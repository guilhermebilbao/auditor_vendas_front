import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/pagina.dart';
import '../../core/sessao/sessao.dart';
import '../admin/modelos.dart';
import '../leads/leads_repo.dart';
import '../leads/modelos.dart';
import 'modelos.dart';

final atuacaoRepoProvider = Provider<AtuacaoRepo>((ref) {
  ref.watch(usuarioAtualProvider);
  return AtuacaoRepo(ref.watch(clienteApiProvider));
});

typedef ConsultaMetricas = ({String desde, String ate, int? vendedorId});

final metricasProvider = FutureProvider.autoDispose
    .family<MetricasAgregadas, ConsultaMetricas>(
      (ref, c) => ref
          .watch(atuacaoRepoProvider)
          .metricas(desde: c.desde, ate: c.ate, vendedorId: c.vendedorId),
    );

/// Fila de esquecidos: clientes sem resposta há mais que o limite (`30m`, `2h`
/// ou `1d`), em tempo corrido.
final esquecidosProvider = FutureProvider.autoDispose
    .family<List<Lead>, String>((ref, haMaisDe) async {
      final pagina = await ref
          .watch(leadsRepoProvider)
          .listar(FiltrosLeads(haMaisDe: haMaisDe), limite: 10);
      return pagina.itens;
    });

final rankingProvider = FutureProvider.autoDispose
    .family<List<ItemRanking>, ({String desde, String ate})>(
      (ref, c) =>
          ref.watch(atuacaoRepoProvider).ranking(desde: c.desde, ate: c.ate),
    );

final vendedorProvider = FutureProvider.autoDispose.family<Vendedor, int>(
  (ref, id) => ref.watch(atuacaoRepoProvider).vendedor(id),
);

final evolucaoProvider = FutureProvider.autoDispose
    .family<List<PontoEvolucao>, ({int vendedorId, String agrupamento})>(
      (ref, c) => ref
          .watch(atuacaoRepoProvider)
          .evolucao(c.vendedorId, agrupamento: c.agrupamento),
    );

class AtuacaoRepo {
  const AtuacaoRepo(this._api);

  final ClienteApi _api;

  /// `GET /metricas`: calculado no banco, sem IA.
  Future<MetricasAgregadas> metricas({
    required String desde,
    required String ate,
    int? vendedorId,
  }) async {
    final resposta = await _api.get(
      '/metricas',
      query: {'desde': desde, 'ate': ate, 'vendedor_id': vendedorId},
    );
    return MetricasAgregadas.deJson(mapa(resposta.data));
  }

  Future<List<ItemRanking>> ranking({
    required String desde,
    required String ate,
  }) async {
    final resposta = await _api.get(
      '/vendedores/ranking',
      query: {'desde': desde, 'ate': ate},
    );
    return Pagina.deJson(mapa(resposta.data), ItemRanking.deJson).itens;
  }

  Future<Vendedor> vendedor(int id) async =>
      Vendedor.deJson(mapa((await _api.get('/vendedores/$id')).data));

  /// [agrupamento]: `semana` ou `mes` (12 períodos por padrão).
  Future<List<PontoEvolucao>> evolucao(
    int vendedorId, {
    required String agrupamento,
  }) async {
    final resposta = await _api.get(
      '/vendedores/$vendedorId/evolucao',
      query: {'agrupamento': agrupamento},
    );
    return Pagina.deJson(mapa(resposta.data), PontoEvolucao.deJson).itens;
  }

  /// `GET /vendedores/{id}/pontos-de-melhoria`: **chama a IA** (a não ser que
  /// haja cache). Só deve ser chamada por ação do usuário.
  Future<PontosMelhoria> pontosDeMelhoria(
    int vendedorId, {
    required String desde,
    required String ate,
  }) async {
    final resposta = await _api.get(
      '/vendedores/$vendedorId/pontos-de-melhoria',
      query: {'desde': desde, 'ate': ate},
      timeout: timeoutIA,
    );
    return PontosMelhoria.deJson(mapa(resposta.data));
  }
}
