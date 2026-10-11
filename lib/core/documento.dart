import 'package:flutter/services.dart';

/// Só os dígitos de um CPF ou CNPJ digitado com ou sem máscara.
String soDigitos(String texto) => texto.replaceAll(RegExp(r'\D'), '');

/// Confere os dígitos verificadores de um CPF (11 dígitos) ou CNPJ (14), como
/// o backend faz (spec 19, item 1). Não consulta a Receita.
bool documentoValido(String texto) {
  final d = soDigitos(texto);
  if (d.length != 11 && d.length != 14) return false;
  final n = [for (final c in d.split('')) int.parse(c)];
  if (n.every((x) => x == n.first)) return false;
  return d.length == 11 ? _cpfValido(n) : _cnpjValido(n);
}

bool _cpfValido(List<int> n) {
  for (final pos in [9, 10]) {
    var soma = 0;
    for (var i = 0; i < pos; i++) {
      soma += n[i] * (pos + 1 - i);
    }
    var dv = soma * 10 % 11;
    if (dv == 10) dv = 0;
    if (dv != n[pos]) return false;
  }
  return true;
}

bool _cnpjValido(List<int> n) {
  const pesos = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  for (final pos in [12, 13]) {
    var soma = 0;
    for (var i = 0; i < pos; i++) {
      soma += n[i] * pesos[pesos.length - pos + i];
    }
    final resto = soma % 11;
    if ((resto < 2 ? 0 : 11 - resto) != n[pos]) return false;
  }
  return true;
}

/// Máscara enquanto digita: 000.000.000-00 até 11 dígitos e
/// 00.000.000/0000-00 a partir do 12º.
String formatarDocumento(String texto) {
  final d = soDigitos(texto);
  final cnpj = d.length > 11;
  final separadores = cnpj
      ? const {2: '.', 5: '.', 8: '/', 12: '-'}
      : const {3: '.', 6: '.', 9: '-'};
  final saida = StringBuffer();
  for (var i = 0; i < d.length && i < 14; i++) {
    final sep = separadores[i];
    if (sep != null) saida.write(sep);
    saida.write(d[i]);
  }
  return saida.toString();
}

class MascaraDocumento extends TextInputFormatter {
  const MascaraDocumento();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue atual,
  ) {
    final texto = formatarDocumento(atual.text);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
