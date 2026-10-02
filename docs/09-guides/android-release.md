---
title: Publicação no Android
type: guide
updated: 2026-10-02
---

# Publicação no Android

O que precisa acontecer para o app sair da máquina de desenvolvimento e ir para
a Play Store. **O app nunca foi enviado à loja.**

## 1. Identificador do app

`br.com.yvenist.app`, o domínio dos donos (`yvenist.com.br`) ao contrário.
**Não pode mais mudar depois da primeira publicação.** Onde ele está em cada
plataforma: [ADR-016](../05-decisions/ADR-016-identificador-br-com-yvenist-app.md).

## 2. As duas chaves

Na Play Store um app novo tem duas chaves (ajuda do Play Console, "Play App
Signing", conferida em 2 de outubro de 2026):

| Chave | Quem guarda | Para quê |
|---|---|---|
| de assinatura do app | o Google | assina o que chega aos aparelhos |
| **de envio** (*upload key*) | **vocês** | assina o pacote que vocês enviam ao Play Console |

O projeto só lida com a chave de envio. **Ela existe desde 2 de outubro de
2026**, criada a pedido dos donos na máquina de desenvolvimento do Keven, fora
do repositório:

| O quê | Como está |
|---|---|
| Arquivo | `yvenist-upload.jks`, na pasta `yvenist-chave-de-envio` da pasta pessoal do usuário, com um `LEIA-ME.txt` ao lado. O caminho exato está em `android/key.properties`, que só existe naquela máquina |
| Chave | apelido `upload`, RSA de 2048 bits, válida até 17 de fevereiro de 2054 |
| Impressão digital do certificado (SHA-256) | `C4:CA:8C:91:B5:DC:7D:9F:34:71:AC:18:CB:08:63:C6:BD:70:D3:95:A1:81:67:AC:85:A7:B3:65:7B:B9:BE:7E`. Não é segredo: serve para conferir que o pacote foi assinado pela chave certa |
| Senhas | geradas na hora e gravadas **só** em `android/key.properties`. Não estão em nenhum outro lugar |

**Falta os donos guardarem uma cópia** do arquivo `.jks` e das duas senhas
fora daquela máquina ([KI-55](../07-known-issues/README.md)). Sem cópia, apagar
a pasta do projeto leva as senhas junto.

## 3. Criar a chave de envio

Já foi feito (acima). O comando fica registrado para o caso de uma chave nova:

```powershell
keytool -genkeypair -v -keystore C:\caminho\seguro\yvenist-upload.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

(`keytool` vem com o Android Studio, em `Android Studio\jbr\bin`.) O comando
pede duas senhas e gera um arquivo `.jks`.

| Pergunta | Resposta |
|---|---|
| Onde guardar | o arquivo `.jks` e as duas senhas em um gerenciador de senhas, com uma cópia fora da máquina. **Nunca no repositório**: `*.jks`, `*.keystore` e `android/key.properties` estão no `.gitignore` |
| Quem precisa dela | só quem gera o pacote para a loja. O CI não a usa |
| Se vazar | quem a tiver só consegue enviar uma versão se também entrar na conta do Play Console. Peça a troca da chave (abaixo) e ative a verificação em duas etapas na conta |
| Se for perdida | **o app não se perde**. Cria-se uma chave nova e pede-se a troca no Play Console (no menu em inglês: *Protected with Play → Play Store protection → Manage Play app signing → Request upload key reset*). Até a troca ser aceita, não dá para enviar atualizações |

## 4. Apontar o build para a chave

Na máquina onde a chave foi criada isso já está feito. Em outra máquina, copie
`android/key.properties.example` para `android/key.properties` e preencha:

```properties
storePassword=<senha do keystore>
keyPassword=<senha da chave>
keyAlias=upload
storeFile=C:/caminho/seguro/yvenist-upload.jks
```

## 5. Gerar o pacote

A URL da API entra no build. Em release ela **precisa ser `https`**; com outro
valor o app abre uma tela de erro de configuração em vez de funcionar pela
metade.

```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.seudominio.com/api/v1
```

O arquivo para enviar fica em
`build/app/outputs/bundle/release/app-release.aab`.

**Sem `android/key.properties` esse comando falha na hora**, dizendo o motivo
(`android/app/build.gradle.kts`): um pacote para a loja assinado com a chave de
debug seria recusado no envio. Um APK de release (`flutter build apk
--release`) continua saindo sem a chave, assinado com a de debug, para testar
na própria máquina.

Para conferir quem assinou:

```powershell
keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
```

O dono do certificado tem de ser o da chave de vocês, e não `CN=Android Debug`.

> Sem `--dart-define=API_BASE_URL` o build sai em **modo demonstração**, com
> dados de exemplo em memória. Serve para mostrar o app, não para publicar.

## 6. A cada nova versão

Aumente a versão em `pubspec.yaml` (`version: 1.0.1+2`: o número depois do `+`
tem de crescer a cada envio) e a constante `AppConfig.appVersion`, que é a
versão mostrada na tela de perfil. Um teste falha se as duas ficarem
diferentes.

## O que o projeto já garante

| Item | Onde |
|---|---|
| Permissão de internet também em release, e nenhuma outra | `android/app/src/main/AndroidManifest.xml` |
| `http` sem TLS só em debug | `android/app/src/debug/AndroidManifest.xml` |
| Backup do Google desligado (tokens e dados da conta não vão para a nuvem) | `android:allowBackup="false"` no manifesto principal |
| Tokens da sessão no Keystore | `lib/core/storage/token_storage.dart` |
| Release recusa API sem `https` | `lib/core/config/app_config.dart` |
| Chave e senhas fora do Git | `.gitignore` (`*.jks`, `*.keystore`, `android/key.properties`) |
| Pacote para a loja só com a chave de envio | `android/app/build.gradle.kts` |
| O caminho de assinatura continua funcionando | job `android` do [CI](ci.md): gera uma chave de teste, compila o pacote de release e confere quem assinou |

## O que a loja exige, e como está

Conferido na ajuda do Play Console e na documentação do Android em 2 de
outubro de 2026.

| Exigência | Estado |
|---|---|
| Mirar o Android 16 (API 36) ou mais novo, desde 31 de agosto de 2026 | atendida: o build de release mira a API 36 (é o padrão do Flutter 3.41) |
| Bibliotecas de 64 bits alinhadas em 16 KB | atendida: as seis do pacote de release foram conferidas uma a uma |
| Política de privacidade em um endereço público | **falta publicar** ([legal](../03-features/legal.md)) |
| Página pública para pedir a exclusão da conta | **falta publicar**; a página já é gerada |
| Ficha "Segurança dos dados" | o levantamento está pronto em [personal-data](../01-architecture/personal-data.md); quem preenche são os donos |
| Conta de desenvolvedor no Play Console | dos donos. Em conta **pessoal** criada depois de 13 de novembro de 2023, a loja pede um teste fechado com 12 pessoas por 14 dias seguidos antes de liberar a produção |

## Antes de publicar de verdade

- A API no ar em `https`, com `YVENIST_ENV=production` e um
  `YVENIST_JWT_SECRET` próprio ([deployment](deployment.md)).
- Os textos legais fechados, e a política de privacidade **e a página de
  exclusão de conta** em endereços públicos ([legal](../03-features/legal.md)).
  A loja exige as duas: quem cria conta pelo app tem de poder pedir a exclusão
  também sem ele.
- iOS não foi compilado neste projeto ([ios-build](ios-build.md)).

Tudo o que ainda bloqueia a publicação:
[problemas conhecidos](../07-known-issues/README.md).

## O que foi conferido

| O quê | Como | Quando |
|---|---|---|
| Build de release assinado pela chave de `key.properties`, instalado e aberto em um emulador (Android 13), com o backup desligado | chave descartável, apagada depois | 2026-10-02 |
| Pacote para a loja (`.aab`): recusa sem a chave; com uma chave de teste, compila e sai assinado por ela | na máquina de desenvolvimento; chave descartável, apagada depois | 2026-10-02 |
| Pacote para a loja assinado pela **chave de envio de verdade**, com o pacote `br.com.yvenist.app` | `keytool -printcert -jarfile` no `.aab`: a impressão digital é a da tabela da seção 2. Build em modo demonstração, só para conferir a assinatura | 2026-10-02 |
| O manifesto final de release: mínimo Android 7 (API 24), alvo API 36, só a permissão de internet | lido do build | 2026-10-02 |
| O identificador `br.com.yvenist.app` no pacote e na atividade inicial | lido do manifesto final de um APK de debug | 2026-10-02 |

**Não conferido:** o envio ao Play Console, a assinatura pelo Google, o teste
fechado.
