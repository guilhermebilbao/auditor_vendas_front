import '../../core/api/pagina.dart';
import '../../core/formatos.dart';

class Distribuicao {
  const Distribuicao({this.mediaSeg, this.p50Seg, this.p90Seg});

  final int? mediaSeg;
  final int? p50Seg;
  final int? p90Seg;

  factory Distribuicao.deJson(Map<String, dynamic> j) => Distribuicao(
    mediaSeg: inteiro(j['media_seg']),
    p50Seg: inteiro(j['p50_seg']),
    p90Seg: inteiro(j['p90_seg']),
  );
}

/// Métricas de atendimento da loja inteira ou de um vendedor.
class MetricasGrupo {
  const MetricasGrupo({
    required this.vendedorNome,
    required this.leads,
    required this.respostas,
    required this.respostasForaSla,
    required this.tempoPrimeiraResposta,
    required this.tempoResposta,
    required this.leadsAguardandoResposta,
    this.vendedorId,
    this.percentualForaSla,
  });

  final int? vendedorId;
  final String vendedorNome;
  final int leads;
  final int respostas;
  final int respostasForaSla;
  final double? percentualForaSla;
  final Distribuicao tempoPrimeiraResposta;
  final Distribuicao tempoResposta;
  final int leadsAguardandoResposta;

  factory MetricasGrupo.deJson(Map<String, dynamic> j) => MetricasGrupo(
    vendedorId: inteiro(j['vendedor_id']),
    vendedorNome: texto(j['vendedor_nome']),
    leads: inteiro(j['leads']) ?? 0,
    respostas: inteiro(j['respostas']) ?? 0,
    respostasForaSla: inteiro(j['respostas_fora_sla']) ?? 0,
    percentualForaSla: decimal(j['percentual_fora_sla']),
    tempoPrimeiraResposta: Distribuicao.deJson(
      mapa(j['tempo_primeira_resposta']),
    ),
    tempoResposta: Distribuicao.deJson(mapa(j['tempo_resposta'])),
    leadsAguardandoResposta: inteiro(j['leads_aguardando_resposta']) ?? 0,
  );
}

class MetricasAgregadas {
  const MetricasAgregadas({
    required this.slaRespostaSeg,
    required this.total,
    required this.porVendedor,
  });

  final int slaRespostaSeg;
  final MetricasGrupo total;
  final List<MetricasGrupo> porVendedor;

  factory MetricasAgregadas.deJson(Map<String, dynamic> j) => MetricasAgregadas(
    slaRespostaSeg: inteiro(j['sla_resposta_seg']) ?? 0,
    total: MetricasGrupo.deJson(mapa(j['total'])),
    porVendedor: listaDeMapas(j['por_vendedor'])
        .map(MetricasGrupo.deJson)
        .toList(),
  );
}

Map<String, double?> _notasCriterios(dynamic v) => {
  for (final e in mapa(v).entries) e.key: decimal(e.value),
};

class ItemRanking {
  const ItemRanking({
    required this.vendedorId,
    required this.vendedorNome,
    required this.ativo,
    required this.leadsAuditados,
    required this.notasCriterios,
    this.posicao,
    this.notaMedia,
    this.probabilidadeMedia,
    this.atendimento,
  });

  /// Nula para quem não tem auditoria com nota no período.
  final int? posicao;
  final int vendedorId;
  final String vendedorNome;
  final bool ativo;
  final int leadsAuditados;
  final double? notaMedia;
  final Map<String, double?> notasCriterios;
  final double? probabilidadeMedia;
  final MetricasGrupo? atendimento;

  factory ItemRanking.deJson(Map<String, dynamic> j) => ItemRanking(
    posicao: inteiro(j['posicao']),
    vendedorId: inteiro(j['vendedor_id']) ?? 0,
    vendedorNome: texto(j['vendedor_nome']),
    ativo: j['ativo'] != false,
    leadsAuditados: inteiro(j['leads_auditados']) ?? 0,
    notaMedia: decimal(j['nota_media']),
    notasCriterios: _notasCriterios(j['notas_criterios']),
    probabilidadeMedia: decimal(j['probabilidade_media']),
    atendimento: j['atendimento'] is Map
        ? MetricasGrupo.deJson(mapa(j['atendimento']))
        : null,
  );
}

class PontoEvolucao {
  const PontoEvolucao({
    required this.inicio,
    required this.auditorias,
    required this.notasCriterios,
    this.notaMedia,
  });

  /// Primeiro dia da semana ou do mês (`AAAA-MM-DD`).
  final String inicio;
  final int auditorias;
  final double? notaMedia;
  final Map<String, double?> notasCriterios;

  factory PontoEvolucao.deJson(Map<String, dynamic> j) => PontoEvolucao(
    inicio: texto(j['inicio']),
    auditorias: inteiro(j['auditorias']) ?? 0,
    notaMedia: decimal(j['nota_media']),
    notasCriterios: _notasCriterios(j['notas_criterios']),
  );
}

class PontoMelhoria {
  const PontoMelhoria({
    required this.titulo,
    required this.descricao,
    required this.ocorrencias,
    required this.sugestao,
  });

  final String titulo;
  final String descricao;
  final int ocorrencias;
  final String sugestao;

  factory PontoMelhoria.deJson(Map<String, dynamic> j) => PontoMelhoria(
    titulo: texto(j['titulo']),
    descricao: texto(j['descricao']),
    ocorrencias: inteiro(j['ocorrencias']) ?? 0,
    sugestao: texto(j['sugestao']),
  );
}

class PontosMelhoria {
  const PontosMelhoria({
    required this.auditoriasConsideradas,
    required this.pontos,
    required this.doCache,
    this.geradoEm,
  });

  final int auditoriasConsideradas;
  final List<PontoMelhoria> pontos;
  final DateTime? geradoEm;

  /// Resultado salvo: não houve auditoria nova desde a última geração.
  final bool doCache;

  factory PontosMelhoria.deJson(Map<String, dynamic> j) => PontosMelhoria(
    auditoriasConsideradas: inteiro(j['auditorias_consideradas']) ?? 0,
    pontos: listaDeMapas(j['pontos']).map(PontoMelhoria.deJson).toList(),
    geradoEm: data(j['gerado_em']),
    doCache: j['do_cache'] == true,
  );
}

/// Período das telas de desempenho. Fica na URL: `?periodo=7d` ou
/// `?desde=AAAA-MM-DD&ate=AAAA-MM-DD`.
class Periodo {
  const Periodo(this.tipo, this.desde, this.ate);

  /// `hoje`, `7d`, `30d` ou `personalizado`.
  final String tipo;
  final String desde;
  final String ate;

  static const rotulos = {'hoje': 'Hoje', '7d': '7 dias', '30d': '30 dias'};

  factory Periodo.deTipo(String tipo, {DateTime? agora}) {
    final hoje = hojeNaLoja(agora);
    final dias = switch (tipo) {
      'hoje' => 0,
      '7d' => 6,
      _ => 29,
    };
    return Periodo(
      rotulos.containsKey(tipo) ? tipo : '30d',
      dataIso(hoje.subtract(Duration(days: dias))),
      dataIso(hoje),
    );
  }

  factory Periodo.daUrl(Map<String, String> q, {DateTime? agora}) {
    final desde = q['desde'] ?? '';
    final ate = q['ate'] ?? '';
    final formato = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (formato.hasMatch(desde) && formato.hasMatch(ate)) {
      return Periodo('personalizado', desde, ate);
    }
    return Periodo.deTipo(q['periodo'] ?? '30d', agora: agora);
  }

  Map<String, String> paraQuery() => tipo == 'personalizado'
      ? {'desde': desde, 'ate': ate}
      : {'periodo': tipo};

  String get rotulo {
    if (tipo != 'personalizado') return rotulos[tipo]!;
    String br(String iso) => iso.split('-').reversed.join('/');
    return '${br(desde)} a ${br(ate)}';
  }
}
