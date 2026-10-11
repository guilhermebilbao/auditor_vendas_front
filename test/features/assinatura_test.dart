import 'package:auditor_vendas_front/core/api/api_exception.dart';
import 'package:auditor_vendas_front/core/api/cliente_api.dart';
import 'package:auditor_vendas_front/core/documento.dart';
import 'package:auditor_vendas_front/core/erros.dart';
import 'package:auditor_vendas_front/core/sessao/armazenamento_token.dart';
import 'package:auditor_vendas_front/core/sessao/modelos.dart';
import 'package:auditor_vendas_front/core/sessao/sessao.dart';
import 'package:auditor_vendas_front/features/assinatura/assinatura_repo.dart';
import 'package:auditor_vendas_front/features/assinatura/loja_inativa_tela.dart';
import 'package:auditor_vendas_front/features/auth/cadastro_tela.dart';
import 'package:auditor_vendas_front/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../apoio.dart';

/// Sessão cuja loja está no [estado] informado.
Map<String, dynamic> _sessaoNoEstado(
  String estado, {
  String? inadimplente,
  String? trialAte,
  String papel = 'admin',
}) {
  final s = sessaoJson('1', DateTime.now().add(const Duration(hours: 1)));
  s['loja'] = {
    ...s['loja'] as Map<String, dynamic>,
    'estado': estado,
    'inadimplente_desde': inadimplente,
    'trial_ate': trialAte,
  };
  s['usuario'] = {...s['usuario'] as Map<String, dynamic>, 'papel': papel};
  return s;
}

void main() {
  group('CPF e CNPJ', () {
    test('valida pelos dígitos verificadores, com ou sem máscara', () {
      expect(documentoValido('529.982.247-25'), isTrue);
      expect(documentoValido('52998224725'), isTrue);
      expect(documentoValido('11.222.333/0001-81'), isTrue);
      expect(documentoValido('529.982.247-24'), isFalse);
      expect(documentoValido('111.111.111-11'), isFalse);
      expect(documentoValido('11.222.333/0001-82'), isFalse);
      expect(documentoValido('123'), isFalse);
    });

    test('máscara muda de CPF para CNPJ no 12º dígito', () {
      expect(formatarDocumento('5299822'), '529.982.2');
      expect(formatarDocumento('52998224725'), '529.982.247-25');
      expect(formatarDocumento('112223330001'), '11.222.333/0001');
      expect(formatarDocumento('11222333000181999'), '11.222.333/0001-81');
    });
  });

  test('loja sem estado (backend antigo) está ativa', () {
    final loja = Loja.deJson({'id': 'x', 'nome': 'X'});
    expect(loja.estado, EstadoLoja.ativa);
    expect(loja.bloqueada, isFalse);
    expect(Loja.deJson({'estado': 'aguardando_pagamento'}).bloqueada, isTrue);
    expect(Loja.deJson({'estado': 'em_revisao'}).bloqueada, isTrue);
    expect(Loja.deJson({'estado': 'suspensa'}).bloqueada, isFalse);
  });

  group('teste grátis (spec 20)', () {
    test('trial navega; trial encerrado fica bloqueado', () {
      final trial = Loja.deJson({
        'estado': 'trial',
        'trial_ate': '2026-10-17T10:00:00-03:00',
      });
      expect(trial.emTrial, isTrue);
      expect(trial.bloqueada, isFalse);
      expect(trial.trialAte, isNotNull);
      expect(Loja.deJson({'estado': 'trial_encerrado'}).bloqueada, isTrue);
    });

    test('dias que faltam na faixa', () {
      final agora = DateTime.parse('2026-10-10T12:00:00-03:00');
      String faixa(String fim) =>
          textoDiasDeTrial(DateTime.parse(fim), agora: agora);
      expect(faixa('2026-10-17T10:00:00-03:00'), 'Teste grátis: faltam 7 dias');
      expect(faixa('2026-10-11T23:00:00-03:00'), 'Teste grátis: falta 1 dia');
      expect(faixa('2026-10-10T23:00:00-03:00'), 'Último dia do teste grátis');
    });

    test('cotas da assinatura e mensagens', () {
      final a = Assinatura.deJson({
        'estado': 'trial',
        'plano': {'nome': 'Padrão', 'max_instancias': 7},
        'trial_ate': '2026-10-17T10:00:00-03:00',
        'auditorias_restantes_hoje': 0,
        'transcricoes_restantes_hoje': 25,
      });
      expect(a.trialAte, isNotNull);
      expect(a.auditoriasRestantesHoje, 0);
      expect(a.transcricoesRestantesHoje, 25);
      expect(
        mensagemDoErro(
          const ApiException(
            codigo: 'COTA_TRIAL_ESGOTADA',
            detalhes: {'recurso': 'auditoria', 'limite': 1},
          ),
        ),
        'No teste grátis, dá para fazer 1 auditoria por dia. A próxima fica '
        'liberada amanhã.',
      );
      expect(
        mensagemDoErro(
          const ApiException(
            codigo: 'LOJA_INATIVA',
            detalhes: {'estado': 'trial_encerrado'},
          ),
        ),
        contains('teste grátis terminou'),
      );
    });
  });

  test('mensagens dos códigos novos (F07)', () {
    expect(
      mensagemDoErro(
        const ApiException(
          codigo: 'LOJA_INATIVA',
          detalhes: {'estado': 'suspensa'},
        ),
      ),
      contains('suspensa'),
    );
    expect(
      mensagemDoErro(const ApiException(codigo: 'LOJA_CANCELADA')),
      'A assinatura desta loja foi cancelada.',
    );
    expect(
      mensagemDoErro(const ApiException(codigo: 'CADASTRO_INDISPONIVEL')),
      contains('suporte'),
    );
  });

  test('assinatura de loja de contrato vem sem plano', () {
    final a = Assinatura.deJson({
      'estado': 'ativa',
      'plano': null,
      'proxima_cobranca': null,
      'inadimplente_desde': null,
      'motivo_suspensao': null,
    });
    expect(a.planoNome, isNull);
    final b = Assinatura.deJson({
      'estado': 'suspensa',
      'plano': {'nome': 'Padrão', 'max_instancias': 10},
      'proxima_cobranca': '2026-11-08',
      'motivo_suspensao': 'inadimplencia',
    });
    expect(b.planoMaxInstancias, 10);
    expect(b.proximaCobranca, DateTime(2026, 11, 8));
  });

  group('sessão', () {
    ClienteApi criar(ResponseBody Function(RequestOptions) responder) =>
        ClienteApi(
          armazenamento: ArmazenamentoMemoria(),
          urlBase: 'http://teste',
          adaptador: AdaptadorFalso(responder),
        );

    test('403 LOJA_INATIVA avisa a sessão; 403 de permissão não', () async {
      final api = criar(
        (req) => switch (req.uri.path) {
          final p when p.endsWith('/cadastro/confirmar') => respostaJson(
            200,
            _sessaoNoEstado('ativa'),
          ),
          final p when p.endsWith('/leads') => respostaJson(403, {
            'erro': '',
            'codigo': 'LOJA_INATIVA',
            'detalhes': {'estado': 'suspensa'},
          }),
          _ => respostaErro(403, 'SEM_PERMISSAO'),
        },
      );
      final avisos = <String>[];
      api.sessao.aoLojaInativa = avisos.add;

      await api.sessao.confirmarCadastro('token', 'senha-forte-123');
      await expectLater(api.get('/leads'), throwsA(isA<ApiException>()));
      await expectLater(api.get('/usuarios'), throwsA(isA<ApiException>()));
      expect(avisos, ['LOJA_INATIVA']);
    });

    test('confirmar o cadastro já entra, sem token de acesso na ida', () async {
      late RequestOptions pedido;
      final api = criar((req) {
        pedido = req;
        return respostaJson(200, _sessaoNoEstado('aguardando_pagamento'));
      });
      final sessao = await api.sessao.confirmarCadastro('abc', 'senha-123456');
      expect(pedido.headers['Authorization'], isNull);
      expect(pedido.data, {'token': 'abc', 'senha': 'senha-123456'});
      expect(sessao.loja.bloqueada, isTrue);
      expect(await api.sessao.armazenamento.ler(), 'refresh-1');
    });
  });

  group('guarda de rotas', () {
    Future<void> abrirApp(WidgetTester tester, Map<String, dynamic> sessao) {
      final api = ClienteApi(
        armazenamento: ArmazenamentoMemoria('refresh-0'),
        urlBase: 'http://teste',
        adaptador: AdaptadorFalso(
          (req) => req.uri.path.endsWith('/assinatura')
              ? respostaJson(200, {
                  'estado': 'suspensa',
                  'plano': {'nome': 'Padrão', 'max_instancias': 10},
                  'motivo_suspensao': 'inadimplencia',
                })
              : respostaJson(200, sessao),
        ),
      );
      return tester.pumpWidget(
        ProviderScope(
          overrides: [clienteApiProvider.overrideWithValue(api)],
          child: const App(),
        ),
      );
    }

    testWidgets(
      'loja aguardando pagamento só vê a tela de pagamento pendente',
      (tester) async {
        await abrirApp(tester, _sessaoNoEstado('aguardando_pagamento'));
        await tester.pumpAndSettle();
        expect(find.text('Pagamento pendente'), findsOneWidget);
        expect(find.text('Reenviar link de pagamento'), findsOneWidget);
        expect(find.text('Já paguei: atualizar'), findsOneWidget);
      },
    );

    testWidgets('loja em análise não oferece reenviar o link', (tester) async {
      await abrirApp(tester, _sessaoNoEstado('em_revisao'));
      await tester.pumpAndSettle();
      expect(find.text('Loja em análise'), findsOneWidget);
      expect(find.text('Reenviar link de pagamento'), findsNothing);
    });

    testWidgets('trial encerrado: admin vê "Quero assinar"', (tester) async {
      await abrirApp(tester, _sessaoNoEstado('trial_encerrado'));
      await tester.pumpAndSettle();
      expect(find.text('Seu teste grátis terminou'), findsOneWidget);
      expect(find.text('Quero assinar'), findsOneWidget);
      expect(find.text('Já paguei: atualizar'), findsOneWidget);
    });

    testWidgets('trial encerrado: gerente é orientado a pedir ao admin', (
      tester,
    ) async {
      await abrirApp(
        tester,
        _sessaoNoEstado('trial_encerrado', papel: 'gerente'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Seu teste grátis terminou'), findsOneWidget);
      expect(find.text('Quero assinar'), findsNothing);
      expect(
        find.text('Peça ao administrador da loja para concluir a assinatura.'),
        findsOneWidget,
      );
    });

    testWidgets('trial navega com a faixa do teste grátis', (tester) async {
      final fim = DateTime.now().add(const Duration(days: 3, hours: 1));
      await abrirApp(
        tester,
        _sessaoNoEstado('trial', trialAte: fim.toUtc().toIso8601String()),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Teste grátis: falta'), findsOneWidget);
      expect(find.text('Seu teste grátis terminou'), findsNothing);
    });

    testWidgets('Mais mostra os dias que faltam no teste grátis', (
      tester,
    ) async {
      final fim = DateTime.now().add(const Duration(days: 3, hours: 1));
      await abrirApp(
        tester,
        _sessaoNoEstado('trial', trialAte: fim.toUtc().toIso8601String()),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Mais'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // A faixa e a linha da tela Mais.
      expect(find.textContaining('Teste grátis: falta'), findsNWidgets(2));
      expect(find.textContaining('Toque para assinar'), findsOneWidget);
    });

    testWidgets('loja suspensa navega com a faixa fixa', (tester) async {
      await abrirApp(
        tester,
        _sessaoNoEstado('suspensa', inadimplente: '2026-10-01T10:00:00-03:00'),
      );
      // O painel consulta a API periodicamente: sem pumpAndSettle.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.text('Assinatura suspensa: dados só para consulta.'),
        findsOneWidget,
      );
      expect(find.text('Pagamento pendente'), findsNothing);
    });
  });

  testWidgets('cadastro: valida os campos e exige o aceite', (tester) async {
    await tester.pumpWidget(app(const CadastroTela()));
    final botao = find.widgetWithText(FilledButton, 'Criar conta');
    await tester.ensureVisible(botao);
    await tester.tap(botao);
    await tester.pump();
    expect(find.text('Informe o nome da loja'), findsOneWidget);
    expect(find.text('Informe um e-mail válido'), findsOneWidget);
    expect(find.text('CPF ou CNPJ inválido'), findsOneWidget);
    expect(find.text('É preciso aceitar para continuar'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'CPF ou CNPJ'),
      '52998224725',
    );
    expect(find.text('529.982.247-25'), findsOneWidget);
  });

  test('texto de cada estado', () {
    expect(
      textoDoEstado('suspensa', motivoSuspensao: 'estorno').$2,
      contains('estornado'),
    );
    expect(textoDoEstado('aguardando_pagamento').$1, 'Pagamento pendente');
  });
}
