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

/// Termos de uso e política de privacidade mostrados no cadastro (spec 19).
/// A [versaoTermos] vai junto com o aceite; mude-a quando o texto mudar.
const urlTermos = String.fromEnvironment(
  'URL_TERMOS',
  defaultValue: 'https://www.emplakey.com/termos',
);
const urlPrivacidade = String.fromEnvironment(
  'URL_PRIVACIDADE',
  defaultValue: 'https://www.emplakey.com/privacidade',
);
const versaoTermos = String.fromEnvironment(
  'VERSAO_TERMOS',
  defaultValue: '2026-10',
);
