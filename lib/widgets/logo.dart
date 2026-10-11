import 'package:flutter/material.dart';

/// Logo do EmplaKey (ícone e nome). No tema escuro, o azul vira claro.
class LogoApp extends StatelessWidget {
  const LogoApp({super.key, this.largura = 220});

  final double largura;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      escuro ? 'assets/logo/emplakey_escuro.png' : 'assets/logo/emplakey.png',
      width: largura,
      semanticLabel: 'EmplaKey',
    );
  }
}
