import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

typedef DestinoBarra = ({String rotulo, IconData icone, IconData iconeAtivo});

/// Barra de navegação inferior em forma de pílula flutuante, com efeito de
/// vidro: o conteúdo das abas passa por trás dela (`extendBody: true` na
/// [Casca]) e aparece desfocado dentro da pílula.
///
/// Controlada de fora: a [Casca] diz qual aba está ativa e decide o que
/// fazer com o toque.
///
/// A troca de aba anima no estilo do iOS: uma cápsula desliza em mola até o
/// item tocado e o ícone dá um "bounce"; o conteúdo troca na hora, como no
/// UITabBarController.
class BarraPilula extends StatefulWidget {
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
  State<BarraPilula> createState() => _BarraPilulaState();
}

/// Molas no formato do SwiftUI (duração percebida + quanto "quica"): é a
/// mesma descrição que o iOS usa, então o movimento fica com a cara dele.
final _molaCapsula = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 450),
  bounce: 0.2,
);
final _molaIcone = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 400),
  bounce: 0.5,
);

class _BarraPilulaState extends State<BarraPilula>
    with SingleTickerProviderStateMixin {
  // Posição da cápsula em "índices" (1.5 = entre o segundo e o terceiro
  // item). Sem limites porque a mola passa um pouco do alvo antes de parar.
  late final _posicao = AnimationController.unbounded(
    vsync: this,
    value: widget.indiceAtual.toDouble(),
  );

  @override
  void didUpdateWidget(BarraPilula antiga) {
    super.didUpdateWidget(antiga);
    if (widget.indiceAtual == antiga.indiceAtual) return;
    final alvo = widget.indiceAtual.toDouble();
    if (MediaQuery.disableAnimationsOf(context)) {
      _posicao.value = alvo;
      return;
    }
    // Parte da posição e da velocidade atuais: tocar em outra aba no meio
    // do movimento redireciona a cápsula sem tranco, como no iOS.
    _posicao.animateWith(
      SpringSimulation(_molaCapsula, _posicao.value, alvo, _posicao.velocity),
    );
  }

  @override
  void dispose() {
    _posicao.dispose();
    super.dispose();
  }

  void _tocar(int i) {
    if (i != widget.indiceAtual) HapticFeedback.selectionClick();
    widget.aoSelecionar(i);
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final insetSistema = MediaQuery.viewPaddingOf(context).bottom;

    return SizedBox(
      height: BarraPilula._alturaTotal(context),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          BarraPilula._margemInferior + insetSistema,
        ),
        // Duas camadas de propósito: esta só desenha a sombra e fica FORA
        // do clip (dentro dele a sombra seria cortada); a de baixo recorta
        // o blur no formato da pílula, senão o BackdropFilter desfocaria o
        // retângulo inteiro, inclusive a margem em volta.
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BarraPilula._raio),
            boxShadow: [
              BoxShadow(
                color: cores.shadow.withValues(alpha: escuro ? 0.4 : 0.15),
                blurRadius: 10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BarraPilula._raio),
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
                  borderRadius: BorderRadius.circular(BarraPilula._raio),
                  border: Border.all(
                    color: cores.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, limites) {
                    final n = widget.destinos.length;
                    final largura = limites.maxWidth / n;
                    return Stack(
                      children: [
                        AnimatedBuilder(
                          animation: _posicao,
                          builder: (context, _) => Positioned(
                            // Mantida dentro da pílula mesmo quando a mola
                            // passa do alvo no primeiro ou no último item.
                            left: _posicao.value.clamp(0, n - 1) * largura,
                            top: 0,
                            bottom: 0,
                            width: largura,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: DecoratedBox(
                                decoration: ShapeDecoration(
                                  shape: const StadiumBorder(),
                                  color: cores.primary.withValues(
                                    alpha: escuro ? 0.2 : 0.12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (i, d) in widget.destinos.indexed)
                              _Item(
                                destino: d,
                                ativo: i == widget.indiceAtual,
                                aoTocar: () => _tocar(i),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatefulWidget {
  const _Item({
    required this.destino,
    required this.ativo,
    required this.aoTocar,
  });

  final DestinoBarra destino;
  final bool ativo;
  final VoidCallback aoTocar;

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> with SingleTickerProviderStateMixin {
  late final _escala = AnimationController.unbounded(vsync: this, value: 1);

  @override
  void didUpdateWidget(_Item antigo) {
    super.didUpdateWidget(antigo);
    // O "bounce" do ícone é só de quem acabou de ser escolhido: começa
    // encolhido e a mola o devolve ao tamanho normal, passando um pouco.
    if (widget.ativo &&
        !antigo.ativo &&
        !MediaQuery.disableAnimationsOf(context)) {
      _escala.animateWith(SpringSimulation(_molaIcone, 0.8, 1, 0));
    }
  }

  @override
  void dispose() {
    _escala.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ativo = widget.ativo;
    final cor = ativo
        ? tema.colorScheme.primary
        : tema.colorScheme.onSurfaceVariant;

    return Expanded(
      child: Semantics(
        button: true,
        selected: ativo,
        // Sem ripple do Material: no iOS o retorno visual do toque é a
        // própria cápsula deslizando.
        child: GestureDetector(
          onTap: widget.aoTocar,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _escala,
                child: Icon(
                  ativo ? widget.destino.iconeAtivo : widget.destino.icone,
                  color: cor,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: tema.textTheme.labelSmall!.copyWith(
                  color: cor,
                  fontWeight: ativo ? FontWeight.w600 : FontWeight.w500,
                ),
                child: Text(
                  widget.destino.rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
