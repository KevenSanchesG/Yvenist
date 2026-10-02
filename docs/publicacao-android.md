# Publicação no Android

O que precisa acontecer para o app sair da máquina de desenvolvimento e ir para
a Play Store. O projeto já está preparado para os passos 2 a 4; o passo 1 é uma
decisão que ainda precisa ser tomada.

## 1. Definir o identificador do app (pendente)

O app ainda usa o identificador de exemplo do Flutter, `com.example.yvenist`.
**A Play Store não aceita `com.example`**, e o identificador não pode ser
trocado depois da primeira publicação: é ele que identifica o app para sempre.

Escolha um identificador com um domínio que seja de vocês, ao contrário (por
exemplo `br.com.yvenist.app`), e troque em três lugares:

| Arquivo | O que trocar |
|---|---|
| `android/app/build.gradle.kts` | `namespace` e `applicationId` |
| `android/app/src/main/kotlin/com/example/yvenist/MainActivity.kt` | a linha `package` e a pasta em que o arquivo fica |
| iOS: `ios/Runner.xcodeproj` (Bundle Identifier) | o mesmo identificador, para as duas lojas ficarem iguais |

Depois de trocar: `flutter clean` e `flutter build apk --debug` para conferir.

## 2. Criar a chave de publicação

Uma vez só. A chave prova que as atualizações vêm de vocês; **se ela for
perdida, não dá mais para atualizar o app**. Guarde o arquivo e as senhas em um
gerenciador de senhas, fora do repositório.

```powershell
keytool -genkeypair -v -keystore C:\caminho\seguro\yvenist-upload.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

(`keytool` vem com o Android Studio, em `Android Studio\jbr\bin`.)

## 3. Apontar o build para a chave

Crie `android/key.properties` (o arquivo está no `.gitignore`; nunca o
versione):

```properties
storePassword=<senha do keystore>
keyPassword=<senha da chave>
keyAlias=upload
storeFile=C:/caminho/seguro/yvenist-upload.jks
```

Com esse arquivo presente, o build de release é assinado com a chave de
publicação. Sem ele, o build ainda funciona, assinado com a chave de debug:
serve para testar na própria máquina, mas a loja recusa.

## 4. Gerar o pacote

A URL da API entra no build. Em release ela **precisa ser `https`**; com outro
valor o app abre uma tela de erro de configuração em vez de funcionar pela
metade.

```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.seudominio.com/api/v1
```

O arquivo para enviar à Play Store fica em
`build/app/outputs/bundle/release/app-release.aab`.

Para conferir a assinatura de um APK:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://api.seudominio.com/api/v1
& "$env:LOCALAPPDATA\Android\sdk\build-tools\<versão>\apksigner.bat" verify --print-certs build\app\outputs\flutter-apk\app-release.apk
```

O "certificate DN" tem de ser o da chave de vocês, e não `CN=Android Debug`.

> Sem `--dart-define=API_BASE_URL` o build sai em **modo demonstração**, com
> dados de exemplo em memória. Serve para mostrar o app, não para publicar.

## 5. A cada nova versão

Aumente a versão em `pubspec.yaml` (`version: 1.0.1+2`: o número depois do `+`
tem de crescer a cada envio) e a constante `AppConfig.appVersion`, que é a
versão mostrada na tela de perfil. Um teste falha se as duas ficarem
diferentes.

## O que o projeto já garante

| Item | Onde |
|---|---|
| Permissão de internet também em release | `android/app/src/main/AndroidManifest.xml` |
| `http` sem TLS só em debug | `android/app/src/debug/AndroidManifest.xml` |
| Backup do Google desligado (tokens e dados da conta não vão para a nuvem) | `android:allowBackup="false"` no manifesto principal |
| Tokens da sessão no Keystore | `lib/core/storage/token_storage.dart` |
| Release recusa API sem `https` | `lib/core/config/app_config.dart` |
| Chave e senhas fora do Git | `.gitignore` (`*.jks`, `*.keystore`, `android/key.properties`) |

Conferido em um emulador (Android 13): build de release assinado pela chave
configurada em `key.properties`, instalado e aberto, com o backup desligado.

## Antes de publicar de verdade

- A API precisa estar no ar em `https`, com `YVENIST_ENV=production` e um
  `YVENIST_JWT_SECRET` próprio (veja `backend/README.md`).
- Os Termos de Uso e a Política de Privacidade ainda não foram escritos; a tela
  "Termos e Política" diz isso. A loja exige a política de privacidade.
- A ficha da loja pede a declaração de quais dados são coletados: nome, e-mail,
  telefone e data de nascimento (opcionais), e CPF/CNPJ de quem anuncia.
- iOS não foi compilado neste projeto (exige um Mac).
