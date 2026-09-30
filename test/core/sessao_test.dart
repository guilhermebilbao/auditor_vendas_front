import 'package:auditor_vendas_front/core/api/api_exception.dart';
import 'package:auditor_vendas_front/core/api/cliente_api.dart';
import 'package:auditor_vendas_front/core/sessao/armazenamento_token.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../apoio.dart';

void main() {
  final agora = DateTime.parse('2026-09-30T15:00:00-03:00');
  final daquiUmaHora = agora.add(const Duration(hours: 1));

  late ArmazenamentoMemoria cofre;
  late AdaptadorFalso servidor;
  late int renovacoes;
  late Set<String> vencidos;

  /// Servidor com rotação de refresh token: cada refresh só vale uma vez.
  ClienteApi criar({
    String? refreshGuardado = 'refresh-0',
    ResponseBody? Function(RequestOptions)? extra,
  }) {
    cofre = ArmazenamentoMemoria(refreshGuardado);
    renovacoes = 0;
    vencidos = {};
    var refreshValido = 'refresh-0';
    servidor = AdaptadorFalso((req) async {
      final caminho = req.uri.path;
      if (caminho.endsWith('/auth/refresh')) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if ((req.data as Map)['refresh_token'] != refreshValido) {
          return respostaErro(401, 'NAO_AUTENTICADO');
        }
        renovacoes++;
        refreshValido = 'refresh-$renovacoes';
        return respostaJson(200, sessaoJson('$renovacoes', daquiUmaHora));
      }
      final especial = extra?.call(req);
      if (especial != null) return especial;
      final token = req.headers['Authorization'];
      if (token == null) return respostaErro(401, 'NAO_AUTENTICADO');
      if (vencidos.contains(token)) return respostaErro(401, 'TOKEN_EXPIRADO');
      return respostaJson(200, {'ok': caminho});
    });
    return ClienteApi(
      armazenamento: cofre,
      urlBase: 'http://teste',
      adaptador: servidor,
      agora: () => agora,
    );
  }

  test(
    '5 requisições juntas sem token válido geram um único refresh',
    () async {
      final api = criar();

      final respostas = await Future.wait([
        for (var i = 0; i < 5; i++) api.get('/leads/$i'),
      ]);

      expect(respostas.map((r) => r.statusCode), everyElement(200));
      expect(servidor.vezes('/auth/refresh'), 1);
      expect(cofre.valor, 'refresh-1', reason: 'guarda o refresh token novo');
    },
  );

  test(
    '401 TOKEN_EXPIRADO em 5 requisições: renova uma vez e repete',
    () async {
      final api = criar();
      await api.sessao.restaurar();
      expect(servidor.vezes('/auth/refresh'), 1);

      // O token ainda está no prazo para o app, mas o servidor já o recusa.
      vencidos.add('Bearer acesso-1');
      final respostas = await Future.wait([
        for (var i = 0; i < 5; i++) api.get('/leads/$i'),
      ]);

      expect(respostas.map((r) => r.statusCode), everyElement(200));
      expect(
        servidor.vezes('/auth/refresh'),
        2,
        reason: 'um só refresh a mais',
      );
      expect(cofre.valor, 'refresh-2');
    },
  );

  test('refresh recusado limpa a sessão e avisa (vai para o login)', () async {
    final api = criar(refreshGuardado: 'refresh-revogado');
    var perdeu = false;
    api.sessao.aoPerder = () => perdeu = true;

    await expectLater(
      api.get('/me'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.codigo,
          'codigo',
          'NAO_AUTENTICADO',
        ),
      ),
    );
    expect(perdeu, isTrue);
    expect(cofre.valor, isNull);
  });

  test('sem refresh token guardado, restaurar não chama o servidor', () async {
    final api = criar(refreshGuardado: null);
    expect(await api.sessao.restaurar(), isNull);
    expect(servidor.chamadas, isEmpty);
  });

  test(
    'senha atual incorreta também é 401, mas não derruba a sessão',
    () async {
      final api = criar(
        extra: (req) => req.uri.path.endsWith('/me/senha')
            ? respostaErro(401, 'CREDENCIAIS_INVALIDAS')
            : null,
      );
      var perdeu = false;
      api.sessao.aoPerder = () => perdeu = true;

      await expectLater(
        api.patch('/me/senha', corpo: {'senha_atual': 'x', 'senha_nova': 'y'}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.codigo, 'codigo', 'CREDENCIAIS_INVALIDAS')
              .having((e) => e.status, 'status', 401),
        ),
      );
      expect(perdeu, isFalse);
      expect(cofre.valor, 'refresh-1');
    },
  );

  test('logout apaga o refresh token mesmo se o servidor falhar', () async {
    final api = criar(
      extra: (req) => req.uri.path.endsWith('/auth/logout')
          ? respostaErro(500, 'ERRO_INTERNO')
          : null,
    );
    await api.get('/me');
    await api.sessao.sair();
    expect(cofre.valor, isNull);
    expect(servidor.vezes('/auth/logout'), 1);
  });

  test('erros de rede e timeout viram códigos locais', () async {
    final api = criar();
    await api.sessao.restaurar();

    servidor = AdaptadorFalso(
      (req) => throw DioException.connectionError(
        requestOptions: req,
        reason: 'sem rede',
      ),
    );
    api.dio.httpClientAdapter = servidor;
    await expectLater(
      api.get('/leads'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.codigo,
          'codigo',
          ApiException.semConexao,
        ),
      ),
    );

    api.dio.httpClientAdapter = AdaptadorFalso(
      (req) => throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 15),
        requestOptions: req,
      ),
    );
    await expectLater(
      api.get('/leads'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.codigo,
          'codigo',
          ApiException.tempoEsgotado,
        ),
      ),
    );
  });

  test('erro da API chega como ApiException com código e request id', () async {
    final api = criar(
      extra: (req) => req.uri.path.endsWith('/leads/9')
          ? respostaJson(
              404,
              {'erro': 'Lead não encontrado', 'codigo': 'LEAD_NAO_ENCONTRADO'},
              headers: {'x-request-id': 'req-42'},
            )
          : null,
    );
    await expectLater(
      api.get('/leads/9'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.codigo, 'codigo', 'LEAD_NAO_ENCONTRADO')
            .having((e) => e.status, 'status', 404)
            .having((e) => e.requestId, 'requestId', 'req-42'),
      ),
    );
  });

  test('auditoria usa timeout de 120s; o padrão é 15s', () async {
    final api = criar();
    await api.post('/leads/1/auditar', timeout: timeoutIA);
    await api.get('/leads/1');
    final auditar = servidor.chamadas.firstWhere(
      (c) => c.uri.path.endsWith('/auditar'),
    );
    expect(auditar.receiveTimeout, const Duration(seconds: 120));
    expect(servidor.chamadas.last.receiveTimeout, const Duration(seconds: 15));
  });
}
