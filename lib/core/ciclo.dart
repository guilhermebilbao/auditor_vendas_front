import 'dart:async';

import 'package:flutter/widgets.dart';

/// Repete uma consulta em intervalos (conversa, lista de leads, painel, QR).
///
/// - Pausa com o app em segundo plano e retoma na volta (F07, item 4).
/// - Quando a consulta falha, tenta de novo com espera crescente (5s, 10s, 30s)
///   e avisa por [aoMudarFalha], sem apagar o que a tela já mostra (F07, item 2).
class Ciclo with WidgetsBindingObserver {
  Ciclo({
    required this.intervalo,
    required this.tarefa,
    this.ativo,
    this.aoMudarFalha,
  });

  final Duration intervalo;
  final Future<void> Function() tarefa;

  /// Se devolver `false`, a rodada é pulada (ex.: a tela está coberta por outra).
  final bool Function()? ativo;
  final void Function(bool falhando)? aoMudarFalha;

  static const _esperas = [
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  Timer? _timer;
  int _falhas = 0;
  bool _parado = true;
  bool _executando = false;
  bool _emPrimeiroPlano = true;

  bool get falhando => _falhas > 0;

  void iniciar() {
    if (!_parado) return;
    _parado = false;
    WidgetsBinding.instance.addObserver(this);
    _agendar(intervalo);
  }

  void parar() {
    if (_parado) return;
    _parado = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  void _agendar(Duration espera) {
    _timer?.cancel();
    if (_parado || !_emPrimeiroPlano) return;
    _timer = Timer(espera, _executar);
  }

  Future<void> _executar() async {
    if (_parado || _executando) return;
    if (ativo != null && !ativo!()) return _agendar(intervalo);

    _executando = true;
    try {
      await tarefa();
      if (_falhas > 0) {
        _falhas = 0;
        if (!_parado) aoMudarFalha?.call(false);
      }
    } catch (_) {
      _falhas++;
      if (_falhas == 1 && !_parado) aoMudarFalha?.call(true);
    } finally {
      _executando = false;
    }
    _agendar(
      _falhas == 0
          ? intervalo
          : _esperas[(_falhas - 1).clamp(0, _esperas.length - 1)],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visivel = state == AppLifecycleState.resumed;
    if (visivel == _emPrimeiroPlano) return;
    _emPrimeiroPlano = visivel;
    if (visivel) {
      _agendar(Duration.zero);
    } else {
      _timer?.cancel();
    }
  }
}
