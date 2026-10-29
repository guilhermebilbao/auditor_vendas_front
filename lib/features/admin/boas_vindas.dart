/// Texto da boas-vindas automática (spec 22). Mesmas regras do backend
/// (`api/boas_vindas.go`), para a prévia mostrar o que o cliente vai receber.
library;

/// Variáveis aceitas no texto.
const variaveisBoasVindas = ['{cliente}', '{vendedor}', '{loja}'];

const tamanhoMaxBoasVindas = 500;

final _variavel = RegExp(r'\{[^{}]*\}');
final _semCliente = RegExp(r'[ \t]*,?[ \t]*\{cliente\}');

/// Confere tamanho e variáveis. Devolve o problema ou `null`.
String? validarTextoBoasVindas(String texto, {required bool ativa}) {
  final t = texto.trim();
  if (ativa && t.isEmpty) return 'Escreva o texto antes de ligar.';
  if (t.runes.length > tamanhoMaxBoasVindas) {
    return 'Use no máximo $tamanhoMaxBoasVindas caracteres.';
  }
  for (final m in _variavel.allMatches(t)) {
    if (!variaveisBoasVindas.contains(m.group(0))) {
      return '${m.group(0)} não existe. Use {cliente}, {vendedor} ou {loja}.';
    }
  }
  return null;
}

/// Troca as variáveis. Sem nome do cliente, "{cliente}" some junto com a
/// vírgula e o espaço antes dele ("Olá, {cliente}!" vira "Olá!").
String montarBoasVindas(
  String texto, {
  required String cliente,
  required String vendedor,
  required String loja,
}) {
  final nomeCliente = _primeiroNome(cliente);
  var t = texto;
  if (nomeCliente.isEmpty) {
    t = t.replaceAll(_semCliente, '').replaceFirst(RegExp(r'^[ ,]+'), '');
  }
  return t
      .replaceAll('{cliente}', nomeCliente)
      .replaceAll('{vendedor}', _primeiroNome(vendedor))
      .replaceAll('{loja}', loja.trim())
      .trim();
}

String _primeiroNome(String nome) {
  final partes = nome.trim().split(RegExp(r'\s+'));
  return partes.first;
}
