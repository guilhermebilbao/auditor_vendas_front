import 'package:flutter/material.dart';

const _semente = Color(0xFF1F4E79);

ThemeData tema(Brightness brilho) {
  final cores = ColorScheme.fromSeed(seedColor: _semente, brightness: brilho);
  return ThemeData(
    colorScheme: cores,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: cores.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cores.outlineVariant),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    // Alvos de toque com pelo menos 48px (F07, item 7).
    materialTapTargetSize: MaterialTapTargetSize.padded,
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Largura a partir da qual a tela usa o layout de desktop (F07, item 6).
const larguraDesktop = 1024.0;

bool ehDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= larguraDesktop;
