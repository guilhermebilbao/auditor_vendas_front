import 'package:flutter/foundation.dart';

const _apiUrlDefinida = String.fromEnvironment('API_URL');

/// URL do backend (F01, item 1): `--dart-define=API_URL=https://api...`.
/// Sem a variável, usa o backend local. No emulador Android, o `localhost`
/// da máquina é `10.0.2.2`.
String get apiUrl {
  var url = _apiUrlDefinida;
  if (url.isEmpty) {
    final emuladorAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    url = emuladorAndroid ? 'http://10.0.2.2:8088' : 'http://localhost:8088';
  }
  return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}

/// Fuso das lojas (`America/Sao_Paulo`). O Brasil não tem horário de verão
/// desde 2019, então o deslocamento é fixo.
const fusoLoja = Duration(hours: -3);
