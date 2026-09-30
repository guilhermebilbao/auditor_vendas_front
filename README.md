# Auditor de Vendas — app do gerente (Flutter)

App mobile (Android e iOS) do painel do gerente comercial. Consome a API `/api/v1` do backend
[`auditor_vendas`](../auditor_vendas) e segue as specs `doc/frontend/F00` a `F08` de lá.

## Rodar

```bash
flutter run                                               # emulador Android: backend em http://10.0.2.2:8088
flutter run --dart-define=API_URL=http://192.168.0.10:8088   # celular na rede: IP da máquina do backend
```

Sem `API_URL`, o app usa o backend local (`10.0.2.2:8088` no emulador Android, `localhost:8088` nos demais).

Os links de convite e de senha abrem o app pelo esquema `auditorvendas://app/definir-senha?token=...`
(`APP_PUBLIC_URL=auditorvendas://app` no `.env` do backend). Na tela de login também dá para colar o link
recebido em "Recebi um link de convite ou de senha".

## Testes

```bash
flutter test            # unitários e de widgets (servidor falso)

# Integração com o backend real (não audita: não gasta tokens da IA)
TESTE_API_URL=http://localhost:8088 TESTE_EMAIL=admin@loja.com TESTE_SENHA='...' \
  flutter test test/integracao
```

## Organização

```
lib/
  main.dart            ProviderScope e MaterialApp.router
  app/                 rotas e guardas (go_router), navegação principal, tema
  core/
    api/               cliente dio, renovação do token em fila única, ApiException, paginação
    sessao/            tokens, usuário logado, login e logout
    formatos.dart      datas no fuso da loja, durações, notas, telefone
    erros.dart         código da API -> mensagem ao usuário
    ciclo.dart         consultas periódicas (pausa em segundo plano, espera crescente na falha)
  features/
    auth/              login, esqueci a senha, definir senha, minha conta
    leads/             lista com filtros e tela do lead (conversa, métricas, LGPD)
    conversa/          conversa com novidades a cada 5s
    auditoria/         pedir a auditoria, análise, histórico e feedback
    desempenho/        painel, ranking, evolução e pontos de melhoria
    admin/             vendedores e WhatsApp (QR code), usuários, loja
  widgets/             estados de tela, selos e cartões compartilhados
```
