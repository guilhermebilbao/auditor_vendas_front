import 'package:flutter/material.dart';

import 'config.dart';

/// Converte um instante para o relógio da loja. O resultado é marcado como UTC
/// só para carregar os campos (dia, hora) já no fuso da loja.
DateTime noFusoLoja(DateTime instante) => instante.toUtc().add(fusoLoja);

String _dois(int n) => n.toString().padLeft(2, '0');

String formatarHora(DateTime instante) {
  final d = noFusoLoja(instante);
  return '${_dois(d.hour)}:${_dois(d.minute)}';
}

String formatarData(DateTime instante) {
  final d = noFusoLoja(instante);
  return '${_dois(d.day)}/${_dois(d.month)}/${d.year}';
}

/// `AAAA-MM-DD`, o formato dos filtros `desde` e `ate`.
String dataIso(DateTime dia) =>
    '${dia.year}-${_dois(dia.month)}-${_dois(dia.day)}';

/// Dia de calendário de hoje no fuso da loja.
DateTime hojeNaLoja([DateTime? agora]) {
  final d = noFusoLoja(agora ?? DateTime.now());
  return DateTime(d.year, d.month, d.day);
}

int _diasEntre(DateTime instante, DateTime agora) {
  final a = noFusoLoja(instante);
  final b = noFusoLoja(agora);
  return DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

const _diasAbreviados = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

/// Hoje: "14:32"; ontem: "ontem 14:32"; na semana: "seg 14:32"; antes:
/// "28/09/2026 14:32".
String formatarDataHora(DateTime? instante, {DateTime? agora}) {
  if (instante == null) return '—';
  final hora = formatarHora(instante);
  final dias = _diasEntre(instante, agora ?? DateTime.now());
  if (dias == 0) return hora;
  if (dias == 1) return 'ontem $hora';
  if (dias > 1 && dias < 7) {
    return '${_diasAbreviados[noFusoLoja(instante).weekday - 1]} $hora';
  }
  return '${formatarData(instante)} $hora';
}

/// Separador de dia da conversa: "Hoje", "Ontem" ou "28/09/2026".
String formatarDia(DateTime instante, {DateTime? agora}) {
  final dias = _diasEntre(instante, agora ?? DateTime.now());
  if (dias == 0) return 'Hoje';
  if (dias == 1) return 'Ontem';
  return formatarData(instante);
}

bool mesmoDiaNaLoja(DateTime a, DateTime b) => _diasEntre(a, b) == 0;

/// "agora", "há 5 min", "há 3 h", "há 2 dias".
String formatarRelativo(DateTime? instante, {DateTime? agora}) {
  if (instante == null) return '—';
  final passado = (agora ?? DateTime.now()).difference(instante);
  if (passado.inMinutes < 1) return 'agora';
  if (passado.inHours < 1) return 'há ${passado.inMinutes} min';
  if (passado.inDays < 1) return 'há ${passado.inHours} h';
  return passado.inDays == 1 ? 'há 1 dia' : 'há ${passado.inDays} dias';
}

/// Durações em segundos (`*_seg`), no mesmo formato do backend:
/// "menos de 1min", "12min", "2h45min", "3h", "1d3h".
String formatarDuracao(int? segundos) {
  if (segundos == null) return '—';
  final minutos = (segundos / 60).round();
  if (minutos < 1) return 'menos de 1min';
  if (minutos < 60) return '${minutos}min';
  final horas = minutos ~/ 60;
  if (horas < 24) {
    final resto = minutos % 60;
    return resto == 0 ? '${horas}h' : '${horas}h${_dois(resto)}min';
  }
  final dias = horas ~/ 24;
  final restoHoras = horas % 24;
  return restoHoras == 0 ? '${dias}d' : '${dias}d${restoHoras}h';
}

String _umaCasa(num valor) => valor.toStringAsFixed(1).replaceAll('.', ',');

/// Nota de 0 a 10 com vírgula decimal ("8,3"); `null` vira "—".
String formatarNota(double? nota) => nota == null ? '—' : _umaCasa(nota);

/// Variação entre duas notas: "↑ +1,5", "↓ -0,5" ou "= 0,0".
String formatarVariacao(double variacao) {
  if (variacao > 0) return '↑ +${_umaCasa(variacao)}';
  if (variacao < 0) return '↓ ${_umaCasa(variacao)}';
  return '= 0,0';
}

String formatarCriterio(int? nota) =>
    nota == null ? 'não avaliado' : '$nota/10';

String formatarProbabilidade(num? valor) =>
    valor == null ? '—' : '${valor.round()}%';

String formatarPercentual(double? valor) =>
    valor == null ? '—' : '${_umaCasa(valor)}%';

/// "5548999999999" → "+55 (48) 99999-9999".
String formatarTelefone(String telefone) {
  final d = telefone.replaceAll(RegExp(r'\D'), '');
  if (d.length != 12 && d.length != 13) return telefone;
  final numero = d.substring(4);
  final corte = numero.length - 4;
  return '+${d.substring(0, 2)} (${d.substring(2, 4)}) '
      '${numero.substring(0, corte)}-${numero.substring(corte)}';
}

/// Nome do cliente, ou o telefone quando o WhatsApp ainda não informou o nome.
String nomeDoCliente(String pushName, String telefone) {
  if (pushName.trim().isNotEmpty) return pushName.trim();
  if (telefone.isNotEmpty) return formatarTelefone(telefone);
  return 'Cliente sem nome';
}

/// Régua das notas: 0–3 vermelho, 4–6 âmbar, 7–8 verde, 9–10 verde-escuro.
Color corDaNota(double? nota) {
  if (nota == null) return Colors.grey;
  if (nota < 4) return const Color(0xFFD32F2F);
  if (nota < 7) return const Color(0xFFEF8F00);
  if (nota < 9) return const Color(0xFF43A047);
  return const Color(0xFF1B5E20);
}

Color corDaTemperatura(String temperatura) => switch (temperatura) {
  'Quente' => const Color(0xFFD32F2F),
  'Morno' => const Color(0xFFEF8F00),
  'Frio' => const Color(0xFF1976D2),
  _ => Colors.grey,
};

const corDentroDoSla = Color(0xFF43A047);
const corForaDoSla = Color(0xFFD32F2F);
const corAlerta = Color(0xFFEF8F00);

/// Os 6 critérios da avaliação do vendedor, na ordem de exibição.
const criterios = <String, String>{
  'agilidade': 'Agilidade',
  'rapport': 'Rapport',
  'qualificacao': 'Qualificação',
  'contorno_objecoes': 'Contorno de objeções',
  'conducao_fechamento': 'Condução ao fechamento',
  'comunicacao': 'Comunicação',
};
