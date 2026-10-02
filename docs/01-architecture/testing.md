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
| `test/core/**` | `ApiClient` (renovação da sessão), cofre de tokens, utilitários, **contraste das cores nos dois temas** (`theme_contrast_test.dart`), nenhuma cor escrita à mão nas telas (`theme_usage_test.dart`), a escolha de tema e onde ela é guardada (`theme_mode_test.dart`), arquivos embutidos (`bundled_assets_test.dart`) |
| `test/app/*_flow_test.dart` | o app inteiro em modo demonstração, na tela de um celular (360×780): navegar, buscar, entrar, montar festa, anunciar, analisar |
| `test/app/system_bars_test.dart` | com as barras de um aparelho (os outros testes rodam sem elas): o conteúdo não passa por baixo do relógio no perfil, o último item das listas e os botões dos rodapés ficam acima da barra de navegação, e a barra é transparente nos dois temas |
| `test/app/accessibility_test.dart` | área de toque de 48×48, rótulos, leitores de tela, cada fluxo de novo com a fonte do sistema em 200% e os fluxos principais de novo **no tema escuro** |
| `test/integration/` | o código real do app contra uma API no ar. Pulado sem `YVENIST_API_URL`. Roda na máquina e **dentro do Chrome** |
| `test/visual/screenshots_test.dart` | gera `docs/screenshots/` a partir das telas reais, nos dois temas (etiqueta `screenshots`, fora da suíte normal) |

Apoio (`test/support/`):

| Arquivo | Para que serve |
|---|---|
| `app_harness.dart` | `appTest` sobe o app para um teste de fluxo; `demoDependencies` troca uma dependência; `openTab`, `tapAndSettle`, `scrollToAndTap`, `enterField`; `useDarkTheme` põe o app no tema escuro |
| `fake_keystore.dart` | `FakeKeystore`: o cofre do sistema visto pelo canal do plugin, em um mapa; pode ser mandado falhar |
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

## Ferramentas (`tools/`)

| Arquivo | O que prova |
|---|---|
| `tools/test_build_legal_site.py` | o gerador das páginas legais lê o Markdown como o app lê, não deixa o texto virar marcação, não chama endereço de fora, avisa que é versão preliminar enquanto houver lacuna, e gera sempre o mesmo resultado |

Roda com `python -m unittest discover -s tools -p "test_*.py"`, sem instalar
nada.

## O que foi conferido fora dos testes automáticos

| O quê | Como | Quando |
|---|---|---|
| Android em aparelho | emulador Pixel 6 contra a API: criar conta, favoritar, montar festa, solicitar orçamento, sessão recuperada depois de reiniciar | 2026-10-02 |
| Build de release assinado | chave descartável via `key.properties`, instalado e aberto | 2026-10-02 |
| Pacote para a loja | recusa sem a chave; com uma chave descartável compila e sai assinado por ela; alvo API 36; bibliotecas de 64 bits em 16 KB ([android-release](../09-guides/android-release.md)) | 2026-10-02 |
| Web contra a API | Chrome controlado por script: vitrine, login, sessão recuperada ao recarregar, fila de análise | 2026-10-02 |
| API em modo de produção | o processo de verdade, com a configuração de produção ([deployment](../09-guides/deployment.md)) | 2026-10-02 |
| Tema escuro em um Android | emulador Pixel 6 (Android 13), modo demonstração: escolher "Escuro" em Aparência muda na hora; depois de encerrar o app à força e abrir de novo, ele abre no tema escuro | 2026-10-02 |
| Barras do sistema em um Android | mesmo emulador, com a barra de gestos e com os três botões, nos dois temas: início, perfil rolado, Termos de Uso até o fim, convite ao fornecedor, cadastro do salão com e sem teclado | 2026-10-02 |

Não conferido: iOS (exige um Mac; a lista está em [ios-build](../09-guides/ios-build.md)).

## Convenções

- Nome do teste em português, dizendo o comportamento: `'recusar exige o motivo…'`.
- Defeito corrigido ganha um teste com o comentário `Regressão:`.
- A suíte roda no tema claro. O que só aparece no tema escuro (uma borda que
  tira espaço, uma cor que some) precisa de um teste que chame `useDarkTheme`.
- Um teste de tela nunca usa rede: as imagens são substituídas
  (`withFakeNetworkImages`) e os dados vêm dos repositórios em memória.
- Texto longo lido de um asset em teste de tela: carregar com `cache: false`.
  O cache do `rootBundle` guarda um `Future` do teste anterior, que nunca
  completa no seguinte (aconteceu em `legal_document_page.dart`).
- Em teste que também roda no navegador: nada de `dart:io` direto e nada de
  `1 << 32` (em JavaScript vale 0). Detalhes: [flutter-web-testing](../06-research/flutter-web-testing.md).
