import 'package:auditor_vendas_front/features/admin/boas_vindas.dart';
import 'package:auditor_vendas_front/features/leads/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Os mesmos casos do backend (api/boas_vindas_test.go): a prévia mostra o
  // que o cliente vai receber.
  group('texto da boas-vindas (spec 22)', () {
    String montar(String texto, String cliente) => montarBoasVindas(
      texto,
      cliente: cliente,
      vendedor: 'Ana Lima',
      loja: ' Loja Centro ',
    );

    test('troca as variáveis pelo primeiro nome', () {
      expect(
        montar(
          'Olá, {cliente}! Aqui é o {vendedor}, da {loja}.',
          'Maria Souza',
        ),
        'Olá, Maria! Aqui é o Ana, da Loja Centro.',
      );
    });

    test('sem nome do cliente, {cliente} some com a vírgula', () {
      expect(
        montar('Olá, {cliente}! Aqui é o {vendedor}, da {loja}.', ''),
        'Olá! Aqui é o Ana, da Loja Centro.',
      );
      expect(
        montar('{cliente}, tudo bem? Já te respondo.', '  '),
        'tudo bem? Já te respondo.',
      );
      expect(montar('Oi {cliente}!', ''), 'Oi!');
    });

    test('validação', () {
      expect(validarTextoBoasVindas('Olá, {cliente}!', ativa: true), isNull);
      expect(validarTextoBoasVindas('', ativa: false), isNull);
      expect(validarTextoBoasVindas('  ', ativa: true), isNotNull);
      expect(
        validarTextoBoasVindas('Olá, {nome}!', ativa: false),
        contains('{nome}'),
      );
      expect(validarTextoBoasVindas('a' * 501, ativa: false), isNotNull);
    });
  });

  test('filtro de contatos pessoais vai e volta pela URL', () {
    final f = FiltrosLeads.daUrl({'pessoais': 'true', 'q': 'ana'});
    expect(f.pessoais, isTrue);
    expect(f.paraQuery(), {'q': 'ana', 'pessoais': 'true'});
    expect(f.comBusca('bia').pessoais, isTrue);
    expect(FiltrosLeads.daUrl(f.paraQuery()), f);
  });

  test('lead pessoal marcado pela etiqueta', () {
    final lead = Lead.deJson({
      'id': 1,
      'pessoal': true,
      'pessoal_origem': 'etiqueta',
    });
    expect(lead.pessoal, isTrue);
    expect(lead.pessoalPorEtiqueta, isTrue);
    expect(Lead.deJson({'id': 2}).pessoal, isFalse);
  });
}
