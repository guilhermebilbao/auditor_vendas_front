import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Onde o refresh token fica guardado (F01, item 3). O token de acesso fica só
/// em memória.
abstract class ArmazenamentoToken {
  Future<String?> ler();
  Future<void> gravar(String refreshToken);
  Future<void> apagar();
}

class ArmazenamentoSeguro implements ArmazenamentoToken {
  const ArmazenamentoSeguro([this._storage = const FlutterSecureStorage()]);

  static const _chave = 'refresh_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> ler() async {
    try {
      return await _storage.read(key: _chave);
    } catch (_) {
      // Cofre ilegível (ex.: backup restaurado em outro aparelho): pede login.
      await apagar();
      return null;
    }
  }

  @override
  Future<void> gravar(String refreshToken) =>
      _storage.write(key: _chave, value: refreshToken);

  @override
  Future<void> apagar() async {
    try {
      await _storage.delete(key: _chave);
    } catch (_) {}
  }
}

class ArmazenamentoMemoria implements ArmazenamentoToken {
  ArmazenamentoMemoria([this.valor]);

  String? valor;

  @override
  Future<String?> ler() async => valor;

  @override
  Future<void> gravar(String refreshToken) async => valor = refreshToken;

  @override
  Future<void> apagar() async => valor = null;
}
