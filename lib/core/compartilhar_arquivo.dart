import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Salva o conteúdo num arquivo temporário e abre o compartilhamento do
/// sistema (F06, item 22, mobile). Na web, o equivalente é baixar o arquivo.
Future<void> compartilharArquivo({
  required String nome,
  required String conteudo,
  required String tipo,
  String? assunto,
}) async {
  final pasta = await getTemporaryDirectory();
  final arquivo = File('${pasta.path}/$nome');
  await arquivo.writeAsString(conteudo);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(arquivo.path, mimeType: tipo)],
      subject: assunto,
    ),
  );
}
