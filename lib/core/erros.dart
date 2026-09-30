import 'api/api_exception.dart';
import 'formatos.dart';

/// Mensagem ao usuário a partir do código da API (tabela da F07).
String mensagemDoErro(Object erro) {
  if (erro is! ApiException) return 'Erro inesperado no aplicativo.';
  final suporte = erro.requestId == null
      ? ''
      : ' Código de suporte: ${erro.requestId}.';

  switch (erro.codigo) {
    case ApiException.semConexao:
      return 'Sem conexão com o servidor.';
    case ApiException.tempoEsgotado:
      return 'O servidor demorou para responder.';
    case 'NAO_AUTENTICADO':
    case 'TOKEN_EXPIRADO':
      return 'Sua sessão expirou. Entre de novo.';
    case 'CREDENCIAIS_INVALIDAS':
      return 'E-mail ou senha incorretos.';
    case 'USUARIO_BLOQUEADO':
      final ate = DateTime.tryParse('${erro.detalhes['bloqueado_ate']}');
      return ate == null
          ? 'Muitas tentativas. Tente de novo em alguns minutos.'
          : 'Muitas tentativas. Tente de novo às ${formatarHora(ate)}.';
    case 'SEM_PERMISSAO':
      return 'Você não tem permissão para esta ação.';
    case 'LIMITE_EXCEDIDO':
      return 'Muitas solicitações em pouco tempo. Aguarde um minuto.';
    case 'REQUISICAO_INVALIDA':
    case 'CAMPO_OBRIGATORIO':
    case 'SENHA_FRACA':
    case 'JA_EXISTE':
      return erro.mensagem.isEmpty
          ? 'Confira os dados informados.'
          : erro.mensagem;
    case 'JSON_INVALIDO':
    case 'CURSOR_INVALIDO':
    case 'CORPO_MUITO_GRANDE':
      return 'Não foi possível processar a solicitação.';
    case 'TOKEN_SENHA_INVALIDO':
      return 'Este link expirou ou já foi usado.';
    case 'ROTA_NAO_ENCONTRADA':
    case 'METODO_NAO_PERMITIDO':
      return 'Erro no aplicativo.';
    case 'LEAD_NAO_ENCONTRADO':
      return 'Este lead não existe mais (pode ter sido excluído).';
    case 'LEAD_SEM_MENSAGENS':
      return 'Ainda não há mensagens para auditar.';
    case 'VENDEDOR_NAO_ENCONTRADO':
    case 'INSTANCIA_NAO_ENCONTRADA':
    case 'AUDITORIA_NAO_ENCONTRADA':
    case 'USUARIO_NAO_ENCONTRADO':
      return 'Registro não encontrado.';
    case 'VENDEDOR_INATIVO':
      return 'Reative o vendedor antes de conectar o WhatsApp.';
    case 'INSTANCIA_JA_ATIVA':
      return 'Este vendedor já tem um WhatsApp conectado ou pendente.';
    case 'INSTANCIA_JA_CONECTADA':
      return 'WhatsApp conectado!';
    case 'INSTANCIA_INDISPONIVEL':
      return 'Esta conexão foi removida ou deu erro. Crie uma nova.';
    case 'QRCODE_INDISPONIVEL':
      return 'Gerando QR code…';
    case 'EVOLUTION_INDISPONIVEL':
      return 'O serviço de WhatsApp não respondeu.';
    case 'IA_INDISPONIVEL':
      return 'A análise por IA está indisponível no momento.';
    case 'IA_RESPOSTA_INVALIDA':
      return 'A IA não conseguiu concluir a análise.';
    case 'IA_TIMEOUT':
      return 'A análise demorou demais.';
    case 'BANCO_INDISPONIVEL':
    case 'ERRO_INTERNO':
      return 'Erro no servidor.$suporte';
    default:
      return 'Erro inesperado (${erro.codigo}).$suporte';
  }
}

const _repetiveis = {
  ApiException.semConexao,
  ApiException.tempoEsgotado,
  'LIMITE_EXCEDIDO',
  'EVOLUTION_INDISPONIVEL',
  'IA_INDISPONIVEL',
  'IA_RESPOSTA_INVALIDA',
  'IA_TIMEOUT',
  'BANCO_INDISPONIVEL',
  'ERRO_INTERNO',
  ApiException.desconhecido,
};

/// Se a tela deve oferecer "Tentar de novo" para este erro.
bool podeTentarDeNovo(Object erro) =>
    erro is! ApiException || _repetiveis.contains(erro.codigo);
