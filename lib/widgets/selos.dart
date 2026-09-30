import 'package:flutter/material.dart';

import '../core/formatos.dart';

/// Selo colorido com texto: a cor nunca é a única informação (F07, item 5).
class Selo extends StatelessWidget {
  const Selo(this.texto, {super.key, required this.cor, this.icone});

  final String texto;
  final Color cor;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 13, color: cor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SeloTemperatura extends StatelessWidget {
  const SeloTemperatura(this.temperatura, {super.key});

  final String temperatura;

  @override
  Widget build(BuildContext context) {
    if (temperatura.isEmpty) {
      return const Selo('sem auditoria', cor: Colors.grey);
    }
    return Selo(
      temperatura,
      cor: corDaTemperatura(temperatura),
      icone: switch (temperatura) {
        'Quente' => Icons.local_fire_department,
        'Frio' => Icons.ac_unit,
        _ => Icons.thermostat,
      },
    );
  }
}

/// Nota de 0 a 10 com a cor da régua.
class NotaDestaque extends StatelessWidget {
  const NotaDestaque(this.nota, {super.key, this.tamanho = 22});

  final double? nota;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final cor = corDaNota(nota);
    return Container(
      constraints: BoxConstraints(minWidth: tamanho * 2.2),
      padding: EdgeInsets.symmetric(
        horizontal: tamanho * 0.4,
        vertical: tamanho * 0.2,
      ),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        formatarNota(nota),
        textAlign: TextAlign.center,
        semanticsLabel: nota == null
            ? 'sem nota'
            : 'nota ${formatarNota(nota)}',
        style: TextStyle(
          color: cor,
          fontSize: tamanho,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Barra horizontal de 0 a 10 para um critério; `null` aparece como "—".
class BarraNota extends StatelessWidget {
  const BarraNota({super.key, required this.rotulo, required this.nota});

  final String rotulo;
  final double? nota;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(rotulo, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (nota ?? 0) / 10,
                minHeight: 8,
                color: corDaNota(nota),
                backgroundColor: cores.surfaceContainerHighest,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              formatarNota(nota),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cartão de indicador do painel.
class CartaoIndicador extends StatelessWidget {
  const CartaoIndicador({
    super.key,
    required this.titulo,
    required this.valor,
    this.detalhe,
    this.cor,
    this.aoTocar,
  });

  final String titulo;
  final String valor;
  final String? detalhe;
  final Color? cor;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(titulo, style: tema.textTheme.labelMedium),
                  ),
                  if (aoTocar != null)
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: tema.colorScheme.outline,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                valor,
                style: tema.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cor,
                ),
              ),
              if (detalhe != null) ...[
                const SizedBox(height: 2),
                Text(detalhe!, style: tema.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Título de seção dentro de uma tela rolável.
class TituloSecao extends StatelessWidget {
  const TituloSecao(this.texto, {super.key, this.acao});

  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?acao,
        ],
      ),
    );
  }
}
