import '../../core/api/pagina.dart';
import '../../core/formatos.dart';
import '../auditoria/modelos.dart';

class Lead {
  const Lead({
    required this.id,
    required this.vendedorId,
    required this.vendedorNome,
    required this.telefone,
    required this.pushName,
    required this.temperatura,
    required this.ultimaMensagemEm,
    required this.ultimaMensagem,
    required this.aguardandoResposta,
    required this.totalMensagens,
    this.probabilidadeConversao,
  });

  final int id;
  final int vendedorId;
  final String vendedorNome;
  final String telefone;
  final String pushName;

  /// Da última auditoria: `Quente`, `Morno`, `Frio` ou vazio.
  final String temperatura;
  final DateTime? ultimaMensagemEm;

  /// Prévia que o backend já corta em 120 caracteres.
  final String ultimaMensagem;
  final bool aguardandoResposta;
  final int totalMensagens;
  final int? probabilidadeConversao;

  String get nome => nomeDoCliente(pushName, telefone);

  factory Lead.deJson(Map<String, dynamic> j) => Lead(
    id: inteiro(j['id']) ?? 0,
    vendedorId: inteiro(j['vendedor_id']) ?? 0,
    vendedorNome: texto(j['vendedor_nome']),
    telefone: texto(j['telefone']),
    pushName: texto(j['push_name']),
    temperatura: texto(j['temperatura']),
    ultimaMensagemEm: data(j['ultima_mensagem_em']),
    ultimaMensagem: texto(j['ultima_mensagem']),
    aguardandoResposta: j['aguardando_resposta'] == true,
    totalMensagens: inteiro(j['total_mensagens']) ?? 0,
    probabilidadeConversao: inteiro(j['probabilidade_conversao']),
  );
}

/// O mesmo cliente negociando com outro vendedor da loja.
class OutroLead {
  const OutroLead({
    required this.id,
    required this.vendedorId,
    required this.vendedorNome,
  });

  final int id;
  final int vendedorId;
  final String vendedorNome;

  factory OutroLead.deJson(Map<String, dynamic> j) => OutroLead(
    id: inteiro(j['id']) ?? 0,
    vendedorId: inteiro(j['vendedor_id']) ?? 0,
    vendedorNome: texto(j['vendedor_nome']),
  );
}

class LeadDetalhe {
  const LeadDetalhe({
    required this.lead,
    required this.outrosLeads,
    this.ultimaAuditoria,
  });

  final Lead lead;
  final ResumoAuditoria? ultimaAuditoria;
  final List<OutroLead> outrosLeads;

  factory LeadDetalhe.deJson(Map<String, dynamic> j) => LeadDetalhe(
    lead: Lead.deJson(j),
    ultimaAuditoria: j['ultima_auditoria'] is Map
        ? ResumoAuditoria.deJson(mapa(j['ultima_auditoria']))
        : null,
    outrosLeads: listaDeMapas(j['outros_leads_mesmo_contato'])
        .map(OutroLead.deJson)
        .toList(),
  );
}

class Mensagem {
  const Mensagem({
    required this.id,
    required this.autor,
    required this.tipo,
    required this.conteudo,
    required this.transcricao,
    required this.enviadaEm,
    this.vendedor,
    this.statusTranscricao,
  });

  final int id;

  /// `lead` ou `vendedor`.
  final String autor;
  final String? vendedor;

  /// `texto`, `audio` ou `midia`.
  final String tipo;
  final String conteudo;

  /// O conteúdo é a transcrição de um áudio.
  final bool transcricao;

  /// Só em áudios: `pendente`, `concluida` ou `falhou`.
  final String? statusTranscricao;
  final DateTime enviadaEm;

  bool get doVendedor => autor == 'vendedor';
  bool get audioPendente => statusTranscricao == 'pendente';
  bool get audioFalhou => statusTranscricao == 'falhou';
  bool get audioTranscrito => tipo == 'audio' && transcricao;
  bool get midiaSemConteudo => tipo == 'midia' && conteudo.isEmpty;

  factory Mensagem.deJson(Map<String, dynamic> j) => Mensagem(
    id: inteiro(j['id']) ?? 0,
    autor: texto(j['autor']),
    vendedor: j['vendedor'] as String?,
    tipo: texto(j['tipo']),
    conteudo: texto(j['conteudo']),
    transcricao: j['transcricao'] == true,
    statusTranscricao: j['status_transcricao'] as String?,
    enviadaEm: data(j['enviada_em']) ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class PaginaMensagens {
  const PaginaMensagens({
    required this.itens,
    this.proximoCursor,
    this.ultimoCursor,
  });

  final List<Mensagem> itens;

  /// Para `?antes=`: carrega as mais antigas. Nulo = início da conversa.
  final String? proximoCursor;

  /// Para `?depois=`: busca só as novas.
  final String? ultimoCursor;

  factory PaginaMensagens.deJson(Map<String, dynamic> j) => PaginaMensagens(
    itens: listaDeMapas(j['itens']).map(Mensagem.deJson).toList(),
    proximoCursor: j['proximo_cursor'] as String?,
    ultimoCursor: j['ultimo_cursor'] as String?,
  );
}

/// Tempos em segundos, contados só no horário comercial da loja.
class MetricasLead {
  const MetricasLead({
    required this.respostas,
    required this.respostasForaSla,
    required this.aguardandoResposta,
    required this.vendedorFezFollowup,
    required this.slaRespostaSeg,
    required this.totalMensagensLead,
    required this.totalMensagensVendedor,
    this.tempoPrimeiraRespostaSeg,
    this.tempoMedioRespostaSeg,
    this.tempoMaxRespostaSeg,
    this.tempoSemRespostaSeg,
  });

  final int? tempoPrimeiraRespostaSeg;
  final int? tempoMedioRespostaSeg;
  final int? tempoMaxRespostaSeg;
  final int respostas;
  final int respostasForaSla;
  final bool aguardandoResposta;
  final int? tempoSemRespostaSeg;
  final int totalMensagensLead;
  final int totalMensagensVendedor;
  final bool vendedorFezFollowup;
  final int slaRespostaSeg;

  factory MetricasLead.deJson(Map<String, dynamic> j) => MetricasLead(
    tempoPrimeiraRespostaSeg: inteiro(j['tempo_primeira_resposta_seg']),
    tempoMedioRespostaSeg: inteiro(j['tempo_medio_resposta_seg']),
    tempoMaxRespostaSeg: inteiro(j['tempo_max_resposta_seg']),
    respostas: inteiro(j['respostas']) ?? 0,
    respostasForaSla: inteiro(j['respostas_fora_sla']) ?? 0,
    aguardandoResposta: j['aguardando_resposta'] == true,
    tempoSemRespostaSeg: inteiro(j['tempo_sem_resposta_seg']),
    totalMensagensLead: inteiro(j['total_mensagens_lead']) ?? 0,
    totalMensagensVendedor: inteiro(j['total_mensagens_vendedor']) ?? 0,
    vendedorFezFollowup: j['vendedor_fez_followup'] == true,
    slaRespostaSeg: inteiro(j['sla_resposta_seg']) ?? 0,
  );
}

/// Filtros da lista de leads. Ficam na URL (`/leads?temperatura=Quente&q=...`).
class FiltrosLeads {
  const FiltrosLeads({
    this.q = '',
    this.vendedorId,
    this.temperatura = '',
    this.desde = '',
    this.ate = '',
    this.aguardandoResposta = false,
    this.haMaisDe = '',
  });

  final String q;
  final int? vendedorId;

  /// `Quente`, `Morno`, `Frio` ou `sem_auditoria`.
  final String temperatura;
  final String desde;
  final String ate;
  final bool aguardandoResposta;

  /// `30m`, `2h` ou `1d`: sem resposta há mais que isso (tempo corrido).
  final String haMaisDe;

  factory FiltrosLeads.daUrl(Map<String, String> q) => FiltrosLeads(
    q: q['q'] ?? '',
    vendedorId: int.tryParse(q['vendedor_id'] ?? ''),
    temperatura: q['temperatura'] ?? '',
    desde: q['desde'] ?? '',
    ate: q['ate'] ?? '',
    aguardandoResposta: q['aguardando_resposta'] == 'true',
    haMaisDe: q['ha_mais_de'] ?? '',
  );

  /// Parâmetros para a URL do app e para `GET /leads`.
  Map<String, String> paraQuery() => {
    if (q.isNotEmpty) 'q': q,
    if (vendedorId != null) 'vendedor_id': '$vendedorId',
    if (temperatura.isNotEmpty) 'temperatura': temperatura,
    if (desde.isNotEmpty) 'desde': desde,
    if (ate.isNotEmpty) 'ate': ate,
    if (aguardandoResposta) 'aguardando_resposta': 'true',
    if (haMaisDe.isNotEmpty) 'ha_mais_de': haMaisDe,
  };

  String paraRota() =>
      Uri(path: '/leads', queryParameters: _ouNulo(paraQuery())).toString();

  static Map<String, String>? _ouNulo(Map<String, String> m) =>
      m.isEmpty ? null : m;

  bool get vazio => paraQuery().isEmpty;

  /// Quantos filtros além da busca e dos atalhos estão ligados.
  int get avancados =>
      (vendedorId != null ? 1 : 0) +
      (desde.isNotEmpty || ate.isNotEmpty ? 1 : 0) +
      (temperatura.isNotEmpty && temperatura != 'sem_auditoria' ? 1 : 0) +
      (haMaisDe.isNotEmpty && haMaisDe != '2h' ? 1 : 0);

  FiltrosLeads comBusca(String busca) => FiltrosLeads(
    q: busca,
    vendedorId: vendedorId,
    temperatura: temperatura,
    desde: desde,
    ate: ate,
    aguardandoResposta: aguardandoResposta,
    haMaisDe: haMaisDe,
  );

  @override
  bool operator ==(Object other) =>
      other is FiltrosLeads &&
      other.q == q &&
      other.vendedorId == vendedorId &&
      other.temperatura == temperatura &&
      other.desde == desde &&
      other.ate == ate &&
      other.aguardandoResposta == aguardandoResposta &&
      other.haMaisDe == haMaisDe;

  @override
  int get hashCode => Object.hash(
    q,
    vendedorId,
    temperatura,
    desde,
    ate,
    aguardandoResposta,
    haMaisDe,
  );
}
