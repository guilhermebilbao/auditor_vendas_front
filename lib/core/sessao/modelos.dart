import '../api/pagina.dart';

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
  });

  final String id;
  final String nome;
  final int retencaoMeses;
  final int slaRespostaMin;

  /// Por dia (`dom`..`sab`), a lista de intervalos `[inicio, fim]` em `HH:MM`.
  final Map<String, List<List<String>>> horarioComercial;
  final Map<String, double> pesosCriterios;

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
    );
  }
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
