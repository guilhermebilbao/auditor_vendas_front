import 'package:auditor_vendas_front/core/formatos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('durações no mesmo formato do backend', () {
    const casos = {
      20: 'menos de 1min',
      12 * 60: '12min',
      2 * 3600 + 45 * 60: '2h45min',
      2 * 3600 + 5 * 60: '2h05min',
      3 * 3600: '3h',
      27 * 3600: '1d3h',
      48 * 3600: '2d',
    };
    casos.forEach((segundos, esperado) {
      expect(formatarDuracao(segundos), esperado, reason: '$segundos s');
    });
    expect(formatarDuracao(null), '—');
  });

  test('data e hora no fuso da loja, qualquer que seja o fuso do aparelho', () {
    // Quarta-feira, 30/09/2026, 15:00 em São Paulo.
    final agora = DateTime.parse('2026-09-30T15:00:00-03:00');
    String f(String iso) => formatarDataHora(DateTime.parse(iso), agora: agora);

    expect(f('2026-09-30T14:32:00-03:00'), '14:32');
    expect(f('2026-09-30T17:32:00Z'), '14:32');
    expect(f('2026-09-29T14:32:00-03:00'), 'ontem 14:32');
    expect(f('2026-09-28T14:32:00-03:00'), 'seg 14:32');
    expect(f('2026-09-20T14:32:00-03:00'), '20/09/2026 14:32');
    // 01:30 UTC de hoje ainda é ontem à noite na loja.
    expect(f('2026-09-30T01:30:00Z'), 'ontem 22:30');
    expect(formatarDataHora(null), '—');
  });

  test('separador de dia da conversa', () {
    final agora = DateTime.parse('2026-09-30T15:00:00-03:00');
    String f(String iso) => formatarDia(DateTime.parse(iso), agora: agora);
    expect(f('2026-09-30T08:00:00-03:00'), 'Hoje');
    expect(f('2026-09-29T23:59:00-03:00'), 'Ontem');
    expect(f('2026-09-28T10:00:00-03:00'), '28/09/2026');
  });

  test('tempo relativo', () {
    final agora = DateTime.parse('2026-09-30T15:00:00-03:00');
    String f(Duration d) => formatarRelativo(agora.subtract(d), agora: agora);
    expect(f(const Duration(seconds: 20)), 'agora');
    expect(f(const Duration(minutes: 5)), 'há 5 min');
    expect(f(const Duration(hours: 3)), 'há 3 h');
    expect(f(const Duration(days: 1)), 'há 1 dia');
    expect(f(const Duration(days: 2)), 'há 2 dias');
  });

  test('notas, critérios e percentuais', () {
    expect(formatarNota(8.3), '8,3');
    expect(formatarNota(10), '10,0');
    expect(formatarNota(null), '—');
    expect(formatarCriterio(9), '9/10');
    expect(formatarCriterio(null), 'não avaliado');
    expect(formatarProbabilidade(75), '75%');
    expect(formatarPercentual(12.5), '12,5%');
    expect(formatarPercentual(null), '—');
    expect(formatarVariacao(1.5), '↑ +1,5');
    expect(formatarVariacao(-0.5), '↓ -0,5');
  });

  test('régua de cores da nota', () {
    expect(corDaNota(3), corDaNota(0));
    expect(corDaNota(3.9), corDaNota(0));
    expect(corDaNota(4), corDaNota(6.9));
    expect(corDaNota(7), corDaNota(8.9));
    expect(corDaNota(9), corDaNota(10));
    expect({
      corDaNota(0),
      corDaNota(5),
      corDaNota(8),
      corDaNota(10),
      corDaNota(null),
    }, hasLength(5));
  });

  test('telefone', () {
    expect(formatarTelefone('5548999999999'), '+55 (48) 99999-9999');
    expect(formatarTelefone('554833334444'), '+55 (48) 3333-4444');
    expect(formatarTelefone('123'), '123');
  });

  test('nome do cliente: sem nome no WhatsApp, mostra o telefone', () {
    expect(nomeDoCliente('Maria', '5548999999999'), 'Maria');
    expect(nomeDoCliente('', '5548999999999'), '+55 (48) 99999-9999');
    expect(nomeDoCliente('  ', ''), 'Cliente sem nome');
  });
}
