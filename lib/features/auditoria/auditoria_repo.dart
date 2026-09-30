import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/pagina.dart';
import '../../core/sessao/sessao.dart';
import '../leads/leads_repo.dart';
import 'modelos.dart';

final auditoriaRepoProvider = Provider<AuditoriaRepo>((ref) {
  ref.watch(usuarioAtualProvider);
  return AuditoriaRepo(ref.watch(clienteApiProvider));
});

final historicoAuditoriasProvider = FutureProvider.autoDispose
    .family<List<ResumoAuditoria>, int>(
      (ref, leadId) => ref.watch(auditoriaRepoProvider).historico(leadId),
    );

final auditoriaProvider = FutureProvider.autoDispose.family<Auditoria, int>(
  (ref, id) => ref.watch(auditoriaRepoProvider).buscar(id),
);

class AuditoriaRepo {
  const AuditoriaRepo(this._api);

  final ClienteApi _api;

  /// `POST /leads/{id}/auditar`. Pode levar até ~80s (espera de áudios + IA).
  Future<ResultadoAuditoria> auditar(int leadId, {bool forcar = false}) async {
    final resposta = await _api.post(
      '/leads/$leadId/auditar',
      query: {if (forcar) 'forcar': 'true'},
      timeout: timeoutIA,
    );
    final h = resposta.headers;
    return ResultadoAuditoria(
      analise: AnaliseIA.deJson(mapa(resposta.data)),
      auditoriaId: int.tryParse(h.value('x-auditoria-id') ?? ''),
      reutilizada: h.value('x-auditoria-reutilizada') == 'true',
      transcricoesPendentes:
          int.tryParse(h.value('x-transcricoes-pendentes') ?? '') ?? 0,
    );
  }

  /// `GET /leads/{id}/auditorias`: a mais recente primeiro.
  Future<List<ResumoAuditoria>> historico(int leadId) async {
    final resposta = await _api.get('/leads/$leadId/auditorias');
    return Pagina.deJson(mapa(resposta.data), ResumoAuditoria.deJson).itens;
  }

  Future<Auditoria> buscar(int id) async =>
      Auditoria.deJson(mapa((await _api.get('/auditorias/$id')).data));

  /// `PATCH /auditorias/{id}`: só os campos informados mudam.
  Future<Auditoria> atualizar(
    int id, {
    bool? feedbackEntregue,
    String? observacaoGerente,
  }) async {
    final resposta = await _api.patch(
      '/auditorias/$id',
      corpo: {
        'feedback_entregue': ?feedbackEntregue,
        'observacao_gerente': ?observacaoGerente,
      },
    );
    return Auditoria.deJson(mapa(resposta.data));
  }
}

/// Estado do pedido de auditoria de um lead.
class EstadoAuditar {
  const EstadoAuditar({this.iniciadaEm, this.resultado, this.erro});

  /// Preenchido enquanto a requisição está em andamento.
  final DateTime? iniciadaEm;
  final ResultadoAuditoria? resultado;
  final Object? erro;

  bool get emAndamento => iniciadaEm != null;
}

/// Pedido de auditoria por lead. Não é `autoDispose` de propósito: o gerente
/// pode sair da tela, e a requisição continua (F04, item 2).
final auditarProvider =
    NotifierProvider.family<AuditarNotifier, EstadoAuditar, int>(
      AuditarNotifier.new,
    );

class AuditarNotifier extends Notifier<EstadoAuditar> {
  AuditarNotifier(this.leadId);

  final int leadId;

  @override
  EstadoAuditar build() {
    ref.watch(usuarioAtualProvider);
    return const EstadoAuditar();
  }

  Future<void> auditar({bool forcar = false}) async {
    if (state.emAndamento) return;
    final repo = ref.read(auditoriaRepoProvider);
    state = EstadoAuditar(iniciadaEm: DateTime.now());
    try {
      final resultado = await repo.auditar(leadId, forcar: forcar);
      if (!ref.mounted) return;
      state = EstadoAuditar(resultado: resultado);
      ref.invalidate(historicoAuditoriasProvider(leadId));
      ref.invalidate(leadProvider(leadId));
    } catch (e) {
      if (!ref.mounted) return;
      state = EstadoAuditar(erro: e);
    }
  }

  void limpar() {
    if (!state.emAndamento) state = const EstadoAuditar();
  }
}
