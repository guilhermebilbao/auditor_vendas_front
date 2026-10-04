import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/pagina.dart';
import '../../core/sessao/modelos.dart';
import '../../core/sessao/sessao.dart';
import 'modelos.dart';

final adminRepoProvider = Provider<AdminRepo>((ref) {
  ref.watch(usuarioAtualProvider);
  return AdminRepo(ref.watch(clienteApiProvider));
});

/// `GET /vendedores`: também usado pelo gerente (filtro da lista de leads).
final vendedoresProvider = FutureProvider.autoDispose<List<Vendedor>>(
  (ref) => ref.watch(adminRepoProvider).vendedores(),
);

/// `GET /instancias/{id}`: status ao vivo. A consulta vai até a Evolution,
/// corrige o status e reaplica o webhook se preciso (spec 18, item 10).
final instanciaProvider = FutureProvider.autoDispose.family<Instancia, String>(
  (ref, id) => ref.watch(adminRepoProvider).buscarInstancia(id),
);

final usuariosProvider = FutureProvider.autoDispose<List<Usuario>>(
  (ref) => ref.watch(adminRepoProvider).usuarios(),
);

class AdminRepo {
  const AdminRepo(this._api);

  final ClienteApi _api;

  // Vendedores

  Future<List<Vendedor>> vendedores() async {
    final resposta = await _api.get('/vendedores');
    return Pagina.deJson(mapa(resposta.data), Vendedor.deJson).itens;
  }

  Future<Vendedor> buscarVendedor(int id) async =>
      Vendedor.deJson(mapa((await _api.get('/vendedores/$id')).data));

  Future<Vendedor> criarVendedor({
    required String nome,
    String telefone = '',
    String email = '',
  }) async {
    final resposta = await _api.post(
      '/vendedores',
      corpo: {
        'nome': nome,
        if (telefone.isNotEmpty) 'telefone': telefone,
        if (email.isNotEmpty) 'email': email,
      },
    );
    return Vendedor.deJson(mapa(resposta.data));
  }

  Future<Vendedor> editarVendedor(
    int id, {
    String? nome,
    String? telefone,
    String? email,
    bool? ativo,
  }) async {
    final resposta = await _api.patch(
      '/vendedores/$id',
      corpo: {
        'nome': ?nome,
        'telefone': ?telefone,
        'email': ?email,
        'ativo': ?ativo,
      },
    );
    return Vendedor.deJson(mapa(resposta.data));
  }

  /// `204`: apagado. `200` com o vendedor: tinha histórico e foi desativado.
  Future<ExclusaoVendedor> excluirVendedor(int id) async {
    final resposta = await _api.delete('/vendedores/$id');
    if (resposta.statusCode == 200 && resposta.data is Map) {
      return ExclusaoVendedor.desativado(Vendedor.deJson(mapa(resposta.data)));
    }
    return const ExclusaoVendedor.apagado();
  }

  // Instâncias (WhatsApp)

  Future<Instancia> criarInstancia(int vendedorId) async {
    final resposta = await _api.post(
      '/instancias',
      corpo: {'vendedor_id': vendedorId},
    );
    return Instancia.deJson(mapa(resposta.data));
  }

  /// Vai até a Evolution, corrige o status e reaplica o webhook se preciso.
  Future<Instancia> buscarInstancia(String id) async =>
      Instancia.deJson(mapa((await _api.get('/instancias/$id')).data));

  /// Imagem do QR code. A API devolve um data URI (`data:image/png;base64,…`).
  Future<Uint8List> qrCode(String instanciaId) async {
    final resposta = await _api.get('/instancias/$instanciaId/qrcode');
    final qr = texto(mapa(resposta.data)['qr_code']);
    return base64Decode(qr.substring(qr.indexOf(',') + 1));
  }

  Future<Instancia> reconectar(String instanciaId) async {
    final resposta = await _api.post('/instancias/$instanciaId/reconectar');
    return Instancia.deJson(mapa(resposta.data));
  }

  Future<void> removerInstancia(String instanciaId) =>
      _api.delete('/instancias/$instanciaId');

  // Usuários do painel

  Future<List<Usuario>> usuarios() async {
    final resposta = await _api.get('/usuarios');
    return Pagina.deJson(mapa(resposta.data), Usuario.deJson).itens;
  }

  Future<void> convidar({
    required String nome,
    required String email,
    required String papel,
  }) => _api.post(
    '/usuarios',
    corpo: {'nome': nome, 'email': email, 'papel': papel},
  );

  Future<void> reenviarConvite(int id) => _api.post('/usuarios/$id/convite');

  Future<void> editarUsuario(
    int id, {
    String? nome,
    String? papel,
    bool? ativo,
  }) => _api.patch(
    '/usuarios/$id',
    corpo: {'nome': ?nome, 'papel': ?papel, 'ativo': ?ativo},
  );

  Future<void> desativarUsuario(int id) => _api.delete('/usuarios/$id');

  // Loja

  /// `PATCH /loja`: devolve a loja atualizada.
  Future<Loja> salvarLoja({
    required String nome,
    required int slaRespostaMin,
    required int retencaoMeses,
    required Map<String, List<List<String>>> horarioComercial,
    required Map<String, double> pesosCriterios,
  }) async {
    final resposta = await _api.patch(
      '/loja',
      corpo: {
        'nome': nome,
        'sla_resposta_min': slaRespostaMin,
        'retencao_meses': retencaoMeses,
        'horario_comercial': horarioComercial,
        'pesos_criterios': pesosCriterios,
      },
    );
    return Loja.deJson(mapa(resposta.data));
  }
}
