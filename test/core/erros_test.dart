import 'package:auditor_vendas_front/core/api/api_exception.dart';
import 'package:auditor_vendas_front/core/erros.dart';
import 'package:flutter_test/flutter_test.dart';

/// Os 33 códigos do contrato (`api/erros.go` do backend).
const _codigosDoContrato = [
  'REQUISICAO_INVALIDA',
  'JSON_INVALIDO',
  'CAMPO_OBRIGATORIO',
  'CURSOR_INVALIDO',
  'CORPO_MUITO_GRANDE',
  'NAO_AUTENTICADO',
  'TOKEN_EXPIRADO',
  'CREDENCIAIS_INVALIDAS',
  'USUARIO_BLOQUEADO',
  'SEM_PERMISSAO',
  'ROTA_NAO_ENCONTRADA',
  'METODO_NAO_PERMITIDO',
  'LEAD_NAO_ENCONTRADO',
  'LEAD_SEM_MENSAGENS',
  'VENDEDOR_NAO_ENCONTRADO',
  'INSTANCIA_NAO_ENCONTRADA',
  'AUDITORIA_NAO_ENCONTRADA',
  'USUARIO_NAO_ENCONTRADO',
  'TOKEN_SENHA_INVALIDO',
  'JA_EXISTE',
  'VENDEDOR_INATIVO',
  'INSTANCIA_JA_ATIVA',
  'INSTANCIA_JA_CONECTADA',
  'INSTANCIA_INDISPONIVEL',
  'SENHA_FRACA',
  'LIMITE_EXCEDIDO',
  'ERRO_INTERNO',
  'IA_INDISPONIVEL',
  'IA_RESPOSTA_INVALIDA',
  'IA_TIMEOUT',
  'EVOLUTION_INDISPONIVEL',
  'QRCODE_INDISPONIVEL',
  'BANCO_INDISPONIVEL',
];

void main() {
  test('todos os códigos do contrato e os locais têm mensagem própria', () {
    expect(_codigosDoContrato, hasLength(33));
    for (final codigo in [
      ..._codigosDoContrato,
      ApiException.semConexao,
      ApiException.tempoEsgotado,
    ]) {
      final mensagem = mensagemDoErro(ApiException(codigo: codigo));
      expect(mensagem, isNotEmpty, reason: codigo);
      expect(mensagem, isNot(contains('Erro inesperado')), reason: codigo);
    }
  });

  test(
    'código desconhecido cai na mensagem genérica com o código de suporte',
    () {
      final mensagem = mensagemDoErro(
        const ApiException(codigo: 'CODIGO_NOVO', requestId: 'abc123'),
      );
      expect(mensagem, contains('CODIGO_NOVO'));
      expect(mensagem, contains('abc123'));
    },
  );

  test('erro interno mostra o X-Request-ID como código de suporte', () {
    expect(
      mensagemDoErro(
        const ApiException(codigo: 'ERRO_INTERNO', requestId: 'req-9'),
      ),
      'Erro no servidor. Código de suporte: req-9.',
    );
  });

  test('bloqueio mostra o horário em que dá para tentar de novo', () {
    expect(
      mensagemDoErro(
        const ApiException(
          codigo: 'USUARIO_BLOQUEADO',
          detalhes: {'bloqueado_ate': '2026-09-30T14:45:00-03:00'},
        ),
      ),
      'Muitas tentativas. Tente de novo às 14:45.',
    );
  });

  test('a mensagem da API só é usada nos erros de formulário', () {
    const texto = 'senha deve ter no mínimo 10 caracteres';
    expect(
      mensagemDoErro(
        const ApiException(codigo: 'SENHA_FRACA', mensagem: texto),
      ),
      texto,
    );
    expect(
      mensagemDoErro(
        const ApiException(codigo: 'IA_TIMEOUT', mensagem: 'texto interno'),
      ),
      'A análise demorou demais.',
    );
  });

  test(
    '"Tentar de novo" só aparece para o que pode dar certo na repetição',
    () {
      expect(
        podeTentarDeNovo(const ApiException(codigo: 'IA_TIMEOUT')),
        isTrue,
      );
      expect(
        podeTentarDeNovo(const ApiException(codigo: ApiException.semConexao)),
        isTrue,
      );
      expect(
        podeTentarDeNovo(const ApiException(codigo: 'LEAD_SEM_MENSAGENS')),
        isFalse,
      );
      expect(
        podeTentarDeNovo(const ApiException(codigo: 'SEM_PERMISSAO')),
        isFalse,
      );
    },
  );
}
