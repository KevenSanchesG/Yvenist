---
title: Testes
type: architecture
updated: 2026-10-02
---

# Testes

O que cada conjunto prova e onde fica. Comandos: [development](../09-guides/development.md).
O que o CI roda: [ci](../09-guides/ci.md).

## App (`test/`)

| Onde | O que prova |
|---|---|
| `test/features/**` | regras de domínio, controllers e repositórios. Os da API são testados contra uma camada HTTP de mentira (`support/fake_api.dart`): caminho, corpo e tradução de erros |
| `test/core/**` | `ApiClient` (renovação da sessão), cofre de tokens, utilitários, **contraste das cores** (`theme_contrast_test.dart`), arquivos embutidos (`bundled_assets_test.dart`) |
| `test/app/*_flow_test.dart` | o app inteiro em modo demonstração, na tela de um celular (360×780): navegar, buscar, entrar, montar festa, anunciar, analisar |
| `test/app/accessibility_test.dart` | área de toque de 48×48, rótulos, leitores de tela, e cada fluxo de novo com a fonte do sistema em 200% |
| `test/integration/` | o código real do app contra uma API no ar. Pulado sem `YVENIST_API_URL`. Roda na máquina e **dentro do Chrome** |
| `test/visual/screenshots_test.dart` | gera `docs/screenshots/` a partir das telas reais (etiqueta `screenshots`, fora da suíte normal) |

Apoio (`test/support/`):

| Arquivo | Para que serve |
|---|---|
| `app_harness.dart` | `appTest` sobe o app para um teste de fluxo; `demoDependencies` troca uma dependência; `openTab`, `tapAndSettle`, `scrollToAndTap`, `enterField` |
| `visual_harness.dart` | fontes reais (a Inter embutida), imagens de rede de mentira, tela de celular |
| `fake_api.dart` | `FakeApi`: define a resposta de cada rota e confere o que foi pedido |
| `catalog_fixtures.dart`, `review_fixtures.dart` | dados de exemplo e repositórios que podem ser mandados falhar ou esperar |
| `test_environment.dart` | lê a configuração dos testes de integração: variável de ambiente na máquina, `--dart-define` no navegador |

Etiquetas (`dart_test.yaml`): `integration` e `screenshots`.

## API (`backend/tests/`)

| Arquivo | O que prova |
|---|---|
| `test_auth.py`, `test_users.py`, `test_passwords.py` | cadastro, login, rotação e reuso de token, dados pessoais, senhas comuns |
| `test_catalog.py`, `test_favorites.py` | busca, filtros, cursor, favoritos |
| `test_parties.py`, `test_parties_domain.py` | cada regra da festa, com e sem banco |
| `test_vendors.py` | cadastro de fornecedor e fila de análise |
| `test_api_basics.py`, `test_core.py` | formato de erro, mensagens por campo, CORS, saúde, configuração |
| `test_migrations.py` | o banco criado pelas migrações é igual ao dos modelos; `downgrade` volta ao vazio |
| `test_concurrency.py` | requisições simultâneas de verdade. **Só roda em PostgreSQL** (pulado em SQLite) |
| `test_cli.py`, `test_documents.py` | comandos de administração; CPF e CNPJ (inclusive o alfanumérico) |

Por padrão a suíte usa SQLite em memória; com `YVENIST_TEST_DATABASE_URL` roda
em PostgreSQL, que é onde os testes de concorrência entram.

## O que foi conferido fora dos testes automáticos

| O quê | Como | Quando |
|---|---|---|
| Android em aparelho | emulador Pixel 6 contra a API: criar conta, favoritar, montar festa, solicitar orçamento, sessão recuperada depois de reiniciar | 2026-10-02 |
| Build de release assinado | chave descartável via `key.properties`, instalado e aberto | 2026-10-02 |
| Web contra a API | Chrome controlado por script: vitrine, login, sessão recuperada ao recarregar, fila de análise | 2026-10-02 |

Não conferido: iOS (exige um Mac).

## Convenções

- Nome do teste em português, dizendo o comportamento: `'recusar exige o motivo…'`.
- Defeito corrigido ganha um teste com o comentário `Regressão:`.
- Um teste de tela nunca usa rede: as imagens são substituídas
  (`withFakeNetworkImages`) e os dados vêm dos repositórios em memória.
- Texto longo lido de um asset em teste de tela: carregar com `cache: false`.
  O cache do `rootBundle` guarda um `Future` do teste anterior, que nunca
  completa no seguinte (aconteceu em `legal_document_page.dart`).
- Em teste que também roda no navegador: nada de `dart:io` direto e nada de
  `1 << 32` (em JavaScript vale 0). Detalhes: [flutter-web-testing](../06-research/flutter-web-testing.md).
