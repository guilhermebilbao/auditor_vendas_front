import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/pagina.dart';
import '../../core/sessao/sessao.dart';

/// `GET /assinatura` (spec 19, item 24). Sem valores nem link de pagamento: o
/// link vai só por e-mail, por causa das regras das lojas de aplicativos.
class Assinatura {
  const Assinatura({
    required this.estado,
    this.planoNome,
    this.planoMaxInstancias,
    this.proximaCobranca,
    this.inadimplenteDesde,
    this.motivoSuspensao,
    this.trialAte,
    this.auditoriasRestantesHoje,
    this.transcricoesRestantesHoje,
  });

  final String estado;

  /// `null` = loja de contrato, sem assinatura pelo app.
  final String? planoNome;
  final int? planoMaxInstancias;

  /// Dia da próxima cobrança (sem horário).
  final DateTime? proximaCobranca;
  final DateTime? inadimplenteDesde;

  /// `inadimplencia`, `estorno`, `cancelada_pelo_cliente` ou `suporte`.
  final String? motivoSuspensao;

  /// Fim do teste grátis (spec 20); `null` se a loja nunca teve trial.
  final DateTime? trialAte;

  /// Cotas de hoje no teste grátis; `null` fora do trial.
  final int? auditoriasRestantesHoje;
  final int? transcricoesRestantesHoje;

  factory Assinatura.deJson(Map<String, dynamic> j) {
    final plano = j['plano'] is Map ? mapa(j['plano']) : null;
    return Assinatura(
      estado: texto(j['estado']),
      planoNome: plano == null ? null : texto(plano['nome']),
      planoMaxInstancias: plano == null
          ? null
          : inteiro(plano['max_instancias']),
      proximaCobranca: DateTime.tryParse(texto(j['proxima_cobranca'])),
      inadimplenteDesde: data(j['inadimplente_desde']),
      motivoSuspensao: j['motivo_suspensao'] == null
          ? null
          : texto(j['motivo_suspensao']),
      trialAte: data(j['trial_ate']),
      auditoriasRestantesHoje: inteiro(j['auditorias_restantes_hoje']),
      transcricoesRestantesHoje: inteiro(j['transcricoes_restantes_hoje']),
    );
  }
}

final assinaturaRepoProvider = Provider<AssinaturaRepo>((ref) {
  ref.watch(usuarioAtualProvider);
  return AssinaturaRepo(ref.watch(clienteApiProvider));
});

final assinaturaProvider = FutureProvider.autoDispose<Assinatura>(
  (ref) => ref.watch(assinaturaRepoProvider).buscar(),
);

class AssinaturaRepo {
  const AssinaturaRepo(this._api);

  final ClienteApi _api;

  Future<Assinatura> buscar() async =>
      Assinatura.deJson(mapa((await _api.get('/assinatura')).data));

  /// Manda o link de pagamento de novo para o e-mail dos admins (só admin;
  /// 3 por hora por loja). No teste grátis, é o "Quero assinar" (spec 20).
  Future<void> reenviarLink() => _api.post(
    '/assinatura/reenviar-link',
    timeout: const Duration(seconds: 50),
  );
}
