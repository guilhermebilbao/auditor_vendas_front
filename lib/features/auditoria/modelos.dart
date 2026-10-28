import '../../core/api/pagina.dart';

/// Nota de um critério. `nota == null` quer dizer "sem base na conversa para
/// avaliar": aparece como "não avaliado", nunca como zero.
class Criterio {
  const Criterio({this.nota, this.justificativa = ''});

  final int? nota;
  final String justificativa;

  factory Criterio.deJson(Map<String, dynamic> j) => Criterio(
    nota: inteiro(j['nota']),
    justificativa: texto(j['justificativa']),
  );
}

/// Quanto o cliente dificultou um aspecto da negociação (spec 21): 0 = facilitou,
/// 10 = dificultou muito. `dificuldade == null` aparece como "não avaliado".
class CriterioCliente {
  const CriterioCliente({this.dificuldade, this.justificativa = ''});

  final int? dificuldade;
  final String justificativa;

  factory CriterioCliente.deJson(Map<String, dynamic> j) => CriterioCliente(
    dificuldade: inteiro(j['dificuldade']),
    justificativa: texto(j['justificativa']),
  );
}

/// Comportamento do cliente observado na conversa e o efeito na negociação.
class ComportamentoCliente {
  const ComportamentoCliente({
    required this.descricao,
    required this.dificultou,
  });

  final String descricao;

  /// `false` = facilitou.
  final bool dificultou;

  factory ComportamentoCliente.deJson(Map<String, dynamic> j) =>
      ComportamentoCliente(
        descricao: texto(j['descricao']),
        dificultou: texto(j['efeito']) != 'facilitou',
      );
}

/// Avaliação do comportamento do cliente (schema `AvaliacaoCliente`, spec 21).
class AvaliacaoCliente {
  const AvaliacaoCliente({
    required this.perfil,
    required this.criterios,
    required this.comportamentos,
    required this.fatoresExternos,
    required this.leituraImparcial,
  });

  final String perfil;

  /// Por critério (`clareza_necessidade`, `engajamento`, ...).
  final Map<String, CriterioCliente> criterios;
  final List<ComportamentoCliente> comportamentos;
  final List<String> fatoresExternos;
  final String leituraImparcial;

  static const _naoCriterios = {
    'perfil_predominante',
    'comportamentos_observados',
    'fatores_externos',
    'leitura_imparcial',
  };

  factory AvaliacaoCliente.deJson(Map<String, dynamic> j) => AvaliacaoCliente(
    perfil: texto(j['perfil_predominante']),
    criterios: {
      for (final e in j.entries)
        if (!_naoCriterios.contains(e.key) && e.value is Map)
          e.key: CriterioCliente.deJson(mapa(e.value)),
    },
    comportamentos: [
      for (final c in (j['comportamentos_observados'] as List?) ?? const [])
        if (c is Map) ComportamentoCliente.deJson(mapa(c)),
    ],
    fatoresExternos: listaDeTextos(j['fatores_externos']),
    leituraImparcial: texto(j['leitura_imparcial']),
  );
}

/// Resultado da auditoria com IA (schema `AnaliseIA`).
class AnaliseIA {
  const AnaliseIA({
    required this.veiculoInteresse,
    required this.temCarroNaTroca,
    required this.formaPagamento,
    required this.temperatura,
    required this.estagioJornada,
    required this.urgenciaCompra,
    required this.pontosFortes,
    required this.falhas,
    required this.objecoes,
    required this.avaliacao,
    required this.notaGeral,
    required this.probabilidadeConversao,
    required this.feedbackVendedor,
    required this.proximosPassos,
    this.cliente,
    this.indiceDificuldadeCliente,
    this.faixaDificuldadeCliente,
  });

  final String veiculoInteresse;

  /// `null` = não mencionado.
  final bool? temCarroNaTroca;
  final String formaPagamento;

  final String temperatura;
  final String estagioJornada;
  final String urgenciaCompra;

  final List<String> pontosFortes;
  final List<String> falhas;
  final List<String> objecoes;

  /// Por critério (`agilidade`, `rapport`, ...). Vazio em auditorias antigas.
  final Map<String, Criterio> avaliacao;

  /// Nula em auditorias antigas (prompt v1).
  final double? notaGeral;
  final int? probabilidadeConversao;

  final String feedbackVendedor;
  final List<String> proximosPassos;

  /// Nula nas auditorias anteriores ao prompt v3 (spec 21).
  final AvaliacaoCliente? cliente;

  /// Calculados pelo backend: média dos critérios do cliente e a faixa.
  final double? indiceDificuldadeCliente;
  final String? faixaDificuldadeCliente;

  factory AnaliseIA.deJson(Map<String, dynamic> j) {
    final negocio = mapa(j['perfil_do_negocio']);
    final lead = mapa(j['qualificacao_lead']);
    final tecnica = mapa(j['analise_tecnica_vendedor']);
    final plano = mapa(j['plano_acao_gestor']);
    return AnaliseIA(
      veiculoInteresse: texto(negocio['veiculo_interesse']),
      temCarroNaTroca: negocio['tem_carro_na_troca'] as bool?,
      formaPagamento: texto(negocio['forma_pagamento_citada']),
      temperatura: texto(lead['temperatura']),
      estagioJornada: texto(lead['estagio_jornada']),
      urgenciaCompra: texto(lead['urgencia_compra']),
      pontosFortes: listaDeTextos(tecnica['pontos_fortes']),
      falhas: listaDeTextos(tecnica['falhas_e_gargalos']),
      objecoes: listaDeTextos(tecnica['objecoes_levantadas']),
      avaliacao: {
        for (final e in mapa(j['avaliacao_vendedor']).entries)
          if (e.value is Map) e.key: Criterio.deJson(mapa(e.value)),
      },
      notaGeral: decimal(j['nota_geral']),
      probabilidadeConversao: inteiro(j['probabilidade_conversao']),
      feedbackVendedor: texto(plano['feedback_vendedor']),
      proximosPassos: listaDeTextos(plano['proximos_passos_sugeridos']),
      cliente: j['avaliacao_cliente'] is Map
          ? AvaliacaoCliente.deJson(mapa(j['avaliacao_cliente']))
          : null,
      indiceDificuldadeCliente: decimal(j['indice_dificuldade_cliente']),
      faixaDificuldadeCliente: j['faixa_dificuldade_cliente'] as String?,
    );
  }
}

/// Item do histórico de auditorias de um lead.
class ResumoAuditoria {
  const ResumoAuditoria({
    required this.id,
    required this.criadoEm,
    required this.vendedorNome,
    required this.temperatura,
    required this.estagioJornada,
    required this.probabilidadeConversao,
    this.notaGeral,
    this.solicitadaPorNome,
    this.feedbackEntregueEm,
    this.indiceDificuldadeCliente,
    this.perfilCliente,
  });

  final int id;
  final DateTime? criadoEm;
  final String vendedorNome;
  final String temperatura;
  final String estagioJornada;
  final int? probabilidadeConversao;
  final double? notaGeral;

  /// Quem pediu a auditoria; nulo nas anteriores ao login.
  final String? solicitadaPorNome;
  final DateTime? feedbackEntregueEm;

  /// Nulos nas auditorias anteriores ao prompt v3 (spec 21).
  final double? indiceDificuldadeCliente;
  final String? perfilCliente;

  factory ResumoAuditoria.deJson(Map<String, dynamic> j) => ResumoAuditoria(
    id: inteiro(j['id']) ?? 0,
    criadoEm: data(j['criado_em']),
    vendedorNome: texto(j['vendedor_nome']),
    temperatura: texto(j['temperatura']),
    estagioJornada: texto(j['estagio_jornada']),
    probabilidadeConversao: inteiro(j['probabilidade_conversao']),
    notaGeral: decimal(j['nota_geral']),
    solicitadaPorNome: j['solicitada_por_nome'] as String?,
    feedbackEntregueEm: data(j['feedback_entregue_em']),
    indiceDificuldadeCliente: decimal(j['indice_dificuldade_cliente']),
    perfilCliente: j['perfil_cliente'] as String?,
  );
}

/// Auditoria completa (`GET /auditorias/{id}`).
class Auditoria {
  const Auditoria({
    required this.resumo,
    required this.leadId,
    required this.analise,
    required this.modelo,
    required this.promptVersao,
    required this.transcricoesPendentes,
    required this.observacaoGerente,
  });

  final ResumoAuditoria resumo;
  final int leadId;
  final AnaliseIA analise;
  final String modelo;
  final String promptVersao;
  final int transcricoesPendentes;
  final String observacaoGerente;

  int get id => resumo.id;

  factory Auditoria.deJson(Map<String, dynamic> j) => Auditoria(
    resumo: ResumoAuditoria.deJson(j),
    leadId: inteiro(j['lead_id']) ?? 0,
    analise: AnaliseIA.deJson(mapa(j['analise'])),
    modelo: texto(j['modelo']),
    promptVersao: texto(j['prompt_versao']),
    transcricoesPendentes: inteiro(j['transcricoes_pendentes']) ?? 0,
    observacaoGerente: texto(j['observacao_gerente']),
  );
}

/// Resposta de `POST /leads/{id}/auditar`, com o que vem nos headers.
class ResultadoAuditoria {
  const ResultadoAuditoria({
    required this.analise,
    required this.auditoriaId,
    required this.reutilizada,
    required this.transcricoesPendentes,
  });

  final AnaliseIA analise;

  /// `X-Auditoria-Id`.
  final int? auditoriaId;

  /// `X-Auditoria-Reutilizada`: não houve mensagem nova e a IA não foi chamada.
  final bool reutilizada;

  /// `X-Transcricoes-Pendentes`: áudios que ficaram de fora da análise.
  final int transcricoesPendentes;
}
