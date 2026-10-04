import 'dart:ui';

import 'package:flutter/material.dart';

typedef DestinoBarra = ({String rotulo, IconData icone, IconData iconeAtivo});

/// Barra de navegação inferior em forma de pílula flutuante, com efeito de
/// vidro: o conteúdo das abas passa por trás dela (`extendBody: true` na
/// [Casca]) e aparece desfocado dentro da pílula.
///
/// Controlada de fora: a [Casca] diz qual aba está ativa e decide o que
/// fazer com o toque.
class BarraPilula extends StatelessWidget {
  const BarraPilula({
    super.key,
    required this.destinos,
    required this.indiceAtual,
    required this.aoSelecionar,
  });

  final List<DestinoBarra> destinos;
  final int indiceAtual;
  final ValueChanged<int> aoSelecionar;

  static const _altura = 64.0;
  static const _margemInferior = 12.0;
  static const _raio = 32.0;

  /// Espaço que a barra ocupa por cima do conteúdo, a ser reservado no fim
  /// de toda lista rolável de uma aba; sem ele, os últimos itens ficam
  /// presos atrás da pílula. Fora da casca com a barra (telas de detalhe,
  /// desktop) vale zero, então telas compartilhadas podem chamar sem medo.
  ///
  /// Usa `viewPadding` e não `padding`: com `extendBody`, o Scaffold troca o
  /// `padding.bottom` do body pela altura da própria barra, e somá-lo aqui
  /// contaria a barra duas vezes. O `viewPadding` guarda só o inset real
  /// do sistema (gestos/botões do Android, home indicator do iOS).
  static double folgaInferior(BuildContext context) {
    if (context.dependOnInheritedWidgetOfExactType<EscopoBarraPilula>() ==
        null) {
      return 0;
    }
    return _alturaTotal(context);
  }

  static double _alturaTotal(BuildContext context) =>
      _altura + _margemInferior + MediaQuery.viewPaddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final insetSistema = MediaQuery.viewPaddingOf(context).bottom;

    return SizedBox(
      height: _alturaTotal(context),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, _margemInferior + insetSistema),
        // Duas camadas de propósito: esta só desenha a sombra e fica FORA
        // do clip (dentro dele a sombra seria cortada); a de baixo recorta
        // o blur no formato da pílula, senão o BackdropFilter desfocaria o
        // retângulo inteiro, inclusive a margem em volta.
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_raio),
            boxShadow: [
              BoxShadow(
                color: cores.shadow.withValues(alpha: escuro ? 0.4 : 0.15),
                blurRadius: 10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_raio),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // O vidro sai da superfície do tema: clara no modo claro,
                  // escura no escuro. No escuro fica mais opaco porque o
                  // blur sobre fundo escuro quase não aparece e o texto
                  // perderia contraste.
                  color: cores.surfaceContainer.withValues(
                    alpha: escuro ? 0.75 : 0.6,
                  ),
                  borderRadius: BorderRadius.circular(_raio),
                  border: Border.all(
                    color: cores.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                // Material transparente só para o efeito de toque: sem ele a
                // tinta seria pintada no Material do Scaffold, atrás do vidro.
                child: Material(
                  type: MaterialType.transparency,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, d) in destinos.indexed)
                        _Item(
                          destino: d,
                          ativo: i == indiceAtual,
                          aoTocar: () => aoSelecionar(i),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.destino,
    required this.ativo,
    required this.aoTocar,
  });

  final DestinoBarra destino;
  final bool ativo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cor = ativo
        ? tema.colorScheme.primary
        : tema.colorScheme.onSurfaceVariant;

    return Expanded(
      child: Semantics(
        button: true,
        selected: ativo,
        child: InkResponse(
          onTap: aoTocar,
          containedInkWell: true,
          customBorder: const StadiumBorder(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(ativo ? destino.iconeAtivo : destino.icone, color: cor),
              const SizedBox(height: 2),
              Text(
                destino.rotulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.labelSmall?.copyWith(
                  color: cor,
                  fontWeight: ativo ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marca a subárvore que fica atrás da [BarraPilula]; é o que faz
/// [BarraPilula.folgaInferior] valer zero fora dela.
class EscopoBarraPilula extends InheritedWidget {
  const EscopoBarraPilula({super.key, required super.child});

  @override
  bool updateShouldNotify(EscopoBarraPilula oldWidget) => false;
}
