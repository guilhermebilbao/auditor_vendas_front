/// Formato de toda lista da API: `{"itens": [...], "proximo_cursor": ... | null}`.
class Pagina<T> {
  const Pagina(this.itens, this.proximoCursor);

  final List<T> itens;
  final String? proximoCursor;

  bool get acabou => proximoCursor == null;

  factory Pagina.deJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) item,
  ) {
    final itens = (json['itens'] as List? ?? const [])
        .map((e) => item(Map<String, dynamic>.from(e as Map)))
        .toList();
    return Pagina(itens, json['proximo_cursor'] as String?);
  }
}

// Leitura tolerante dos campos do JSON, usada pelos modelos.
Map<String, dynamic> mapa(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> listaDeMapas(dynamic v) =>
    v is List ? v.map(mapa).toList() : const [];

List<String> listaDeTextos(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

DateTime? data(dynamic v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

double? decimal(dynamic v) => v is num ? v.toDouble() : null;

int? inteiro(dynamic v) => v is num ? v.toInt() : null;

String texto(dynamic v) => v?.toString() ?? '';
