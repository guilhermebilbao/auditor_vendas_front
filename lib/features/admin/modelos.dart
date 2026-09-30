import '../../core/api/pagina.dart';

/// Instância ativa de um vendedor, como vem dentro de `Vendedor`.
class InstanciaResumo {
  const InstanciaResumo({
    required this.id,
    required this.status,
    required this.telefone,
  });

  final String id;
  final String status;
  final String telefone;

  factory InstanciaResumo.deJson(Map<String, dynamic> j) => InstanciaResumo(
    id: texto(j['id']),
    status: texto(j['status']),
    telefone: texto(j['telefone']),
  );
}

class Vendedor {
  const Vendedor({
    required this.id,
    required this.nome,
    required this.telefone,
    required this.email,
    required this.ativo,
    this.instancia,
  });

  final int id;
  final String nome;
  final String telefone;
  final String email;
  final bool ativo;
  final InstanciaResumo? instancia;

  factory Vendedor.deJson(Map<String, dynamic> j) => Vendedor(
    id: inteiro(j['id']) ?? 0,
    nome: texto(j['nome']),
    telefone: texto(j['telefone']),
    email: texto(j['email']),
    ativo: j['ativo'] != false,
    instancia: j['instancia'] is Map
        ? InstanciaResumo.deJson(mapa(j['instancia']))
        : null,
  );
}

class Instancia {
  const Instancia({
    required this.id,
    required this.vendedorId,
    required this.vendedorNome,
    required this.status,
    required this.telefone,
    this.ultimoErro,
  });

  final String id;
  final int vendedorId;
  final String vendedorNome;

  /// `criada`, `aguardando_qr`, `conectada`, `desconectada`, `erro` ou `removida`.
  final String status;
  final String telefone;
  final String? ultimoErro;

  factory Instancia.deJson(Map<String, dynamic> j) => Instancia(
    id: texto(j['id']),
    vendedorId: inteiro(j['vendedor_id']) ?? 0,
    vendedorNome: texto(j['vendedor_nome']),
    status: texto(j['status']),
    telefone: texto(j['telefone']),
    ultimoErro: j['ultimo_erro'] as String?,
  );
}

/// Resultado de `DELETE /vendedores/{id}` (F06, item 6).
class ExclusaoVendedor {
  const ExclusaoVendedor.apagado() : desativado = null;
  const ExclusaoVendedor.desativado(Vendedor this.desativado);

  /// Preenchido quando o vendedor tinha histórico e foi só desativado.
  final Vendedor? desativado;
}
