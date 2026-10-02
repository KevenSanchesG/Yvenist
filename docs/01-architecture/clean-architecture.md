---
title: O app (Flutter)
type: architecture
updated: 2026-10-02
---

# O app (Flutter)

Pastas por funcionalidade, com as camadas da Clean Architecture dentro de cada
uma. Motivo: [ADR-001](../05-decisions/ADR-001-camadas-por-funcionalidade.md).

## Camadas

```
features/<funcionalidade>/
  domain/         entidades, regras e o CONTRATO do repositório (sem Flutter, sem rede)
  data/           implementações do contrato: Api<X>Repository e InMemory<X>Repository
  presentation/   controllers (ChangeNotifier), páginas e widgets
```

As dependências apontam para dentro: `presentation ──▶ domain ◀── data`.

## Mapa de `lib/`

| Pasta | Conteúdo |
|---|---|
| `main.dart` | lê a configuração do build e sobe o app |
| `app/` | raiz de composição, estado do app inteiro, as cinco abas |
| `core/config` | `AppConfig`: URL da API, modo demonstração, versão |
| `core/network` | `ApiClient` |
| `core/storage` | `TokenStorage` (cofre do sistema ou memória) |
| `core/error`, `core/state` | `AppFailure`, `LoadState<T>` |
| `core/theme`, `core/widgets` | tokens de design e widgets compartilhados ([design system](../04-ux/design-system.md)) |
| `core/utils` | dinheiro, CPF/CNPJ, ids |
| `features/auth` | sessão, entrar, criar conta |
| `features/catalog` | anúncios, categorias, busca (só domínio e dados) |
| `features/client` | telas do cliente: `home`, `explore`, `search`, `favorites`, `profile`; `shared` tem o card e as ações de um anúncio |
| `features/party_maker` | [Party Maker](../03-features/party-maker/architecture.md) |
| `features/vendor` | cadastro de fornecedor e do salão |
| `features/admin` | fila de análise |
| `features/shared_features` | `legal`, `security`, e as telas "Em breve": `chat`, `notifications`, `payments` |

## Raiz de composição

| Arquivo | Papel |
|---|---|
| `app/app_dependencies.dart` | escolhe as implementações: `AppDependencies.api` ou `.demo` |
| `app/app_state.dart` | cria os controllers do app inteiro e os liga à sessão |
| `app/yvenist_app.dart` | publica tudo via `Provider`; tema e idioma (`pt_BR`) |
| `app/app_shell.dart` | as cinco abas, a barra inferior, o bloqueio "esta aba exige conta" |

Contratos disponíveis: `AuthRepository`, `CatalogRepository`,
`FavoritesRepository`, `PartyRepository`, `VendorRepository`, `ReviewRepository`.

## Estado

`Provider` + controllers `ChangeNotifier` ([ADR-002](../05-decisions/ADR-002-estado-com-provider.md)).

| Tipo | Quais | Vida |
|---|---|---|
| Do app inteiro | `SessionController`, `FavoritesController`, `PartyMakerController`, `VendorController`, `AppTabController` | criados em `AppState`; quando a sessão muda, cada um troca de conta e recarrega |
| De uma tela | `HomeController`, `ListingSearchController`, `ExploreController`, `ReviewQueueController` | nascem e morrem com a tela (`ChangeNotifierProvider(create:)`) |

Regras comuns: operação devolve `bool`/valor e guarda a falha; dado que demora
tem estado explícito (`LoadState<T>` ou `hasLoaded`/`loadError`); depois de
`dispose` o controller não notifica mais ninguém (`_disposed`).

## Erros

Repositórios lançam `AppFailure` (`core/error/app_failure.dart`), classe selada:
`NetworkFailure`, `UnauthorizedFailure`, `ForbiddenFailure`, `NotFoundFailure`,
`ConflictFailure`, `ValidationFailure` (com `fieldErrors`), `RateLimitedFailure`,
`ServerFailure`, `UnexpectedFailure`. `message` é o texto para a tela; `code` é
o código estável da API. Motivo: [ADR-009](../05-decisions/ADR-009-erros-uniformes.md).

## Rede e sessão

`core/network/api_client.dart` cuida de JSON, cabeçalho de autenticação, tempo
limite (15 s) e da tradução do erro. A renovação da sessão:

- 401 em chamada autenticada → renova o token e repete **uma** vez;
- várias chamadas com 401 ao mesmo tempo esperam uma única renovação;
- sem rede durante a renovação a sessão **não** é apagada.

Tokens no cofre do sistema (`SecureTokenStorage`); se o cofre falhar ao ler, o
app abre sem sessão e não apaga nada. Motivo: [ADR-004](../05-decisions/ADR-004-autenticacao.md).

## Navegação

Cinco abas em `AppTab`: Início, Explorar, Minhas festas (botão central), Chat,
Perfil. "Minhas festas" e "Perfil" pedem conta; as outras funcionam para
visitante. As telas internas são empilhadas com `Navigator.push`. Mapa das
telas: [screens](../04-ux/screens.md).

## Para acrescentar uma funcionalidade

1. `domain/`: entidades e o contrato do repositório.
2. `data/`: `Api…Repository` e `InMemory…Repository`, os dois com testes.
3. Registrar o contrato em `AppDependencies` (construtor e fábricas `api` e
   `demo`) e em `test/support/app_harness.dart`.
4. `presentation/`: controller e página; controller do app inteiro entra em
   `AppState`, o de tela é criado pela própria página.
5. Testes: unidade (repositórios, controller), fluxo (`test/app/*_flow_test.dart`),
   acessibilidade e, se fala com a API, um cenário em `test/integration/`.
6. Registrar na Knowledge Base ([memory-system](../00-project/memory-system.md)).
