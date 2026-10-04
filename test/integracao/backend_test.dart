// Integração com o backend real (F08, item 4). Não roda no `flutter test`
// comum: precisa do backend no ar e de um admin de teste.
//
//   TESTE_API_URL=http://localhost:8089 \
//   TESTE_EMAIL=admin@loja.com TESTE_SENHA='...' \
//   flutter test test/integracao
//
// Não audita nem gera pontos de melhoria: essas rotas gastam tokens da IA.
@Tags(['integracao'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:auditor_vendas_front/core/api/api_exception.dart';
import 'package:auditor_vendas_front/core/api/cliente_api.dart';
import 'package:auditor_vendas_front/core/formatos.dart';
import 'package:auditor_vendas_front/core/sessao/armazenamento_token.dart';
import 'package:auditor_vendas_front/core/sessao/modelos.dart';
import 'package:auditor_vendas_front/features/admin/admin_repo.dart';
import 'package:auditor_vendas_front/features/auditoria/auditoria_repo.dart';
import 'package:auditor_vendas_front/features/atuacao/atuacao_repo.dart';
import 'package:auditor_vendas_front/features/atuacao/modelos.dart';
import 'package:auditor_vendas_front/features/leads/leads_repo.dart';
import 'package:auditor_vendas_front/features/leads/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final url = Platform.environment['TESTE_API_URL'];
  final email = Platform.environment['TESTE_EMAIL'];
  final senha = Platform.environment['TESTE_SENHA'];
  if (url == null || email == null || senha == null) {
    test(
      'integração com o backend',
      () {},
      skip: 'defina TESTE_API_URL, TESTE_EMAIL e TESTE_SENHA',
    );
    return;
  }

  final cofre = ArmazenamentoMemoria();
  final api = ClienteApi(armazenamento: cofre, urlBase: url);
  final leads = LeadsRepo(api);
  final auditorias = AuditoriaRepo(api);
  final atuacao = AtuacaoRepo(api);
  final admin = AdminRepo(api);
  final periodo = Periodo.deTipo('30d');

  Matcher erroApi(String codigo) =>
      isA<ApiException>().having((e) => e.codigo, 'codigo', codigo);

  test(
    'login sem diferenciar maiúsculas; senha errada não diz qual campo',
    () async {
      await expectLater(
        api.sessao.entrar(email, 'senha-errada-123'),
        throwsA(erroApi('CREDENCIAIS_INVALIDAS')),
      );
      final sessao = await api.sessao.entrar(email.toUpperCase(), senha);
      expect(sessao.usuario.email, email.toLowerCase());
      expect(sessao.usuario.papel, anyOf('admin', 'gerente'));
      expect(sessao.expiraEm.isAfter(DateTime.now()), isTrue);
      expect(cofre.valor, sessao.refreshToken);
    },
  );

  test('refresh com rotação: o token anterior deixa de valer', () async {
    final anterior = cofre.valor!;
    final nova = await api.sessao.renovar();
    expect(nova.refreshToken, isNot(anterior));

    final outro = ClienteApi(
      armazenamento: ArmazenamentoMemoria(anterior),
      urlBase: url,
    );
    await expectLater(
      outro.sessao.restaurar(),
      throwsA(erroApi('NAO_AUTENTICADO')),
    );
  });

  test('GET /me traz a loja com SLA, horário e pesos', () async {
    final json = (await api.get('/me')).data as Map;
    final loja = Loja.deJson(Map<String, dynamic>.from(json['loja'] as Map));
    expect(loja.nome, isNotEmpty);
    expect(loja.slaRespostaMin, inInclusiveRange(1, 1440));
    expect(loja.pesosCriterios.keys, containsAll(criterios.keys));
    expect(loja.horarioComercial.keys, everyElement(isIn(diasDaSemana)));
  });

  test('rota inexistente e esqueci-senha (sempre 204)', () async {
    await expectLater(
      api.get('/nao-existe'),
      throwsA(erroApi('ROTA_NAO_ENCONTRADA')),
    );
    final r = await api.post(
      '/auth/esqueci-senha',
      corpo: {'email': 'ninguem@exemplo.invalid'},
      publica: true,
    );
    expect(r.statusCode, 204);
    await expectLater(
      api.post(
        '/auth/definir-senha',
        corpo: {'token': 'token-invalido', 'senha': 'umaSenhaBemLonga1'},
        publica: true,
      ),
      throwsA(erroApi('TOKEN_SENHA_INVALIDO')),
    );
  });

  group('leads e conversa', () {
    late Lead lead;

    test('lista, filtros e atualizados_desde', () async {
      final pagina = await leads.listar(const FiltrosLeads());
      expect(pagina.itens, isNotEmpty, reason: 'semeie mensagens antes');
      lead = pagina.itens.firstWhere((l) => l.totalMensagens > 2);
      expect(lead.nome, isNotEmpty);
      expect(lead.ultimaMensagemEm, isNotNull);

      for (final filtros in const [
        FiltrosLeads(aguardandoResposta: true),
        FiltrosLeads(haMaisDe: '30m'),
        FiltrosLeads(haMaisDe: '1d'),
        FiltrosLeads(temperatura: 'sem_auditoria'),
        FiltrosLeads(temperatura: 'Quente'),
        FiltrosLeads(q: 'zzzz-nao-existe'),
        FiltrosLeads(desde: '2026-01-01', ate: '2030-01-01'),
      ]) {
        final r = await leads.listar(filtros, limite: 5);
        if (filtros.aguardandoResposta) {
          expect(r.itens.map((l) => l.aguardandoResposta), everyElement(true));
        }
        if (filtros.q.isNotEmpty) expect(r.itens, isEmpty);
      }

      final doVendedor = await leads.listar(
        FiltrosLeads(vendedorId: lead.vendedorId),
      );
      expect(
        doVendedor.itens.map((l) => l.vendedorId),
        everyElement(lead.vendedorId),
      );

      final recentes = await leads.listar(
        const FiltrosLeads(),
        atualizadosDesde: DateTime.now().add(const Duration(minutes: 5)),
      );
      expect(recentes.itens, isEmpty);
    });

    test('paginação: limit=1 percorre a lista sem repetir', () async {
      final vistos = <int>{};
      String? cursor;
      do {
        final p = await leads.listar(
          const FiltrosLeads(),
          limite: 1,
          cursor: cursor,
        );
        for (final l in p.itens) {
          expect(vistos.add(l.id), isTrue, reason: 'lead ${l.id} repetido');
        }
        cursor = p.proximoCursor;
      } while (cursor != null && vistos.length < 50);
      expect(vistos.length, greaterThan(1));
    });

    test('detalhe, métricas e histórico do lead', () async {
      final detalhe = await leads.detalhe(lead.id);
      expect(detalhe.lead.id, lead.id);
      expect(detalhe.outrosLeads.map((o) => o.id), isNot(contains(lead.id)));

      final m = await leads.metricas(lead.id);
      expect(m.slaRespostaSeg, greaterThan(0));
      expect(
        m.totalMensagensLead + m.totalMensagensVendedor,
        detalhe.lead.totalMensagens,
      );

      final historico = await auditorias.historico(lead.id);
      for (final a in historico) {
        final completa = await auditorias.buscar(a.id);
        expect(completa.leadId, lead.id);
      }

      await expectLater(
        leads.detalhe(999999999),
        throwsA(erroApi('LEAD_NAO_ENCONTRADO')),
      );
    });

    test('conversa: ordem cronológica, histórico, novidades e ?ids=', () async {
      final primeira = await leads.mensagens(lead.id, limite: 2);
      expect(primeira.itens, hasLength(2));
      expect(primeira.ultimoCursor, isNotNull);
      expect(
        primeira.itens.first.enviadaEm.isAfter(primeira.itens.last.enviadaEm),
        isFalse,
        reason: 'a mais antiga primeiro',
      );

      final antigas = await leads.mensagens(
        lead.id,
        limite: 100,
        antes: primeira.proximoCursor,
      );
      expect(antigas.itens, isNotEmpty);
      expect(
        antigas.itens.last.enviadaEm.isAfter(primeira.itens.first.enviadaEm),
        isFalse,
      );
      final ids = {...antigas.itens, ...primeira.itens}.map((m) => m.id);
      expect(ids.toSet(), hasLength(antigas.itens.length + 2));

      final novas = await leads.mensagens(
        lead.id,
        depois: primeira.ultimoCursor,
      );
      expect(novas.itens, isEmpty);
      expect(novas.ultimoCursor, isNotNull);

      final algumas = await leads.mensagens(
        lead.id,
        ids: [primeira.itens.first.id],
      );
      expect(algumas.itens.single.id, primeira.itens.first.id);

      final todas = [...antigas.itens, ...primeira.itens];
      expect(
        todas.map((m) => m.autor),
        everyElement(isIn(['lead', 'vendedor'])),
      );
      expect(
        todas.map((m) => m.tipo),
        everyElement(isIn(['texto', 'audio', 'midia'])),
      );
    });

    test(
      'exportação (admin) devolve JSON com lead, mensagens e auditorias',
      () async {
        final json = jsonDecode(await leads.exportar(lead.id)) as Map;
        expect(json.keys, containsAll(['lead', 'mensagens', 'auditorias']));
      },
    );
  });

  group('atuação (sem IA)', () {
    test('métricas agregadas e por vendedor', () async {
      final m = await atuacao.metricas(desde: periodo.desde, ate: periodo.ate);
      expect(m.slaRespostaSeg, greaterThan(0));
      expect(m.total.leads, greaterThanOrEqualTo(m.porVendedor.length));
      for (final g in m.porVendedor) {
        expect(g.vendedorId, isNotNull);
        expect(g.vendedorNome, isNotEmpty);
        final filtrado = await atuacao.metricas(
          desde: periodo.desde,
          ate: periodo.ate,
          vendedorId: g.vendedorId,
        );
        expect(filtrado.total.leads, g.leads);
      }
    });

    test('ranking e evolução de cada vendedor', () async {
      final ranking = await atuacao.ranking(
        desde: periodo.desde,
        ate: periodo.ate,
      );
      expect(ranking, isNotEmpty);
      // Sem nota no período: sem posição, no fim da lista.
      final semPosicao = ranking.skipWhile((i) => i.posicao != null);
      expect(semPosicao.map((i) => i.posicao), everyElement(isNull));

      final item = ranking.first;
      final vendedor = await atuacao.vendedor(item.vendedorId);
      expect(vendedor.nome, item.vendedorNome);
      for (final agrupamento in ['semana', 'mes']) {
        final pontos = await atuacao.evolucao(
          item.vendedorId,
          agrupamento: agrupamento,
        );
        for (final p in pontos) {
          expect(p.inicio, matches(r'^\d{4}-\d{2}-\d{2}$'));
        }
      }
    });
  });

  group('administração', () {
    test('vendedor: cria, edita, desativa, reativa e exclui', () async {
      final novo = await admin.criarVendedor(
        nome: 'Temporário Integração',
        telefone: '(48) 98888-7777',
      );
      expect(novo.telefone, '48988887777', reason: 'normalizado pelo backend');
      expect(novo.instancia, isNull);

      final editado = await admin.editarVendedor(novo.id, nome: 'Temp Editado');
      expect(editado.nome, 'Temp Editado');
      expect(editado.telefone, novo.telefone, reason: 'PATCH parcial');

      expect(
        (await admin.editarVendedor(novo.id, ativo: false)).ativo,
        isFalse,
      );
      await expectLater(
        admin.criarInstancia(novo.id),
        throwsA(erroApi('VENDEDOR_INATIVO')),
      );
      expect((await admin.editarVendedor(novo.id, ativo: true)).ativo, isTrue);

      final exclusao = await admin.excluirVendedor(novo.id);
      expect(exclusao.desativado, isNull, reason: 'sem leads: apagado (204)');
      await expectLater(
        admin.buscarVendedor(novo.id),
        throwsA(erroApi('VENDEDOR_NAO_ENCONTRADO')),
      );
    });

    test('vendedores trazem a instância ativa', () async {
      final lista = await admin.vendedores();
      expect(lista, isNotEmpty);
      for (final v in lista) {
        final inst = v.instancia;
        if (inst != null) expect(inst.id, isNotEmpty);
      }
    });

    test('usuários: lista; convite repetido dá JA_EXISTE', () async {
      final usuarios = await admin.usuarios();
      expect(usuarios.map((u) => u.email), contains(email.toLowerCase()));
      await expectLater(
        admin.convidar(nome: 'Repetido', email: email, papel: 'gerente'),
        throwsA(erroApi('JA_EXISTE')),
      );
    });

    test('loja: horário com pausa para o almoço volta igual', () async {
      final atual = Loja.deJson(
        Map<String, dynamic>.from(((await api.get('/me')).data as Map)['loja']),
      );
      const horario = {
        'seg': [
          ['08:00', '12:00'],
          ['13:00', '18:00'],
        ],
        'ter': [
          ['08:00', '18:00'],
        ],
        'qua': [
          ['08:00', '18:00'],
        ],
        'qui': [
          ['08:00', '18:00'],
        ],
        'sex': [
          ['08:00', '18:00'],
        ],
        'sab': [
          ['08:00', '12:00'],
        ],
        'dom': <List<String>>[],
      };
      final pesos = {...atual.pesosCriterios, 'agilidade': 2.5};
      try {
        final salva = await admin.salvarLoja(
          nome: atual.nome,
          slaRespostaMin: 20,
          retencaoMeses: atual.retencaoMeses,
          horarioComercial: horario,
          pesosCriterios: pesos,
        );
        expect(salva.slaRespostaMin, 20);
        expect(salva.horarioComercial['seg'], horario['seg']);
        expect(salva.horarioComercial['dom'], isEmpty);
        expect(salva.pesosCriterios['agilidade'], 2.5);

        final relida = Loja.deJson(
          Map<String, dynamic>.from(
            ((await api.get('/me')).data as Map)['loja'],
          ),
        );
        expect(relida.horarioComercial['seg'], horario['seg']);

        await expectLater(
          admin.salvarLoja(
            nome: atual.nome,
            slaRespostaMin: 20,
            retencaoMeses: atual.retencaoMeses,
            horarioComercial: {
              'seg': [
                ['18:00', '08:00'],
              ],
            },
            pesosCriterios: pesos,
          ),
          throwsA(erroApi('REQUISICAO_INVALIDA')),
        );
      } finally {
        await admin.salvarLoja(
          nome: atual.nome,
          slaRespostaMin: atual.slaRespostaMin,
          retencaoMeses: atual.retencaoMeses,
          horarioComercial: atual.horarioComercial,
          pesosCriterios: atual.pesosCriterios,
        );
      }
    });
  });

  test('logout invalida o refresh token', () async {
    final refresh = cofre.valor!;
    await api.sessao.sair();
    expect(cofre.valor, isNull);
    final outro = ClienteApi(
      armazenamento: ArmazenamentoMemoria(refresh),
      urlBase: url,
    );
    await expectLater(
      outro.sessao.restaurar(),
      throwsA(erroApi('NAO_AUTENTICADO')),
    );
  });
}
