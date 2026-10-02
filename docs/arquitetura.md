# Arquitetura do Yvenist

Como o app e a API estão organizados, e por que cada escolha foi feita. O
objetivo é que alguém novo no projeto consiga achar onde mexer sem ler tudo.

```
┌──────────────────────────┐        HTTPS / JSON        ┌───────────────────┐       ┌────────────┐
│  App Flutter             │ ─────────────────────────▶ │  API (FastAPI)    │ ────▶ │ PostgreSQL │
│  Android · iOS · web     │ ◀───────────────────────── │  /api/v1          │ ◀──── │            │
└──────────────────────────┘                            └───────────────────┘       └────────────┘
        │
        └── ou, sem API_BASE_URL: dados em memória (modo demonstração)
```

É um **monólito modular** dos dois lados: um app, uma API, um banco. Não há
microsserviços, fila nem cache distribuído, porque nada no produto pede isso
hoje. A separação em módulos é o que permite extrair uma parte no futuro, se um
dia fizer sentido.

---

## 1. O app (`lib/`)

### 1.1 Camadas e direção das dependências

Pastas por funcionalidade (`features/`), com as camadas da Clean Architecture
dentro de cada uma:

```
features/<funcionalidade>/
  domain/         entidades, regras e o CONTRATO do repositório (sem Flutter, sem rede)
  data/           implementações do contrato: Api<X>Repository e InMemory<X>Repository
  presentation/   controllers (ChangeNotifier), páginas e widgets
```

As dependências apontam sempre para dentro:

```
presentation ──▶ domain ◀── data
```

Uma tela conhece `CatalogRepository`, nunca `ApiCatalogRepository`. Quem sabe
quais implementações existem é um único arquivo, a **raiz de composição**:

| Arquivo | Papel |
|---|---|
| `app/app_dependencies.dart` | Escolhe as implementações: API (`AppDependencies.api`) ou memória (`AppDependencies.demo`) |
| `app/app_state.dart` | Cria os controllers que vivem o app inteiro e os liga à sessão |
| `app/yvenist_app.dart` | Publica tudo para as telas via `Provider`, define tema e idioma |
| `app/app_shell.dart` | As cinco abas, a barra inferior e o bloqueio "esta aba exige conta" |
| `main.dart` | Lê a configuração do build e sobe o app |

A camada de domínio só é "completa" (entidades, objetos de valor, casos de uso)
onde há regra de negócio de verdade: o **Party Maker**. Nas outras
funcionalidades o domínio é o contrato do repositório e as entidades, sem casos
de uso que só repassariam a chamada. Clean Architecture aqui é ferramenta, não
ritual.

### 1.2 Estado

`Provider` + controllers `ChangeNotifier`. Já era a biblioteca do projeto e dá
conta do tamanho dele; trocar por Riverpod ou Bloc não resolveria nenhum
problema que exista hoje.

Dois tipos de controller:

- **Do app inteiro** (criados em `AppState`): `SessionController`,
  `FavoritesController`, `PartyMakerController`, `VendorController`,
  `AppTabController`. Dependem de quem está logado. Quando a sessão muda (login,
  logout, sessão expirada), `AppState` avisa cada um para trocar de conta e
  recarregar.
- **De uma tela**: `HomeController`, `ListingSearchController`,
  `ExploreController`. Nascem e morrem com a tela.

Regras que todos seguem:

- Operações devolvem `bool`/valor e guardam a falha em `error`; nunca deixam uma
  exceção chegar ao widget.
- Dado que demora tem estado explícito: `LoadState<T>` (carregando, sucesso,
  falha) ou os pares `hasLoaded`/`loadError`. Toda tela trata os três, e o
  estado de erro sempre oferece "Tentar novamente".
- Respostas atrasadas não sobrescrevem as novas (a busca ignora o resultado de
  um termo que já foi trocado; uma carga iniciada para outra conta é
  descartada).

### 1.3 Erros

Os repositórios lançam `AppFailure` (`core/error/app_failure.dart`), uma classe
selada: `NetworkFailure`, `UnauthorizedFailure`, `ValidationFailure`,
`ConflictFailure` etc. `message` é sempre um texto em português pronto para a
tela; `code` é o código estável da API, para quando a tela precisa decidir algo.
Erro desconhecido vira `UnexpectedFailure`, com mensagem genérica: detalhe
técnico nunca aparece para o usuário.

### 1.4 Rede e sessão

`core/network/api_client.dart` concentra o que toda chamada precisa: JSON,
cabeçalho de autenticação, tempo limite, tradução do corpo de erro da API para
`AppFailure`, e a renovação da sessão:

- recebeu 401 em uma chamada autenticada → renova o token e repete a chamada
  uma vez;
- várias chamadas com 401 ao mesmo tempo esperam **uma única** renovação
  (renovar duas vezes com o mesmo token seria tratado pelo servidor como roubo
  de sessão);
- sem rede durante a renovação, a sessão **não** é apagada: estar offline não é
  o mesmo que ter sido deslogado.

Os tokens ficam no cofre do sistema (`flutter_secure_storage`: Keystore no
Android, Keychain no iOS), nunca em `SharedPreferences`.

### 1.5 Modo demonstração

Sem `--dart-define=API_BASE_URL`, o app usa os repositórios em memória. Não é um
"mock de teste" escondido: é uma implementação completa dos mesmos contratos,
com as mesmas validações, e é o que permite abrir o app (e rodar os testes de
tela) sem backend. A tela de login avisa que é demonstração e informa a conta
de teste.

Um valor **errado** em `API_BASE_URL` não cai no modo demonstração: é erro de
build, mostrado em uma tela própria. E um build de release só aceita `https`.

### 1.6 Party Maker

A festa é um agregado (`features/party_maker/domain/entities/party.dart`) que
protege as próprias regras:

```
rascunho ──▶ planejamento ──▶ travada (orçamento solicitado) ──▶ paga
                  ▲                │
                  └──── destravar ─┘          qualquer uma, menos paga ──▶ cancelada
```

- itens só entram e saem em rascunho/planejamento;
- no máximo um salão por festa;
- travar exige ao menos um item e tira uma "foto" do orçamento (snapshot);
- remover o último item apaga a festa.

O app aplica a regra localmente (resposta imediata) e envia o **estado
desejado** com `PUT /parties/{id}`. O servidor valida tudo de novo, copia nome e
preço do catálogo (nunca confia no que o app mandou) e devolve a festa como
ficou; o que volta substitui a cópia local. Cada gravação leva a versão
conhecida: se outro aparelho gravou antes, a resposta é um conflito e o app
recarrega.

### 1.7 Interface e acessibilidade

- Cores, espaçamentos e tipografia são tokens em `core/theme/`. As combinações
  de texto e fundo têm o contraste conferido por teste
  (`test/core/theme_contrast_test.dart`, mínimo 4,5:1).
- O laranja da marca (`#FF6600`) tem 2,9:1 sobre branco: fica para ícones e
  áreas grandes. Texto e botões usam `primaryStrong` (`#C2410C`, 5,2:1).
- Área de toque mínima de 48×48 e rótulo para leitor de tela em todo controle,
  conferidos por teste nas telas principais.
- Nenhuma tela estoura com a fonte do sistema em 200%.
- O que ainda não existe aparece como "Em breve", nunca como botão que não faz
  nada nem como dado de exemplo fingindo ser do usuário.

### 1.8 Fonte

`AppTypography.fontFamily` é `'Inter'`, mas **os arquivos da fonte não estão no
projeto**: hoje cada plataforma usa a sua fonte padrão (Roboto no Android). Para
usar a Inter de fato:

1. baixe as variações 400, 500, 600 e 700 em <https://rsms.me/inter/> (licença
   OFL) e coloque em `assets/fonts/`, junto com o arquivo da licença;
2. declare em `pubspec.yaml`:

   ```yaml
   flutter:
     fonts:
       - family: Inter
         fonts:
           - asset: assets/fonts/Inter-Regular.ttf
           - asset: assets/fonts/Inter-Medium.ttf
             weight: 500
           - asset: assets/fonts/Inter-SemiBold.ttf
             weight: 600
           - asset: assets/fonts/Inter-Bold.ttf
             weight: 700
   ```

3. rode os testes de acessibilidade: a Inter é um pouco mais larga que a Roboto.

---

## 2. A API (`backend/`)

### 2.1 Organização

```
app/
  main.py        monta a aplicação (create_app)
  api/           dependências HTTP compartilhadas e agregação das rotas
  core/          configuração, banco, segurança, erros, paginação, logs, limite de requisições
  modules/
    accounts/    cadastro, login, sessões, dados pessoais
    catalog/     categorias, tipos de evento, busca de anúncios
    favorites/   favoritos
    parties/     festas (regras em domain.py, sem banco nem HTTP)
    vendors/     cadastro de fornecedor, anúncios próprios, fila de análise
migrations/      Alembic
```

Cada módulo tem o mesmo desenho: `router.py` (HTTP) → `service.py` (caso de uso
e transação) → `models.py` (tabelas), com `schemas.py` como contrato de entrada
e saída. Rotas não falam com o banco; serviços não conhecem HTTP.

FastAPI com SQLAlchemy **síncrono**: cada requisição roda em uma thread do pool.
É mais simples de escrever, testar e depurar que a versão assíncrona, e o
gargalo de um marketplace deste porte é o banco, não o número de conexões
abertas.

### 2.2 Rotas

| Método e rota | Acesso | O que faz |
|---|---|---|
| `POST /auth/register` | público, limitado por IP | cria a conta e a sessão |
| `POST /auth/login` | público, limitado por IP | abre uma sessão |
| `POST /auth/refresh` | público | troca o token de renovação por um par novo |
| `POST /auth/logout` | público | encerra a sessão do token informado |
| `GET` `PATCH /users/me` | conta | dados pessoais |
| `POST /users/me/password` | conta | troca a senha e derruba as outras sessões |
| `POST /users/me/delete` | conta | apaga a conta e tudo que é dela |
| `GET /users/me/sessions`, `DELETE /users/me/sessions/{id}` | conta | aparelhos conectados |
| `GET /catalog/categories`, `/catalog/event-types` | público | dados de referência |
| `GET /catalog/listings`, `/catalog/listings/{id}` | público | busca e detalhe de anúncios publicados |
| `GET /favorites`, `PUT` `DELETE /favorites/{listing_id}` | conta | favoritos |
| `GET /parties`, `GET` `PUT` `DELETE /parties/{id}` | conta (dono) | festas |
| `GET /vendors/me`, `/vendors/me/listings`, `POST /vendors/onboarding` | conta | cadastro de fornecedor |
| `GET /admin/vendors`, `POST /admin/vendors/{id}/approve` `/reject` | administrador | análise de cadastros |
| `GET /admin/listings`, `POST /admin/listings/{id}/approve` `/reject` | administrador | análise de anúncios |
| `GET /health/live`, `/health/ready` | público | saúde do processo e do banco |

Todas sob `/api/v1`, menos as de saúde. A documentação interativa fica em
`/docs` (desligada em produção).

### 2.3 Contratos que valem para tudo

- **Erro** tem sempre a mesma forma, com textos em português:
  `{"error": {"code", "message", "details"?, "request_id"}}`. Erros por campo
  vêm em `details.fields` como `[{"field", "message"}]`. O valor enviado nunca
  volta na resposta (pode ser uma senha).
- **Dinheiro** é inteiro, em centavos.
- **Datas** são gravadas e devolvidas em UTC.
- **Identificadores** são UUID. Festas e itens recebem o id no app: repetir uma
  requisição cuja resposta se perdeu não cria duplicata.
- **Paginação** é por cursor (a última posição vista), não por `OFFSET`: não
  repete nem pula itens quando o catálogo muda entre duas páginas, e continua
  rápida na página mil.
- **Busca** ignora acentos e maiúsculas por uma coluna de texto normalizado.

### 2.4 Autenticação

- Senha com Argon2id; recusa das senhas mais comuns (NIST SP 800-63B), sem
  regras de composição.
- Token de acesso JWT de 15 minutos, algoritmo fixado na validação.
- Token de renovação opaco e aleatório; o banco guarda só o SHA-256 dele.
- **Rotação**: cada renovação entrega um token novo e invalida o anterior. Um
  token já trocado que reaparece indica cópia: a sessão inteira é encerrada.
- Trocar a senha incrementa a versão dos tokens do usuário e invalida na hora
  todos os tokens de acesso emitidos antes.
- A cada requisição o estado atual da conta é conferido (existe, está ativa,
  versão confere).

### 2.5 Concorrência

Verificar e depois gravar não é seguro sozinho: entre as duas coisas outra
requisição pode ter passado na frente. As regras ficam garantidas pelo banco:

| Situação | Garantia |
|---|---|
| mesmo e-mail cadastrado duas vezes ao mesmo tempo | índice único → 409 |
| mesmo CPF/CNPJ em dois cadastros de fornecedor | índice único → 409 |
| mesmo token de renovação usado em paralelo | trava na linha (`SELECT ... FOR UPDATE`) → só uma troca |
| dois aparelhos gravando a mesma festa | trava na linha + versão → o segundo recebe 409 e recarrega |
| dois salões na mesma festa | índice único parcial |
| dois administradores analisando o mesmo cadastro | trava na linha → o segundo recebe 409 |

`tests/test_concurrency.py` dispara requisições realmente simultâneas contra o
PostgreSQL para cada uma dessas situações.

### 2.6 Banco de dados

```
users ──┬── refresh_tokens
        ├── favorites ──────────────┐
        ├── parties ── party_items ─┼──▶ listings ── listing_event_types ──▶ event_types
        │        └──── party_snapshots       │
        └── vendor_profiles ─────────────────┘        listings ──▶ categories
```

- Chaves estrangeiras com `ON DELETE CASCADE` a partir do usuário: apagar a
  conta apaga o que é dela. O item de uma festa guarda nome e preço copiados;
  se o anúncio for apagado, o item continua na festa.
- Enums são texto + `CHECK` (não o tipo `ENUM` do PostgreSQL): acrescentar um
  valor é só trocar a constraint.
- As migrações são escritas à mão e conferidas por teste: o banco criado por
  elas tem de ser idêntico ao que os modelos descrevem, em SQLite e em
  PostgreSQL.

---

## 3. Segurança e dados pessoais

| Tema | Como está |
|---|---|
| Senhas | Argon2id; mínimo de 8 caracteres; lista de senhas comuns; tempo de resposta igual para e-mail existente ou não |
| Sessão | tokens no cofre do sistema; rotação com detecção de reuso; logout invalida no servidor |
| Transporte | release exige `https`; `http` só em debug e para `localhost` |
| Autorização | toda consulta filtra pelo dono: a festa de outra pessoa "não existe" (404) e não pode ser alterada; rotas `/admin` exigem administrador |
| Entrada | validada no servidor (Pydantic); o app valida antes só para dar retorno rápido |
| Preços | sempre copiados do catálogo pelo servidor |
| Força bruta | limite por IP em login e cadastro (em memória: veja "limites" abaixo) |
| Logs | sem corpo, query string ou cabeçalhos; cada requisição tem um id |
| Produção | a API se recusa a subir com segredo de desenvolvimento, CORS `*` ou hash de teste |
| LGPD | CPF/CNPJ só saem mascarados; a pessoa corrige os próprios dados e apaga a conta; backup do Android desligado |

---

## 4. Limites conhecidos e por onde crescer

Nada disto é necessário agora; está aqui para a decisão ser tomada com dados
quando o problema aparecer.

| Limite de hoje | Quando incomoda | Caminho |
|---|---|---|
| Busca com `LIKE '%termo%'` | catálogo com dezenas de milhares de anúncios | índice `pg_trgm` na coluna de busca, ou busca textual do PostgreSQL |
| Limite de requisições em memória | mais de uma instância da API | limitar no proxy/gateway, ou contador compartilhado |
| Limite de login só por IP | ataque distribuído a uma conta | limite também por conta, com cuidado para não virar bloqueio da vítima |
| Fotos são só uma URL | fornecedor enviar fotos | armazenamento de objetos + URLs assinadas |
| Sem página de detalhe do anúncio | — | a rota `GET /catalog/listings/{id}` já existe |
| Sem tela de administração | volume de cadastros para analisar | as rotas `/admin/*` já existem |
| Web guarda tokens no navegador | publicar a versão web | cookie `HttpOnly` para o token de renovação |
| Renovação estrita: resposta perdida derruba a sessão | redes muito instáveis | janela curta de tolerância para o token anterior |

---

## 5. Testes

| Onde | O que cobre |
|---|---|
| `test/features/**`, `test/core/**` | regras de domínio, controllers, repositórios (os da API contra uma camada HTTP de mentira: `test/support/fake_api.dart`) |
| `test/app/*_flow_test.dart` | o app inteiro em modo demonstração, na tela de um celular: navegar, buscar, entrar, montar festa, anunciar |
| `test/app/accessibility_test.dart` | área de toque, rótulos, leitores de tela, fonte em 200% |
| `test/core/theme_contrast_test.dart` | contraste de cada par de cores usado |
| `test/integration/` | o código real do app contra uma API no ar (pulado sem `YVENIST_API_URL`) |
| `test/visual/screenshots_test.dart` | gera `docs/screenshots` a partir das telas reais |
| `backend/tests/` | cada rota, as regras das festas, migrações, comandos, concorrência |

`test/support/app_harness.dart` tem o `appTest`, que sobe o app para um teste de
fluxo, e `demoDependencies`, para trocar uma dependência por uma que falha.
