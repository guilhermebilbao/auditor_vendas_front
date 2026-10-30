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
        final conversa = organizarConversa(c.mensagens);
        final visiveis = conversa.mensagens;
        final itens = <Widget>[];
        for (var i = visiveis.length - 1; i >= 0; i--) {
          final m = visiveis[i];
          itens.add(
            m.reacao
                ? _ReacaoAvulsa(m)
                : BalaoMensagem(m, reacoes: conversa.reacoes[m.id] ?? const []),
          );
          final anterior = i > 0 ? visiveis[i - 1] : null;
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

/// A conversa pronta para exibir: as reações saem da lista e vão para baixo da
/// mensagem reagida (spec 24).
typedef ConversaOrganizada = ({
  List<Mensagem> mensagens,
  Map<int, List<Mensagem>> reacoes,
});

/// Separa as reações das mensagens. Vale só a reação mais recente de cada
/// pessoa em cada mensagem (como no WhatsApp). Reação a uma mensagem que não
/// está carregada fica na lista, como linha avulsa.
ConversaOrganizada organizarConversa(List<Mensagem> todas) {
  final carregadas = {
    for (final m in todas)
      if (!m.reacao) m.id,
  };
  final ultimas = <(int, String), Mensagem>{};
  final mensagens = <Mensagem>[];
  for (final m in todas) {
    final alvo = m.reageA;
    if (!m.reacao || alvo == null || !carregadas.contains(alvo)) {
      mensagens.add(m);
      continue;
    }
    final chave = (alvo, m.autor);
    final anterior = ultimas[chave];
    if (anterior == null || m.id > anterior.id) ultimas[chave] = m;
  }
  final reacoes = <int, List<Mensagem>>{};
  for (final r in ultimas.values) {
    reacoes.putIfAbsent(r.reageA!, () => []).add(r);
  }
  return (mensagens: mensagens, reacoes: reacoes);
}

/// Reação a uma mensagem que não está carregada (ex.: anterior à conexão).
class _ReacaoAvulsa extends StatelessWidget {
  const _ReacaoAvulsa(this.reacao);

  final Mensagem reacao;

  @override
  Widget build(BuildContext context) {
    final quem = reacao.doVendedor ? 'O vendedor' : 'O cliente';
    return Align(
      alignment: reacao.doVendedor
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: Text(
          '$quem reagiu com ${reacao.conteudo} a uma mensagem anterior · '
          '${formatarHora(reacao.enviadaEm)}',
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
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
  const BalaoMensagem(this.mensagem, {super.key, this.reacoes = const []});

  final Mensagem mensagem;

  /// Reações a esta mensagem, mostradas embaixo do balão (spec 24).
  final List<Mensagem> reacoes;

  @override
  Widget build(BuildContext context) {
    final m = mensagem;
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    // A boas-vindas automática (spec 22) fica do lado do vendedor, com outra cor.
    final fundo = m.automatica
        ? cores.tertiaryContainer
        : m.doVendedor
        ? cores.primaryContainer
        : cores.surfaceContainerHighest;
    final corTexto = m.automatica
        ? cores.onTertiaryContainer
        : m.doVendedor
        ? cores.onPrimaryContainer
        : cores.onSurface;
    final discreto = TextStyle(
      fontSize: 11,
      color: corTexto.withValues(alpha: 0.7),
    );

    Widget aviso(String texto) => Text(
      texto,
      style: TextStyle(color: corTexto, fontStyle: FontStyle.italic),
    );

    final Widget corpo;
    if (m.apagada && !m.doVendedor) {
      corpo = aviso('🚫 Mensagem apagada pelo cliente');
    } else if (m.figurinha) {
      corpo = aviso('🖼️ Figurinha ${m.conteudo}'.trim());
    } else if (m.audioPendente) {
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
    } else if (m.apagada) {
      // Apagada pelo vendedor: o gerente vê o que foi apagado (spec 24).
      corpo = Text(
        m.conteudo,
        style: TextStyle(
          color: corTexto,
          decoration: TextDecoration.lineThrough,
        ),
      );
    } else {
      corpo = Text(m.conteudo, style: TextStyle(color: corTexto));
    }

    final horario = [
      if (m.apagada && m.doVendedor) 'apagada pelo vendedor',
      if (m.editada) 'editada',
      formatarHora(m.enviadaEm),
    ].join(' · ');

    final balao = Container(
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
          if (m.automatica)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy_outlined, size: 14, color: corTexto),
                  const SizedBox(width: 4),
                  Text(
                    'automática',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: corTexto,
                    ),
                  ),
                ],
              ),
            )
          else if (m.doVendedor && (m.vendedor ?? '').isNotEmpty)
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
            child: Text(horario, style: discreto),
          ),
        ],
      ),
    );

    return Align(
      alignment: m.doVendedor ? Alignment.centerRight : Alignment.centerLeft,
      child: reacoes.isEmpty
          ? balao
          : Column(
              crossAxisAlignment: m.doVendedor
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [balao, _Reacoes(reacoes)],
            ),
    );
  }
}

/// Emojis das reações embaixo do balão, como no WhatsApp.
class _Reacoes extends StatelessWidget {
  const _Reacoes(this.reacoes);

  final List<Mensagem> reacoes;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final quem = reacoes
        .map((r) => '${r.doVendedor ? 'vendedor' : 'cliente'} ${r.conteudo}')
        .join(', ');
    return Transform.translate(
      offset: const Offset(0, -6),
      child: Tooltip(
        message: 'Reações: $quem',
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: cores.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cores.outlineVariant),
          ),
          child: Text(
            reacoes.map((r) => r.conteudo).join(' '),
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }
}
