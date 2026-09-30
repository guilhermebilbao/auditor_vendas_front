import 'package:flutter/foundation.dart';

import '../leads/leads_repo.dart';
import '../leads/modelos.dart';

/// Conversa de um lead (F03, itens 7 a 11).
///
/// Só [abrir] carrega a primeira página, que o backend registra como leitura
/// (LGPD). As atualizações usam `?depois=` e `?ids=`, que não geram registro.
class ConversaController extends ChangeNotifier {
  ConversaController(this._repo, this.leadId);

  final LeadsRepo _repo;
  final int leadId;

  /// Em ordem cronológica (a mais antiga primeiro).
  List<Mensagem> mensagens = const [];
  bool carregando = true;
  bool carregandoHistorico = false;
  Object? erro;

  /// A tela avisa se o usuário está no fim da conversa. Fora do fim, as
  /// mensagens novas ficam retidas até ele pedir ("↓ N novas").
  bool noFim = true;

  final List<Mensagem> _retidas = [];
  String? _proximoCursor;
  String? _ultimoCursor;
  bool _descartado = false;

  int get novasRetidas => _retidas.length;

  /// Não há mensagens mais antigas para carregar.
  bool get chegouAoInicio =>
      !carregando && erro == null && _proximoCursor == null;

  Future<void> abrir() async {
    carregando = true;
    erro = null;
    _avisar();
    try {
      final pagina = await _repo.mensagens(leadId, limite: 100);
      mensagens = _ordenar(pagina.itens);
      _proximoCursor = pagina.proximoCursor;
      _ultimoCursor = pagina.ultimoCursor;
    } catch (e) {
      erro = e;
    } finally {
      carregando = false;
      _avisar();
    }
  }

  /// Mensagens mais antigas, ao rolar até o topo.
  Future<void> carregarHistorico() async {
    final cursor = _proximoCursor;
    if (cursor == null || carregando || carregandoHistorico) return;
    carregandoHistorico = true;
    _avisar();
    try {
      final pagina = await _repo.mensagens(leadId, limite: 100, antes: cursor);
      _proximoCursor = pagina.proximoCursor;
      mensagens = _mesclar(mensagens, pagina.itens);
    } finally {
      carregandoHistorico = false;
      _avisar();
    }
  }

  /// Só as mensagens que chegaram depois do último cursor. Devolve `true` se
  /// chegou alguma.
  Future<bool> buscarNovas() async {
    final cursor = _ultimoCursor;
    if (cursor == null || carregando) return false;
    final pagina = await _repo.mensagens(leadId, depois: cursor);
    _ultimoCursor = pagina.ultimoCursor ?? cursor;
    if (pagina.itens.isEmpty) return false;

    if (noFim) {
      // Cada uma entra na posição do seu horário: uma mensagem pode chegar
      // atrasada, com horário antigo.
      mensagens = _mesclar(mensagens, pagina.itens);
    } else {
      final conhecidas = {for (final m in _retidas) m.id};
      _retidas.addAll(pagina.itens.where((m) => !conhecidas.contains(m.id)));
    }
    _avisar();
    return true;
  }

  /// Busca de novo os áudios que ainda estavam sendo transcritos.
  Future<void> atualizarPendentes() async {
    final ids = [
      for (final m in [...mensagens, ..._retidas])
        if (m.audioPendente) m.id,
    ].take(100).toList();
    if (ids.isEmpty) return;

    final pagina = await _repo.mensagens(leadId, ids: ids);
    final novas = {for (final m in pagina.itens) m.id: m};
    if (novas.isEmpty) return;
    mensagens = [for (final m in mensagens) novas[m.id] ?? m];
    for (var i = 0; i < _retidas.length; i++) {
      _retidas[i] = novas[_retidas[i].id] ?? _retidas[i];
    }
    _avisar();
  }

  void mostrarRetidas() {
    if (_retidas.isEmpty) return;
    mensagens = _mesclar(mensagens, _retidas);
    _retidas.clear();
    _avisar();
  }

  void marcarNoFim(bool valor) {
    if (noFim == valor) return;
    noFim = valor;
    if (valor) mostrarRetidas();
  }

  static List<Mensagem> _mesclar(List<Mensagem> atuais, List<Mensagem> novas) {
    final porId = {for (final m in atuais) m.id: m};
    for (final m in novas) {
      porId[m.id] = m;
    }
    return _ordenar(porId.values.toList());
  }

  static List<Mensagem> _ordenar(List<Mensagem> lista) => lista
    ..sort((a, b) {
      final ordem = a.enviadaEm.compareTo(b.enviadaEm);
      return ordem != 0 ? ordem : a.id.compareTo(b.id);
    });

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
