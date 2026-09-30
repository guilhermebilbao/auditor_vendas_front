import 'package:auditor_vendas_front/core/api/api_exception.dart';
import 'package:auditor_vendas_front/features/admin/admin_repo.dart';
import 'package:auditor_vendas_front/features/admin/dialogo_qr.dart';
import 'package:auditor_vendas_front/features/admin/loja_tela.dart';
import 'package:auditor_vendas_front/features/admin/modelos.dart';
import 'package:auditor_vendas_front/features/auditoria/analise_view.dart';
import 'package:auditor_vendas_front/features/auditoria/modelos.dart';
import 'package:auditor_vendas_front/features/auditoria/painel_auditorias.dart';
import 'package:auditor_vendas_front/features/conversa/conversa_view.dart';
import 'package:auditor_vendas_front/features/desempenho/desempenho_tela.dart';
import 'package:auditor_vendas_front/features/desempenho/modelos.dart';
import 'package:auditor_vendas_front/features/desempenho/vendedor_tela.dart';
import 'package:auditor_vendas_front/features/leads/modelos.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../apoio.dart';

Mensagem _mensagem({
  String autor = 'lead',
  String tipo = 'texto',
  String conteudo = '',
  String? status,
  bool transcricao = false,
}) => Mensagem.deJson({
  'id': 1,
  'autor': autor,
  'vendedor': autor == 'vendedor' ? 'Bruno' : null,
  'tipo': tipo,
  'conteudo': conteudo,
  'transcricao': transcricao,
  'status_transcricao': status,
  'enviada_em': '2026-09-30T14:32:00-03:00',
});

const _analise = {
  'perfil_do_negocio': {
    'veiculo_interesse': 'Onix 2022',
    'tem_carro_na_troca': null,
    'forma_pagamento_citada': 'Financiamento',
  },
  'qualificacao_lead': {
    'temperatura': 'Quente',
    'estagio_jornada': 'Negociação',
    'urgencia_compra': 'Alta',
  },
  'analise_tecnica_vendedor': {
    'pontos_fortes': ['Respondeu rápido'],
    'falhas_e_gargalos': ['Não pediu o telefone'],
    'objecoes_levantadas': <String>[],
  },
  'avaliacao_vendedor': {
    'agilidade': {'nota': 9, 'justificativa': 'Respondeu em 2 minutos'},
    'rapport': {'nota': 7, 'justificativa': 'Cordial'},
    'qualificacao': {'nota': 5, 'justificativa': 'Faltou perguntar o prazo'},
    'contorno_objecoes': {
      'nota': null,
      'justificativa': 'Nenhuma objeção levantada',
    },
    'conducao_fechamento': {'nota': 6, 'justificativa': 'Não propôs visita'},
    'comunicacao': {'nota': 8, 'justificativa': 'Clara'},
  },
  'nota_geral': 7.2,
  'probabilidade_conversao': 75,
  'plano_acao_gestor': {
    'feedback_vendedor': 'Bruno, proponha a visita logo no início.',
    'proximos_passos_sugeridos': ['Ligar amanhã'],
  },
};

/// Repositório falso do fluxo de QR: cada consulta consome o próximo passo.
class _RepoQr implements AdminRepo {
  _RepoQr(this.passos);

  final List<Object> passos;
  int consultas = 0;
  int reconexoes = 0;

  @override
  Future<Uint8List> qrCode(String instanciaId) async {
    final passo = passos[consultas.clamp(0, passos.length - 1)];
    consultas++;
    if (passo is ApiException) throw passo;
    return passo as Uint8List;
  }

  @override
  Future<Instancia> buscarInstancia(String id) async => Instancia.deJson({
    'id': id,
    'vendedor_id': 1,
    'vendedor_nome': 'Bruno',
    'status': 'conectada',
    'telefone': '5548999990000',
    'ultimo_erro': null,
  });

  @override
  Future<Instancia> reconectar(String instanciaId) async {
    reconexoes++;
    return buscarInstancia(instanciaId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('balões da conversa', () {
    Future<void> mostrar(WidgetTester tester, Mensagem m) =>
        tester.pumpWidget(app(BalaoMensagem(m)));

    testWidgets('texto do cliente à esquerda, com a hora da loja', (
      tester,
    ) async {
      await mostrar(tester, _mensagem(conteudo: 'Bom dia'));
      expect(find.text('Bom dia'), findsOneWidget);
      expect(find.text('14:32'), findsOneWidget);
      final alinhamento = tester.widget<Align>(find.byType(Align).first);
      expect(alinhamento.alignment, Alignment.centerLeft);
    });

    testWidgets('vendedor à direita, com o nome', (tester) async {
      await mostrar(tester, _mensagem(autor: 'vendedor', conteudo: 'Olá!'));
      expect(find.text('Bruno'), findsOneWidget);
      final alinhamento = tester.widget<Align>(find.byType(Align).first);
      expect(alinhamento.alignment, Alignment.centerRight);
    });

    testWidgets('áudio transcrito mostra o texto e a legenda', (tester) async {
      await mostrar(
        tester,
        _mensagem(
          tipo: 'audio',
          conteudo: 'quero ver o carro',
          status: 'concluida',
          transcricao: true,
        ),
      );
      expect(find.text('quero ver o carro'), findsOneWidget);
      expect(find.text('transcrição do áudio'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('áudio pendente', (tester) async {
      await mostrar(tester, _mensagem(tipo: 'audio', status: 'pendente'));
      expect(find.text('🎤 Transcrevendo áudio…'), findsOneWidget);
    });

    testWidgets('áudio que falhou', (tester) async {
      await mostrar(tester, _mensagem(tipo: 'audio', status: 'falhou'));
      expect(
        find.text('🎤 Áudio (não foi possível transcrever)'),
        findsOneWidget,
      );
    });

    testWidgets('mídia ainda não processada', (tester) async {
      await mostrar(tester, _mensagem(tipo: 'midia'));
      expect(
        find.text('📎 Mídia (imagem, vídeo ou documento), ainda não exibida'),
        findsOneWidget,
      );
    });
  });

  group('análise da auditoria', () {
    Future<void> mostrar(WidgetTester tester, Map<String, dynamic> json) =>
        tester.pumpWidget(
          app(
            SingleChildScrollView(child: AnaliseView(AnaliseIA.deJson(json))),
          ),
        );

    testWidgets('6 critérios com justificativa; o nulo é "não avaliado"', (
      tester,
    ) async {
      await mostrar(tester, _analise);

      expect(find.text('7,2'), findsOneWidget);
      for (final criterio in [
        'Agilidade',
        'Rapport',
        'Qualificação',
        'Contorno de objeções',
        'Condução ao fechamento',
        'Comunicação',
      ]) {
        expect(find.text(criterio), findsOneWidget);
      }
      expect(find.text('9/10'), findsOneWidget);
      expect(find.text('não avaliado'), findsOneWidget);
      expect(find.text('Nenhuma objeção levantada'), findsOneWidget);
      expect(find.text('0/10'), findsNothing);
      // Carro na troca `null` é "não mencionado", não "não".
      expect(find.text('Não mencionado'), findsOneWidget);
      expect(find.text('75% de conversão'), findsOneWidget);
    });

    testWidgets('o feedback é copiado com um toque', (tester) async {
      String? copiado;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (chamada) async {
          if (chamada.method == 'Clipboard.setData') {
            copiado = (chamada.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await mostrar(tester, _analise);

      await tester.ensureVisible(find.text('Copiar'));
      await tester.tap(find.text('Copiar'));
      await tester.pump();

      expect(copiado, 'Bruno, proponha a visita logo no início.');
      expect(find.text('Feedback copiado'), findsOneWidget);
    });

    testWidgets('auditoria antiga, sem nota nem critérios, não quebra', (
      tester,
    ) async {
      await mostrar(tester, {
        'qualificacao_lead': {'temperatura': 'Morno'},
        'nota_geral': null,
        'probabilidade_conversao': 40,
      });
      expect(
        find.textContaining('Sem nota (auditoria antiga)'),
        findsOneWidget,
      );
      expect(find.text('—'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('histórico: variação da nota e selo de feedback entregue', (
      tester,
    ) async {
      ResumoAuditoria resumo(int id, double? nota, {String? entregue}) =>
          ResumoAuditoria.deJson({
            'id': id,
            'criado_em': '2026-09-20T10:00:00-03:00',
            'vendedor_nome': 'Bruno',
            'temperatura': 'Quente',
            'estagio_jornada': 'Negociação',
            'probabilidade_conversao': 70,
            'nota_geral': nota,
            'feedback_entregue_em': entregue,
          });
      await tester.pumpWidget(
        app(
          Column(
            children: [
              ItemHistorico(
                resumo(2, 8, entregue: '2026-09-21T09:00:00-03:00'),
                anterior: resumo(1, 6.5),
              ),
              ItemHistorico(resumo(1, null)),
            ],
          ),
        ),
      );
      expect(find.text('↑ +1,5 desde a anterior'), findsOneWidget);
      expect(find.text('feedback entregue'), findsOneWidget);
      expect(find.text('sem nota (auditoria antiga)'), findsOneWidget);
    });
  });

  group('desempenho', () {
    testWidgets('ranking: vendedor sem nota aparece sem posição e com "—"', (
      tester,
    ) async {
      final itens = [
        ItemRanking.deJson({
          'posicao': 1,
          'vendedor_id': 1,
          'vendedor_nome': 'Ana',
          'ativo': true,
          'leads_auditados': 4,
          'nota_media': 8.3,
          'notas_criterios': {'agilidade': 9.0, 'contorno_objecoes': null},
          'probabilidade_media': 62.5,
          'atendimento': null,
        }),
        ItemRanking.deJson({
          'posicao': null,
          'vendedor_id': 2,
          'vendedor_nome': 'Caio',
          'ativo': false,
          'leads_auditados': 0,
          'nota_media': null,
          'notas_criterios': <String, dynamic>{},
          'probabilidade_media': null,
          'atendimento': null,
        }),
      ];
      await tester.pumpWidget(
        app(ListView(children: [for (final i in itens) ItemRankingCartao(i)])),
      );

      expect(find.text('1º'), findsOneWidget);
      expect(find.text('8,3'), findsOneWidget);
      expect(find.text('inativo'), findsOneWidget);
      // Caio: sem posição e sem nota.
      expect(find.text('—'), findsNWidgets(2));

      // Os critérios abrem sob demanda; o nulo aparece como "—".
      await tester.tap(find.byTooltip('Mostrar os critérios').first);
      await tester.pump();
      expect(find.text('Contorno de objeções'), findsOneWidget);
      expect(find.text('9,0'), findsOneWidget);
    });

    testWidgets('evolução: período sem nota quebra a linha (não vira zero)', (
      tester,
    ) async {
      final pontos = [
        for (final (inicio, nota) in [
          ('2026-09-07', 6.0),
          ('2026-09-14', null),
          ('2026-09-21', 8.0),
        ])
          PontoEvolucao.deJson({
            'inicio': inicio,
            'auditorias': nota == null ? 0 : 2,
            'nota_media': nota,
            'notas_criterios': <String, dynamic>{},
          }),
      ];
      await tester.pumpWidget(app(GraficoEvolucao(pontos)));

      final grafico = tester.widget<LineChart>(find.byType(LineChart));
      final spots = grafico.data.lineBarsData.single.spots;
      expect(spots, hasLength(3));
      expect(spots[0].y, 6.0);
      expect(spots[1].isNull(), isTrue);
      expect(spots[2].y, 8.0);
    });

    testWidgets('pontos de melhoria: resultado salvo e nenhum no período', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          PontosMelhoriaView(
            PontosMelhoria.deJson({
              'auditorias_consideradas': 5,
              'pontos': [
                {
                  'titulo': 'Demora no retorno',
                  'descricao': 'Responde tarde',
                  'ocorrencias': 3,
                  'sugestao': 'Treinar rotina de retorno',
                },
              ],
              'gerado_em': '2026-09-30T10:00:00-03:00',
              'do_cache': true,
            }),
          ),
        ),
      );
      expect(find.text('apareceu em 3 de 5 auditorias'), findsOneWidget);
      expect(find.textContaining('resultado salvo'), findsOneWidget);

      await tester.pumpWidget(
        app(
          PontosMelhoriaView(
            PontosMelhoria.deJson({'auditorias_consideradas': 0, 'pontos': []}),
          ),
        ),
      );
      expect(
        find.text('Não há auditorias do vendedor no período.'),
        findsOneWidget,
      );
    });
  });

  group('diálogo do QR code', () {
    const indisponivel = ApiException(
      status: 503,
      codigo: 'QRCODE_INDISPONIVEL',
    );
    const conectada = ApiException(
      status: 409,
      codigo: 'INSTANCIA_JA_CONECTADA',
    );

    Future<void> abrir(
      WidgetTester tester,
      _RepoQr repo, {
      Duration prazo = const Duration(minutes: 2),
    }) => tester.pumpWidget(
      app(
        DialogoQr(
          repo: repo,
          instanciaId: 'abc',
          vendedorNome: 'Bruno',
          prazo: prazo,
        ),
      ),
    );

    testWidgets('200 → 503 → 409: mostra o QR e para sozinho ao conectar', (
      tester,
    ) async {
      final repo = _RepoQr([pngMinimo, indisponivel, conectada]);
      await abrir(tester, repo);
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(find.textContaining('Aparelhos conectados'), findsOneWidget);
      expect(find.textContaining('Evolution Manager'), findsOneWidget);

      // 503: continua consultando, sem apagar o QR.
      await tester.pump(const Duration(seconds: 2));
      expect(repo.consultas, 2);
      expect(find.byType(Image), findsOneWidget);

      // 409: no fluxo do QR, é o sucesso.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('WhatsApp conectado!'), findsOneWidget);
      expect(find.text('+55 (48) 99999-0000'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      expect(repo.consultas, 3, reason: 'parou de consultar');
    });

    testWidgets('sem QR ainda (503): mostra "Gerando QR code…"', (
      tester,
    ) async {
      final repo = _RepoQr([indisponivel]);
      await abrir(tester, repo);
      await tester.pump();
      expect(find.text('Gerando QR code…'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('passou do prazo sem conectar: oferece gerar um QR novo', (
      tester,
    ) async {
      final repo = _RepoQr([pngMinimo]);
      await abrir(tester, repo, prazo: Duration.zero);
      await tester.pump();

      expect(find.text('Gerar novo QR code'), findsOneWidget);
      expect(repo.consultas, 0);

      await tester.tap(find.text('Gerar novo QR code'));
      await tester.pump();
      expect(repo.reconexoes, 1);
      await tester.pumpWidget(const SizedBox());
    });
  });

  test('horário comercial: valida HH:MM e início antes do fim', () {
    expect(
      validarHorario({
        'seg': [
          ['08:00', '12:00'],
          ['13:00', '18:00'],
        ],
        'dom': [],
      }),
      isNull,
    );
    expect(
      validarHorario({
        'ter': [
          ['13:00', '12:00'],
        ],
      }),
      contains('Terça'),
    );
    expect(
      validarHorario({
        'sab': [
          ['8h', '12:00'],
        ],
      }),
      contains('HH:MM'),
    );
  });
}
