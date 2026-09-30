import 'package:flutter/material.dart';

import '../../core/formatos.dart';
import 'modelos.dart';

/// Rótulo e cor do selo do WhatsApp conforme o status da instância.
(String, Color) seloDoWhatsApp(InstanciaResumo? instancia) =>
    switch (instancia?.status) {
      null => ('WhatsApp não conectado', Colors.grey),
      'aguardando_qr' || 'criada' => ('Aguardando leitura do QR', corAlerta),
      'conectada' => (
        instancia!.telefone.isEmpty
            ? 'Conectado'
            : 'Conectado: ${formatarTelefone(instancia.telefone)}',
        corDentroDoSla,
      ),
      'desconectada' => ('Desconectado', corForaDoSla),
      final outro => ('WhatsApp: $outro', corForaDoSla),
    };
