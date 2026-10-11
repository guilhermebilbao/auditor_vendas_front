# Auditor de Vendas — app do gerente (Flutter)

App mobile (Android e iOS) do painel do gerente comercial. Consome a API `/api/v1` do backend
[`auditor_vendas`](../auditor_vendas) e segue as specs `doc/frontend/F00` a `F08` de lá.

## Rodar

```bash
flutter run                                               # emulador Android: backend em http://10.0.2.2:8088
flutter run --dart-define=API_URL=http://192.168.0.10:8088   # celular na rede: IP da máquina do backend
```

Sem `API_URL`, o app usa o backend local (`10.0.2.2:8088` no emulador Android, `localhost:8088` nos demais).

Os links de convite, de senha e de cadastro abrem o app pelo esquema `auditorvendas://app/...`
(`APP_PUBLIC_URL=auditorvendas://app` no `.env` do backend). Na tela de login também dá para colar o link
recebido em "Recebi um link por e-mail".

O cadastro de loja pelo app (spec 19) só funciona com o autocadastro ligado no backend (`PAGAMENTOS_GATEWAY`).
Os links dos termos aparecem no formulário e são definidos na compilação:

```bash
flutter run --dart-define=URL_TERMOS=https://.../termos --dart-define=URL_PRIVACIDADE=https://.../privacidade \
            --dart-define=VERSAO_TERMOS=2026-10
```

## Gerar o app (Android)

O `applicationId` é `com.emplakey.app`: a Play Store não deixa trocar depois de publicar.

**Chave de release (uma vez só).** Guarde o arquivo `.jks` e as senhas fora do repositório e com
cópia de segurança: sem eles, não dá para publicar atualizações com o mesmo app.

```bash
keytool -genkey -v -keystore ~/emplakey-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias emplakey
```

E o `android/key.properties` (já está no `.gitignore`):

```properties
storeFile=/home/<usuario>/emplakey-release.jks
storePassword=...
keyAlias=emplakey
keyPassword=...
```

Sem o `key.properties`, o release sai assinado com a chave de debug: serve para testar no aparelho,
não para distribuir.

**Build de produção:**

```bash
flutter build apk --release \
  --dart-define=API_URL=https://api.seudominio.com.br \
  --dart-define=URL_TERMOS=https://.../termos --dart-define=URL_PRIVACIDADE=https://.../privacidade
# APK em build/app/outputs/flutter-apk/app-release.apk (para mandar direto aos convidados)
# Para a Play Store: flutter build appbundle --release com os mesmos --dart-define
```

Suba o `version` do `pubspec.yaml` (o número depois do `+` é o `versionCode`) a cada versão distribuída.

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
