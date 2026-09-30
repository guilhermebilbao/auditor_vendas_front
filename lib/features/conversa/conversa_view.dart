import 'package:flutter/material.dart';

import '../../core/formatos.dart';
import '../../widgets/estados.dart';
import '../leads/modelos.dart';
import 'conversa_controller.dart';

/// Conversa somente leitura: o painel não envia mensagens (F03, item 12).
class ConversaView extends StatefulWidget {
  const ConversaView({super.key, required this.controle});

  final ConversaController controle;

  @override
  State<ConversaView> createState() => _ConversaViewState();
}

class _ConversaViewState extends State<ConversaView> {
  final _rolagem = ScrollController();

  @override
  void initState() {
    super.initState();
    _rolagem.addListener(_aoRolar);
    // A lista sempre abre no fim da conversa (ex.: ao voltar de outra aba).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controle.marcarNoFim(true);
    });
  }

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  // A lista é invertida: o deslocamento zero é o fim da conversa.
  void _aoRolar() {
    final posicao = _rolagem.position;
    widget.controle.marcarNoFim(posicao.pixels < 80);
    if (posicao.extentAfter < 400) {
      widget.controle.carregarHistorico().catchError((_) {});
    }
  }

  void _irParaOFim() {
    widget.controle.mostrarRetidas();
    _rolagem.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controle,
      builder: (context, _) {
        final c = widget.controle;
        if (c.carregando) return const Carregando();
        if (c.erro != null) {
          return ErroTela(c.erro!, aoTentarDeNovo: c.abrir);
        }
        if (c.mensagens.isEmpty) {
          return const Vazio(
            'Ainda não há mensagens nesta conversa.',
            icone: Icons.chat_bubble_outline,
          );
        }

        // Do fim para o começo: mensagens, separadores de dia e, no topo, o
        // marcador de início (ou o carregamento do histórico).
        final itens = <Widget>[];
        for (var i = c.mensagens.length - 1; i >= 0; i--) {
          final m = c.mensagens[i];
          itens.add(BalaoMensagem(m));
          final anterior = i > 0 ? c.mensagens[i - 1] : null;
          if (anterior == null ||
              !mesmoDiaNaLoja(anterior.enviadaEm, m.enviadaEm)) {
            itens.add(_SeparadorDia(formatarDia(m.enviadaEm)));
          }
        }
        itens.add(
          c.chegouAoInicio
              ? const _SeparadorDia('Início da conversa')
              : const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
        );

        return Stack(
          children: [
            ListView.builder(
              controller: _rolagem,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: itens.length,
              itemBuilder: (context, i) => itens[i],
            ),
            if (c.novasRetidas > 0)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: FilledButton.tonalIcon(
                    onPressed: _irParaOFim,
                    icon: const Icon(Icons.arrow_downward, size: 18),
                    label: Text(
                      c.novasRetidas == 1
                          ? '1 nova'
                          : '${c.novasRetidas} novas',
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SeparadorDia extends StatelessWidget {
  const _SeparadorDia(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: cores.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(texto, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}

/// Balão de uma mensagem: cliente à esquerda, vendedor à direita (F03, item 11).
class BalaoMensagem extends StatelessWidget {
  const BalaoMensagem(this.mensagem, {super.key});

  final Mensagem mensagem;

  @override
  Widget build(BuildContext context) {
    final m = mensagem;
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final fundo = m.doVendedor
        ? cores.primaryContainer
        : cores.surfaceContainerHighest;
    final corTexto = m.doVendedor ? cores.onPrimaryContainer : cores.onSurface;
    final discreto = TextStyle(
      fontSize: 11,
      color: corTexto.withValues(alpha: 0.7),
    );

    Widget aviso(String texto) => Text(
      texto,
      style: TextStyle(color: corTexto, fontStyle: FontStyle.italic),
    );

    final Widget corpo;
    if (m.audioPendente) {
      corpo = aviso('🎤 Transcrevendo áudio…');
    } else if (m.audioFalhou) {
      corpo = aviso('🎤 Áudio (não foi possível transcrever)');
    } else if (m.audioTranscrito) {
      corpo = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic, size: 14, color: corTexto.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text('transcrição do áudio', style: discreto),
            ],
          ),
          const SizedBox(height: 2),
          Text(m.conteudo, style: TextStyle(color: corTexto)),
        ],
      );
    } else if (m.midiaSemConteudo) {
      corpo = aviso('📎 Mídia (imagem, vídeo ou documento), ainda não exibida');
    } else {
      corpo = Text(m.conteudo, style: TextStyle(color: corTexto));
    }

    return Align(
      alignment: m.doVendedor ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width.clamp(0, 720) * 0.8,
        ),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: fundo,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.doVendedor && (m.vendedor ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  m.vendedor!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: corTexto,
                  ),
                ),
              ),
            corpo,
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.bottomRight,
              widthFactor: 1,
              child: Text(formatarHora(m.enviadaEm), style: discreto),
            ),
          ],
        ),
      ),
    );
  }
}
