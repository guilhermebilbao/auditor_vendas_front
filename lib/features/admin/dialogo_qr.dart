import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/erros.dart';
import '../../core/formatos.dart';
import 'admin_repo.dart';

enum _Fase { gerando, qr, conectado, expirado, removida, erro }

/// Conexão do WhatsApp do vendedor por QR code (spec 18, itens 5 a 9).
///
/// O gestor mostra o QR na própria tela e o vendedor lê com o celular dele.
/// Consulta `GET /instancias/{id}/qrcode` a cada [intervalo] até o celular
/// conectar (`409 INSTANCIA_JA_CONECTADA`). Depois de [prazo] sem conectar,
/// para e oferece gerar um QR novo. Fechar só para a consulta: a instância
/// continua em `aguardando_qr` e pode ser retomada. Fecha devolvendo `true`
/// se conectou.
class DialogoQr extends StatefulWidget {
  const DialogoQr({
    super.key,
    required this.repo,
    required this.instanciaId,
    required this.vendedorNome,
    this.intervalo = const Duration(seconds: 2),
    this.prazo = const Duration(minutes: 2),
  });

  final AdminRepo repo;
  final String instanciaId;
  final String vendedorNome;
  final Duration intervalo;
  final Duration prazo;

  @override
  State<DialogoQr> createState() => _DialogoQrState();
}

class _DialogoQrState extends State<DialogoQr> {
  _Fase _fase = _Fase.gerando;
  Uint8List? _imagem;
  String _telefone = '';
  String _erro = '';
  bool _semConexao = false;
  Timer? _proxima;
  late DateTime _inicio;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _proxima?.cancel();
    super.dispose();
  }

  void _iniciar() {
    _inicio = DateTime.now();
    setState(() {
      _fase = _Fase.gerando;
      _imagem = null;
    });
    _consultar();
  }

  Future<void> _consultar() async {
    if (!mounted) return;
    if (DateTime.now().difference(_inicio) >= widget.prazo) {
      return setState(() => _fase = _Fase.expirado);
    }
    try {
      final imagem = await widget.repo.qrCode(widget.instanciaId);
      if (!mounted) return;
      setState(() {
        _imagem = imagem;
        _fase = _Fase.qr;
        _semConexao = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      switch (e.codigo) {
        case 'QRCODE_INDISPONIVEL':
          // Ainda não há QR: continua consultando.
          setState(() => _semConexao = false);
        case 'INSTANCIA_JA_CONECTADA':
          return _conectou();
        case 'INSTANCIA_INDISPONIVEL':
          // Removida pelo backend (ex.: 30 min sem leitura do QR).
          return setState(() => _fase = _Fase.removida);
        case _ when e.deRede:
          setState(() => _semConexao = true);
        default:
          return setState(() {
            _fase = _Fase.erro;
            _erro = mensagemDoErro(e);
          });
      }
    }
    _proxima = Timer(widget.intervalo, _consultar);
  }

  // No fluxo do QR, `INSTANCIA_JA_CONECTADA` é o sucesso.
  Future<void> _conectou() async {
    setState(() => _fase = _Fase.conectado);
    try {
      final instancia = await widget.repo.buscarInstancia(widget.instanciaId);
      if (mounted) setState(() => _telefone = instancia.telefone);
    } on ApiException {
      // O telefone é só um complemento da mensagem de sucesso.
    }
  }

  Future<void> _gerarNovo() async {
    setState(() => _fase = _Fase.gerando);
    try {
      await widget.repo.reconectar(widget.instanciaId);
      if (mounted) _iniciar();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.codigo == 'INSTANCIA_INDISPONIVEL') {
          _fase = _Fase.removida;
        } else {
          _fase = _Fase.erro;
          _erro = mensagemDoErro(e);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final conectado = _fase == _Fase.conectado;
    final encerrado = conectado || _fase == _Fase.removida;

    final Widget corpo = switch (_fase) {
      _Fase.gerando => const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 24),
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Gerando QR code…'),
          SizedBox(height: 24),
        ],
      ),
      _Fase.qr => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            child: Image.memory(
              _imagem!,
              width: 260,
              height: 260,
              gaplessPlayback: true,
              semanticLabel: 'QR code para conectar o WhatsApp',
            ),
          ),
          const SizedBox(height: 16),
          const _Instrucoes(),
        ],
      ),
      _Fase.conectado => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: corDentroDoSla, size: 56),
          const SizedBox(height: 12),
          Text(
            _telefone.isEmpty
                ? 'WhatsApp conectado!'
                : 'WhatsApp conectado: ${formatarTelefone(_telefone)}',
            style: tema.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      _Fase.expirado => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('O QR code expirou sem que o celular conectasse.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _gerarNovo,
            child: const Text('Gerar novo QR code'),
          ),
        ],
      ),
      _Fase.removida => const Text(
        'Esta conexão expirou. Comece de novo.',
        textAlign: TextAlign.center,
      ),
      _Fase.erro => Text(
        _erro,
        style: TextStyle(color: tema.colorScheme.error),
      ),
    };

    return AlertDialog(
      title: Text('WhatsApp de ${widget.vendedorNome}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            corpo,
            if (_semConexao)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Sem conexão; tentando de novo…',
                  style: TextStyle(color: tema.colorScheme.error),
                ),
              ),
            if (!encerrado) ...[
              const SizedBox(height: 16),
              Text(
                'Não conecte este número pelo Evolution Manager: isso desliga '
                'o recebimento de mensagens.',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, conectado),
          child: Text(conectado ? 'Concluir' : 'Fechar'),
        ),
      ],
    );
  }
}

/// Passos para o vendedor, que está ao lado do gestor (spec 18, item 6).
class _Instrucoes extends StatelessWidget {
  const _Instrucoes();

  static const _passos = [
    'Peça ao vendedor para abrir o WhatsApp no celular dele.',
    'Toque em ⋮ / Configurações → Aparelhos conectados → Conectar um '
        'aparelho.',
    'Aponte a câmera do celular para este QR code.',
  ];

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, passo) in _passos.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: tema.colorScheme.primaryContainer,
                  child: Text(
                    '${i + 1}',
                    style: tema.textTheme.labelSmall?.copyWith(
                      color: tema.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(passo)),
              ],
            ),
          ),
      ],
    );
  }
}
