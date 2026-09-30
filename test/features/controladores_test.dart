import 'package:auditor_vendas_front/core/api/cliente_api.dart';
import 'package:auditor_vendas_front/core/sessao/armazenamento_token.dart';
import 'package:auditor_vendas_front/features/auditoria/auditoria_repo.dart';
import 'package:auditor_vendas_front/features/conversa/conversa_controller.dart';
import 'package:auditor_vendas_front/features/leads/leads_controller.dart';
import 'package:auditor_vendas_front/features/leads/leads_repo.dart';
import 'package:auditor_vendas_front/features/leads/modelos.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../apoio.dart';

Map<String, dynamic> _mensagem(
  int id,
  String enviadaEm, {
  String tipo = 'texto',
  String conteudo = 'oi',
  String? status,
  bool transcricao = false,
}) => {
  'id': id,
  'autor': 'lead',
  'vendedor': null,
  'tipo': tipo,
  'conteudo': conteudo,
  'transcricao': transcricao,
  'status_transcricao': status,
  'enviada_em': enviadaEm,
};

Map<String, dynamic> _lead(
  int id,
  String ultimaMensagemEm, {
  String nome = '',
}) => {
  'id': id,
  'vendedor_id': 1,
  'vendedor_nome': 'Bruno',
  'telefone': '5548999990000',
  'lid': '',
  'push_name': nome.isEmpty ? 'Cliente $id' : nome,
  'temperatura': '',
  'ultima_mensagem_em': ultimaMensagemEm,
  'total_mensagens': 3,
  'ultima_mensagem': 'oi',
  'aguardando_resposta': true,
  'ultima_auditoria_em': null,
  'probabilidade_conversao': null,
};

void main() {
  final agora = DateTime.parse('2026-09-30T15:00:00-03:00');
  late AdaptadorFalso servidor;

  ClienteApi criarApi(ResponseBody Function(RequestOptions) responder) {
    servidor = AdaptadorFalso((req) {
      if (req.uri.path.endsWith('/auth/refresh')) {
        return respostaJson(
          200,
          sessaoJson('1', agora.add(const Duration(hours: 1))),
        );
      }
      return responder(req);
    });
    return ClienteApi(
      armazenamento: ArmazenamentoMemoria('refresh-0'),
      urlBase: 'http://teste',
      adaptador: servidor,
      agora: () => agora,
    );
  }

  List<Uri> consultas(String sufixo) => [
    for (final c in servidor.chamadas)
      if (c.uri.path.endsWith(sufixo)) c.uri,
  ];

  group('conversa', () {
    late List<Map<String, dynamic>> novas;
    late Map<int, Map<String, dynamic>> atualizadas;

    ConversaController criar() {
      novas = [];
      atualizadas = {};
      final api = criarApi((req) {
        final q = req.uri.queryParameters;
        if (q.containsKey('depois')) {
          final itens = novas;
          novas = [];
          return respostaJson(200, {
            'itens': itens,
            'proximo_cursor': null,
            'ultimo_cursor': 'cursor-novo',
          });
        }
        if (q.containsKey('ids')) {
          return respostaJson(200, {
            'itens': [
              for (final id in q['ids']!.split(','))
                ?atualizadas[int.parse(id)],
            ],
            'proximo_cursor': null,
            'ultimo_cursor': 'cursor-1',
          });
        }
        if (q.containsKey('antes')) {
          return respostaJson(200, {
            'itens': [_mensagem(1, '2026-09-29T09:00:00-03:00')],
            'proximo_cursor': null,
            'ultimo_cursor': 'cursor-1',
          });
        }
        return respostaJson(200, {
          'itens': [
            _mensagem(10, '2026-09-30T10:00:00-03:00'),
            _mensagem(
              11,
              '2026-09-30T10:05:00-03:00',
              tipo: 'audio',
              conteudo: '',
              status: 'pendente',
            ),
            _mensagem(12, '2026-09-30T10:10:00-03:00'),
          ],
          'proximo_cursor': 'cursor-antigas',
          'ultimo_cursor': 'cursor-1',
        });
      });
      return ConversaController(LeadsRepo(api), 7);
    }

    test('mensagem atrasada entra na posição do seu horário', () async {
      final conversa = criar();
      await conversa.abrir();
      expect(conversa.mensagens.map((m) => m.id), [10, 11, 12]);

      // Chegou depois (id maior), mas foi enviada antes da 12.
      novas = [_mensagem(13, '2026-09-30T10:07:00-03:00')];
      await conversa.buscarNovas();

      expect(conversa.mensagens.map((m) => m.id), [10, 11, 13, 12]);
      expect(
        consultas('/mensagens').last.queryParameters['depois'],
        'cursor-1',
      );
    });

    test('guarda o ultimo_cursor novo para a consulta seguinte', () async {
      final conversa = criar();
      await conversa.abrir();
      await conversa.buscarNovas();
      await conversa.buscarNovas();
      expect(
        consultas('/mensagens').last.queryParameters['depois'],
        'cursor-novo',
      );
    });

    test(
      'fora do fim da conversa, as novas ficam retidas ("↓ N novas")',
      () async {
        final conversa = criar();
        await conversa.abrir();
        conversa.marcarNoFim(false);

        novas = [
          _mensagem(13, '2026-09-30T10:20:00-03:00'),
          _mensagem(14, '2026-09-30T10:21:00-03:00'),
        ];
        await conversa.buscarNovas();
        expect(conversa.mensagens, hasLength(3));
        expect(conversa.novasRetidas, 2);

        conversa.marcarNoFim(true);
        expect(conversa.mensagens.map((m) => m.id), [10, 11, 12, 13, 14]);
        expect(conversa.novasRetidas, 0);
      },
    );

    test('histórico entra acima, sem repetir, e marca o início', () async {
      final conversa = criar();
      await conversa.abrir();
      expect(conversa.chegouAoInicio, isFalse);

      await conversa.carregarHistorico();
      expect(conversa.mensagens.map((m) => m.id), [1, 10, 11, 12]);
      expect(conversa.chegouAoInicio, isTrue);

      // Sem cursor, não consulta de novo.
      final antes = servidor.chamadas.length;
      await conversa.carregarHistorico();
      expect(servidor.chamadas.length, antes);
    });

    test(
      'áudio pendente é atualizado por ?ids=, sem reabrir a conversa',
      () async {
        final conversa = criar();
        await conversa.abrir();
        expect(conversa.mensagens[1].audioPendente, isTrue);

        atualizadas[11] = _mensagem(
          11,
          '2026-09-30T10:05:00-03:00',
          tipo: 'audio',
          conteudo: 'quero ver o carro',
          status: 'concluida',
          transcricao: true,
        );
        await conversa.atualizarPendentes();

        final audio = conversa.mensagens[1];
        expect(audio.audioPendente, isFalse);
        expect(audio.audioTranscrito, isTrue);
        expect(audio.conteudo, 'quero ver o carro');
        expect(consultas('/mensagens').last.queryParameters, {'ids': '11'});

        // Sem pendentes, não há o que consultar.
        final antes = servidor.chamadas.length;
        await conversa.atualizarPendentes();
        expect(servidor.chamadas.length, antes);
      },
    );

    test(
      'só a abertura carrega sem cursor (a única que registra leitura)',
      () async {
        final conversa = criar();
        await conversa.abrir();
        for (var i = 0; i < 5; i++) {
          await conversa.buscarNovas();
          await conversa.atualizarPendentes();
        }
        await conversa.carregarHistorico();

        final semCursor = consultas('/mensagens').where((u) {
          final q = u.queryParameters;
          return !q.containsKey('depois') &&
              !q.containsKey('antes') &&
              !q.containsKey('ids');
        });
        expect(semCursor, hasLength(1));
      },
    );
  });

  group('lista de leads', () {
    test(
      'atualização mescla pelo id e reordena pela última mensagem',
      () async {
        var atualizados = <Map<String, dynamic>>[];
        final api = criarApi((req) {
          if (req.uri.queryParameters.containsKey('atualizados_desde')) {
            return respostaJson(200, {
              'itens': atualizados,
              'proximo_cursor': null,
            });
          }
          return respostaJson(200, {
            'itens': [
              _lead(1, '2026-09-30T14:00:00-03:00'),
              _lead(2, '2026-09-30T13:00:00-03:00'),
            ],
            'proximo_cursor': null,
          });
        });
        final lista = LeadsController(
          LeadsRepo(api),
          const FiltrosLeads(temperatura: 'Quente'),
          agora: () => agora,
        );
        await lista.carregar();
        expect(lista.itens.map((l) => l.id), [1, 2]);

        atualizados = [
          _lead(2, '2026-09-30T14:30:00-03:00', nome: 'Maria'),
          _lead(3, '2026-09-30T14:10:00-03:00'),
        ];
        await lista.atualizar();

        expect(lista.itens.map((l) => l.id), [2, 3, 1]);
        expect(lista.itens.first.nome, 'Maria');

        final q = consultas('/leads').last.queryParameters;
        expect(q['temperatura'], 'Quente', reason: 'mantém os filtros atuais');
        expect(q['atualizados_desde'], '2026-09-30T17:59:55Z');
      },
    );

    test(
      'rolagem infinita usa o proximo_cursor e para quando ele é nulo',
      () async {
        final api = criarApi((req) {
          final cursor = req.uri.queryParameters['cursor'];
          return respostaJson(200, {
            'itens': [
              _lead(cursor == null ? 1 : 2, '2026-09-30T14:00:00-03:00'),
            ],
            'proximo_cursor': cursor == null ? 'pagina-2' : null,
          });
        });
        final lista = LeadsController(LeadsRepo(api), const FiltrosLeads());
        await lista.carregar();
        expect(lista.temMais, isTrue);

        await lista.carregarMais();
        expect(lista.itens.map((l) => l.id), [1, 2]);
        expect(lista.temMais, isFalse);
        expect(consultas('/leads').last.queryParameters['cursor'], 'pagina-2');

        final antes = servidor.chamadas.length;
        await lista.carregarMais();
        expect(servidor.chamadas.length, antes);
      },
    );
  });

  test('filtros da lista vão e voltam da URL', () {
    const filtros = FiltrosLeads(
      q: 'maria',
      vendedorId: 3,
      temperatura: 'Quente',
      haMaisDe: '2h',
    );
    final rota = filtros.paraRota();
    expect(
      rota,
      '/leads?q=maria&vendedor_id=3&temperatura=Quente&ha_mais_de=2h',
    );
    expect(FiltrosLeads.daUrl(Uri.parse(rota).queryParameters), filtros);
    expect(const FiltrosLeads().paraRota(), '/leads');
  });

  group('auditar', () {
    const analise = {'nota_geral': 7.5, 'probabilidade_conversao': 60};

    test(
      '201: auditoria nova, com o id e os áudios que ficaram de fora',
      () async {
        final api = criarApi(
          (req) => respostaJson(
            201,
            analise,
            headers: {'x-auditoria-id': '42', 'x-transcricoes-pendentes': '2'},
          ),
        );
        final r = await AuditoriaRepo(api).auditar(7);
        expect(r.auditoriaId, 42);
        expect(r.reutilizada, isFalse);
        expect(r.transcricoesPendentes, 2);
        expect(r.analise.notaGeral, 7.5);
        expect(servidor.chamadas.last.receiveTimeout, timeoutIA);
        expect(servidor.chamadas.last.uri.queryParameters, isEmpty);
      },
    );

    test(
      '200 reaproveitada; "Refazer mesmo assim" manda ?forcar=true',
      () async {
        final api = criarApi(
          (req) => respostaJson(
            200,
            analise,
            headers: {
              'x-auditoria-id': '41',
              'x-auditoria-reutilizada': 'true',
            },
          ),
        );
        final repo = AuditoriaRepo(api);
        final r = await repo.auditar(7);
        expect(r.reutilizada, isTrue);
        expect(r.auditoriaId, 41);

        await repo.auditar(7, forcar: true);
        expect(servidor.chamadas.last.uri.queryParameters, {'forcar': 'true'});
      },
    );

    test('PATCH da auditoria manda só o campo alterado', () async {
      final api = criarApi((req) => respostaJson(200, {'id': 5}));
      final repo = AuditoriaRepo(api);

      await repo.atualizar(5, feedbackEntregue: true);
      expect(servidor.chamadas.last.data, {'feedback_entregue': true});

      // Texto vazio apaga a observação.
      await repo.atualizar(5, observacaoGerente: '');
      expect(servidor.chamadas.last.data, {'observacao_gerente': ''});
    });
  });
}
