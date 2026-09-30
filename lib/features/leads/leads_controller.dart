import 'package:flutter/foundation.dart';

import 'leads_repo.dart';
import 'modelos.dart';

/// Lista de leads de um conjunto de filtros: primeira página, rolagem infinita
/// e atualização incremental (F03, itens 1 a 4).
class LeadsController extends ChangeNotifier {
  LeadsController(this._repo, this.filtros, {DateTime Function()? agora})
    : _agora = agora ?? DateTime.now;

  final LeadsRepo _repo;
  final FiltrosLeads filtros;
  final DateTime Function() _agora;

  List<Lead> itens = const [];
  bool carregando = true;
  bool carregandoMais = false;
  Object? erro;

  String? _cursor;
  DateTime? _ultimaConsulta;
  bool _descartado = false;

  bool get temMais => _cursor != null;

  Future<void> carregar() async {
    carregando = true;
    erro = null;
    _avisar();
    final inicio = _agora();
    try {
      final pagina = await _repo.listar(filtros);
      itens = pagina.itens;
      _cursor = pagina.proximoCursor;
      _ultimaConsulta = inicio;
    } catch (e) {
      erro = e;
    } finally {
      carregando = false;
      _avisar();
    }
  }

  Future<void> carregarMais() async {
    if (carregando || carregandoMais || _cursor == null) return;
    carregandoMais = true;
    _avisar();
    try {
      final pagina = await _repo.listar(filtros, cursor: _cursor);
      final conhecidos = {for (final l in itens) l.id};
      itens = [
        ...itens,
        ...pagina.itens.where((l) => !conhecidos.contains(l.id)),
      ];
      _cursor = pagina.proximoCursor;
    } finally {
      carregandoMais = false;
      _avisar();
    }
  }

  /// Busca só os leads que mudaram desde a última consulta e mescla na lista,
  /// sem recarregar tudo (F03, item 3).
  Future<void> atualizar() async {
    final desde = _ultimaConsulta;
    if (desde == null || carregando) return;
    final inicio = _agora();
    final pagina = await _repo.listar(
      filtros,
      limite: 200,
      // Margem para diferença de relógio com o servidor; a mescla é idempotente.
      atualizadosDesde: desde.subtract(const Duration(seconds: 5)),
    );
    _ultimaConsulta = inicio;
    if (pagina.itens.isEmpty) return;

    final porId = {for (final l in itens) l.id: l};
    for (final lead in pagina.itens) {
      porId[lead.id] = lead;
    }
    final epoca = DateTime.fromMillisecondsSinceEpoch(0);
    itens = porId.values.toList()
      ..sort((a, b) {
        final ordem = (b.ultimaMensagemEm ?? epoca).compareTo(
          a.ultimaMensagemEm ?? epoca,
        );
        return ordem != 0 ? ordem : b.id.compareTo(a.id);
      });
    _avisar();
  }

  void remover(int leadId) {
    itens = itens.where((l) => l.id != leadId).toList();
    _avisar();
  }

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
