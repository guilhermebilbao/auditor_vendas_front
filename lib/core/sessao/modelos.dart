import '../api/pagina.dart';
import '../formatos.dart';

class Usuario {
  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.papel,
    required this.ativo,
    required this.senhaDefinida,
    this.ultimoLoginEm,
  });

  final int id;
  final String nome;
  final String email;
  final String papel;
  final bool ativo;

  /// `false` = convite ainda não aceito.
  final bool senhaDefinida;
  final DateTime? ultimoLoginEm;

  bool get admin => papel == 'admin';

  factory Usuario.deJson(Map<String, dynamic> j) => Usuario(
    id: inteiro(j['id']) ?? 0,
    nome: texto(j['nome']),
    email: texto(j['email']),
    papel: texto(j['papel']),
    ativo: j['ativo'] != false,
    senhaDefinida: j['senha_definida'] != false,
    ultimoLoginEm: data(j['ultimo_login_em']),
  );
}

/// Estados da loja (specs 19 e 20).
abstract final class EstadoLoja {
  static const aguardandoPagamento = 'aguardando_pagamento';
  static const emRevisao = 'em_revisao';
  static const ativa = 'ativa';
  static const suspensa = 'suspensa';
  static const cancelada = 'cancelada';
  static const trial = 'trial';
  static const trialEncerrado = 'trial_encerrado';
}

/// Chaves dos dias em `horario_comercial`, na ordem de exibição.
const diasDaSemana = ['seg', 'ter', 'qua', 'qui', 'sex', 'sab', 'dom'];

class Loja {
  const Loja({
    required this.id,
    required this.nome,
    required this.retencaoMeses,
    required this.slaRespostaMin,
    required this.horarioComercial,
    required this.pesosCriterios,
    this.maxInstancias,
    this.instanciasEmUso = 0,
    this.estado = EstadoLoja.ativa,
    this.inadimplenteDesde,
    this.trialAte,
  });

  final String id;
  final String nome;
  final int retencaoMeses;
  final int slaRespostaMin;

  /// Por dia (`dom`..`sab`), a lista de intervalos `[inicio, fim]` em `HH:MM`.
  final Map<String, List<List<String>>> horarioComercial;
  final Map<String, double> pesosCriterios;

  /// Quantos WhatsApps a loja pode conectar (definido pelo suporte, spec 17).
  /// `null` quando a API não informa.
  final int? maxInstancias;

  /// Instâncias que ocupam vaga: todas, menos `removida` e `erro`.
  final int instanciasEmUso;

  /// Estado da assinatura (spec 19). Diferente de `ativa`, o app mostra a tela
  /// de loja inativa; em `suspensa`, só a faixa de aviso.
  final String estado;

  /// Pagamento em atraso desde esta data; a loja é suspensa depois da carência.
  final DateTime? inadimplenteDesde;

  /// Fim do teste grátis (spec 20); `null` se a loja nunca teve trial.
  final DateTime? trialAte;

  bool get suspensa => estado == EstadoLoja.suspensa;

  /// No teste grátis: usa tudo, com cotas, até [trialAte].
  bool get emTrial => estado == EstadoLoja.trial;

  /// A loja não pode usar o app: pagamento pendente, em revisão ou teste
  /// grátis encerrado sem pagamento.
  bool get bloqueada =>
      estado == EstadoLoja.aguardandoPagamento ||
      estado == EstadoLoja.emRevisao ||
      estado == EstadoLoja.trialEncerrado;

  /// A loja chegou ao limite do plano e não pode conectar outro WhatsApp.
  bool get noLimiteDeInstancias =>
      maxInstancias != null && instanciasEmUso >= maxInstancias!;

  factory Loja.deJson(Map<String, dynamic> j) {
    final horario = <String, List<List<String>>>{};
    mapa(j['horario_comercial']).forEach((dia, intervalos) {
      if (intervalos is! List) return;
      horario[dia] = [
        for (final i in intervalos)
          if (i is List && i.length == 2) [i[0].toString(), i[1].toString()],
      ];
    });
    final pesos = <String, double>{};
    mapa(j['pesos_criterios']).forEach((criterio, peso) {
      if (peso is num) pesos[criterio] = peso.toDouble();
    });
    return Loja(
      id: texto(j['id']),
      nome: texto(j['nome']),
      retencaoMeses: inteiro(j['retencao_meses']) ?? 12,
      slaRespostaMin: inteiro(j['sla_resposta_min']) ?? 15,
      horarioComercial: horario,
      pesosCriterios: pesos,
      maxInstancias: inteiro(j['max_instancias']),
      instanciasEmUso: inteiro(j['instancias_em_uso']) ?? 0,
      // Backend sem a spec 19 não manda o estado: a loja está ativa.
      estado: texto(j['estado']).isEmpty
          ? EstadoLoja.ativa
          : texto(j['estado']),
      inadimplenteDesde: data(j['inadimplente_desde']),
      trialAte: data(j['trial_ate']),
    );
  }
}

/// Texto da faixa do teste grátis: dias que faltam até [fim], contados pelo
/// calendário da loja (spec 20, item 30).
String textoDiasDeTrial(DateTime fim, {DateTime? agora}) {
  final d = noFusoLoja(fim);
  final dias = DateTime(
    d.year,
    d.month,
    d.day,
  ).difference(hojeNaLoja(agora)).inDays;
  if (dias <= 0) return 'Último dia do teste grátis';
  return dias == 1
      ? 'Teste grátis: falta 1 dia'
      : 'Teste grátis: faltam $dias dias';
}

/// Resposta de `POST /auth/login` e `POST /auth/refresh`.
class Sessao {
  const Sessao({
    required this.accessToken,
    required this.refreshToken,
    required this.expiraEm,
    required this.usuario,
    required this.loja,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiraEm;
  final Usuario usuario;
  final Loja loja;

  factory Sessao.deJson(Map<String, dynamic> j) => Sessao(
    accessToken: texto(j['access_token']),
    refreshToken: texto(j['refresh_token']),
    expiraEm: data(j['expira_em']) ?? DateTime.now(),
    usuario: Usuario.deJson(mapa(j['usuario'])),
    loja: Loja.deJson(mapa(j['loja'])),
  );
}
