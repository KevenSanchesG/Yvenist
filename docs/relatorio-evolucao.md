# YVENIST — RELATÓRIO DE EVOLUÇÃO

Estado em 2 de outubro de 2026, branch `feat/professional-foundation` (20
commits sobre a `main`, o último deles este relatório; nada enviado ao GitHub).

## 1. Estado inicial

- 239 arquivos Dart, dos quais **175 vazios**; cerca de 5,2 mil linhas de código
  de verdade. Dependências: só `provider` e `cupertino_icons`.
- Um protótipo de telas: sem backend, sem login, sem persistência, **nenhum
  teste**, sem CI.
- Várias telas mostravam dados inventados como se fossem do usuário (reservas,
  notificações, cartões, saldo "R$ 2.5k").
- O README prometia Firebase, pagamentos, chat, avaliações e 2FA; nada disso
  existia.
- Android: permissão de internet só no manifesto de debug (um build de release
  não carregaria nada), identificador `com.example.yvenist`, release assinado
  com a chave de debug.

## 2. Problemas encontrados

| Tipo | Exemplos |
|---|---|
| Estrutura | 175 arquivos vazios; repositório duplicado; estado global em singletons (`GlobalAppState`, `VendorSession`); dados fixos dentro dos widgets |
| Bugs de regra | ids gerados pelo relógio colidiam (remover um item removia dois); remover o último item deixava uma festa "fantasma"; favoritos e itens identificados pelo título |
| Bugs de tela | cor do cabeçalho com canais trocados; formulário de salão com campos sem controle e um rádio travado; avatar apontando para uma página, não para uma imagem |
| Só vistos com testes de tela | metade do seletor "Modo Cliente/Fornecedor" e o topo do botão central não recebiam toque; contadores do perfil sem ação para leitor de tela; contraste de 3,7:1 e 4,3:1; telas estourando com fonte grande; mensagens com jargão ("Party está Locked") |
| Só vistos no aparelho | "próximo" do teclado parava no botão do olho da senha e no e-mail bloqueado; card cortava nome e preço com fonte em 150%; relógio escuro sobre cabeçalho escuro |
| Só vistos com PostgreSQL | dois cadastros de fornecedor simultâneos com o mesmo documento davam erro 500; conexão de teste fechada só pelo coletor de lixo |
| Só vistos na integração | `create-admin` criava administrador com e-mail que o login recusava; erro de campo vinha em inglês; erro do servidor no campo senha não aparecia em lugar nenhum |

## 3. Skills necessárias

Arquitetura Flutter (camadas, Provider), domínio rico (Party Maker), API com
FastAPI/SQLAlchemy/Alembic, PostgreSQL (travas, índices parciais, concorrência),
segurança (OWASP, NIST 800-63B), acessibilidade (WCAG 2.1 AA), testes em quatro
níveis, GitHub Actions, Docker e build/assinatura Android. A skill `find-skills`
foi instalada no início; nenhuma outra foi necessária.

## 4. Arquitetura anterior

Telas falando direto com estado global e com dados escritos no próprio widget.
O Party Maker já tinha um domínio bem modelado (agregado, objetos de valor, casos
de uso), mas preso a um repositório em memória instanciado dentro da tela. Não
havia camada de dados, sessão, tratamento de erro nem composição de dependências.

## 5. Arquitetura implementada

Detalhes em `docs/arquitetura.md`. Em resumo:

- **App**: pastas por funcionalidade, com `domain` (contratos e regras), `data`
  (implementação pela API e em memória) e `presentation` (controllers
  `ChangeNotifier` + telas). Uma raiz de composição (`AppDependencies`) escolhe
  API ou modo demonstração; `AppState` liga os controllers à sessão.
- **API**: monólito modular (contas, catálogo, favoritos, festas, fornecedores),
  cada módulo com rota → serviço → modelo. Regras das festas em um `domain.py`
  puro.
- **Modo demonstração** de primeira classe: sem `API_BASE_URL` o app roda
  inteiro em memória.

## 6. Mudanças realizadas

| Commit | Etapa |
|---|---|
| `a7311d0` | Higiene: 175 arquivos vazios removidos, `.gitattributes`, permissão de internet em release |
| `ccefcab` | Testes de caracterização do Party Maker (domínio, casos de uso, controller) |
| `a12aea5` | API completa: FastAPI + SQLAlchemy + Alembic, 318 testes |
| `c9afed1` | Fundação do app: configuração, cliente HTTP, cofre de tokens, falhas, tema |
| `42630a4` | Party Maker passa a depender do contrato; dois bugs corrigidos |
| `653648f` | Todas as telas sobre repositórios; login, cadastro, catálogo, favoritos, fornecedor |
| `5bcd4e8` | Lints mais rígidos e formatação |
| `790377a` | Correções achadas pelos testes de tela (toque, leitores de tela, contraste, fonte grande, mensagens) |
| `f13e1ff` | Testes do app: dados, controllers, fluxos de tela, acessibilidade |
| `9baeef2` | `create-admin` valida o e-mail como o login |
| `7ebd5ef` | Testes de integração: o app contra a API no ar |
| `47ea6cc` | Suíte e migrações rodando em PostgreSQL |
| `4595f67` | Corrida no cadastro de fornecedor: 409 em vez de 500; testes de concorrência |
| `9070beb` | `API_BASE_URL` errada vira erro visível; release exige https; Android (backup, assinatura) |
| `948339e` | Correções vistas no emulador (teclado, cards com fonte grande, barra de status, superfícies) |
| `5708104` | Erros de campo em português; lista de senhas comuns |
| `6b48a8b` | App mostra o erro do servidor no campo certo |
| `fee3c74` | CI com 5 jobs |
| `7b7aa2a` | README fiel ao código, arquitetura, guia de publicação Android |

## 7. Estrutura de diretórios final

```
lib/                       109 arquivos, 9,8 mil linhas
  app/                     composição, estado do app, abas
  core/                    config, erro, rede, armazenamento, tema, widgets
  features/
    auth/ catalog/ client/ party_maker/ vendor/ shared_features/
test/                      31 arquivos, 7,3 mil linhas
  core/ features/          unidades
  app/                     fluxos de tela e acessibilidade
  integration/             app contra a API no ar
  visual/                  gera docs/screenshots
  support/                 harness, API de mentira, fixtures
backend/
  app/                     45 arquivos, 3,4 mil linhas (api, core, modules)
  migrations/              Alembic
  tests/                   16 arquivos, 3,2 mil linhas
docs/                      arquitetura, publicação Android, este relatório, screenshots
.github/workflows/ci.yml
docker-compose.yml
```

## 8. Banco de dados

- 11 tabelas: `users`, `refresh_tokens`, `categories`, `event_types`,
  `vendor_profiles`, `listings`, `listing_event_types`, `favorites`, `parties`,
  `party_items`, `party_snapshots`.
- UUID como chave; dinheiro em centavos; datas em UTC; enums como texto + `CHECK`.
- Regras no próprio banco: e-mail único, documento único, um salão por festa
  (índice único parcial), quantidades e preços positivos, anúncio publicado tem
  data. Apagar a conta apaga em cascata o que é dela.
- Índices para cada ordenação do catálogo e para as consultas por dono.
- Uma migração (`0001`), escrita à mão, com teste que compara o banco migrado
  com os modelos e exercita o `downgrade`.
- **Verificado em SQLite e em PostgreSQL 17.11.**

## 9. APIs

30 operações em `/api/v1` (tabela em `docs/arquitetura.md`): autenticação
e sessões, dados pessoais e exclusão da conta, catálogo público com busca e
paginação por cursor, favoritos, festas (gravação por estado desejado, com
versão), cadastro de fornecedor e fila de análise para administradores, mais
`/health/live` e `/health/ready`. Todo erro tem o mesmo formato, com `code`
estável e `message` em português.

## 10. Segurança

Resolvidos nesta evolução:

| Severidade | Achado | Solução |
|---|---|---|
| ALTO | Qualquer pessoa se aprovava como fornecedor por um botão "Aprovar (Dev)" no app | Aprovação só por administrador, na API; no modo demonstração a simulação é rotulada como tal |
| ALTO | Não existia autenticação nem dono dos dados | Argon2id, JWT curto + token de renovação com rotação e detecção de reuso; toda consulta filtra pelo dono |
| ALTO | Preço e nome dos itens da festa vinham do app | O servidor copia do catálogo; um cliente adulterado não muda preço (testado) |
| MÉDIO | `API_BASE_URL` errada virava modo demonstração em silêncio; `http` aceito em release | Erro de configuração visível; release exige `https` |
| MÉDIO | Backup do Android ligado, com tokens da sessão no aparelho | `allowBackup="false"`; tokens no Keystore |
| MÉDIO | Senhas como `12345678` eram aceitas | Lista de senhas comuns (NIST 800-63B), no cadastro, na troca e no `create-admin` |
| MÉDIO | Corrida entre dois cadastros de fornecedor terminava em erro 500 | Violação do índice único vira 409; coberto por teste de concorrência |
| BAIXO | `create-admin` aceitava e-mail que o login recusa | Mesma validação do login |
| BAIXO | Release assinado com a chave de debug | Assinatura por `android/key.properties` (fora do Git), conferida com `apksigner` |
| INFORMATIVO | Erros de campo com o texto interno do Pydantic, em inglês | Mensagens próprias em português; o valor enviado nunca volta na resposta |

Em aberto (nenhum CRÍTICO ou ALTO conhecido):

| Severidade | Ponto | Observação |
|---|---|---|
| MÉDIO | Limite de tentativas de login só por IP e em memória | Com mais de uma instância, limitar no proxy; avaliar limite também por conta |
| MÉDIO | Termos de Uso e Política de Privacidade não existem | Exigidos pela LGPD e pelas lojas antes de publicar; a tela diz que estão em elaboração |
| BAIXO | Versão web guarda os tokens no navegador | Antes de publicar a web: token de renovação em cookie `HttpOnly` |
| BAIXO | Se a resposta de uma renovação se perde, a sessão cai | Consequência da rotação estrita; uma janela curta de tolerância resolveria |
| INFORMATIVO | Laranja da marca tem 2,94:1 sobre branco | Fica logo abaixo dos 3:1 pedidos para ícones; mudar é decisão de marca |

## 11. Performance

- Catálogo com paginação por cursor e índices para cada ordenação; itens e
  snapshots das festas carregados sem consulta por linha.
- Home faz as quatro consultas em paralelo; abas só são montadas quando abertas;
  imagens decodificadas no tamanho em que aparecem; busca com espera de 400 ms
  entre teclas; botões de cada card se redesenham sozinhos.
- Nas execuções locais as leituras responderam em poucos milissegundos (3 a
  50 ms). **Não foi feito teste de carga.**

## 12. Escalabilidade

A API não guarda estado entre requisições (fora o limite de tentativas), usa
pool de conexões e tem teto por usuário (100 festas, 50 itens por festa, 500
favoritos, 50 anúncios por fornecedor). Os limites conhecidos e o caminho para
cada um (busca com `pg_trgm`, limite de requisições compartilhado, armazenamento
de fotos) estão em `docs/arquitetura.md`, seção 4. Nada de microsserviços, fila
ou cache distribuído: não há problema hoje que eles resolvam.

## 13. Clean Architecture

Aplicada onde ajuda: as telas dependem de contratos, as regras das festas não
conhecem Flutter nem rede, e a mesma interface tem duas implementações (API e
memória). Onde não há regra de negócio, não há casos de uso só para repassar a
chamada.

## 14. IHC / UX / UI

- Todo dado que demora tem os três estados: carregando, erro com "Tentar
  novamente", vazio com explicação do que fazer.
- O que não existe aparece como "Em breve", em vez de botão morto ou dado falso.
- Navegar no catálogo não exige conta; favoritar e montar festa pedem login
  dizendo o motivo, e a ação continua depois de entrar.
- Formulários validam no campo, mantêm o que foi digitado e pedem confirmação
  antes de descartar alterações.
- Acessibilidade conferida por teste: contraste AA em todos os pares de cor,
  área de toque de 48×48, rótulos para leitor de tela, nenhuma tela estoura com
  a fonte do sistema em 200%.
- Mensagens das regras em linguagem de quem usa ("Esta festa já tem um salão.
  Remova o atual para escolher outro.").

## 15. Testes criados ou alterados

Antes: 0. Agora:

| Suíte | Quantidade | Resultado |
|---|---|---|
| App: unidades, fluxos de tela, acessibilidade, contraste | 442 | todos passam |
| App contra a API no ar (integração) | 26 cenários | todos passam |
| Backend em SQLite | 339 | todos passam |
| Backend em PostgreSQL 17.11 | 329 (321 + 8 de concorrência) | todos passam |
| Geração de screenshots a partir das telas reais | 8 | todos passam |

Os 18 testes de backend adicionados por último (mensagens de campo e senhas
comuns) rodaram só em SQLite: o PostgreSQL temporário já tinha sido desligado.

## 16. DevOps

- `.github/workflows/ci.yml`: cinco jobs independentes (app, backend com
  PostgreSQL, integração app + API, APK Android, Docker).
- `backend/Dockerfile` (usuário sem privilégios, healthcheck) e
  `docker-compose.yml` (PostgreSQL, migrações, API).
- Dependências do backend travadas (`requirements*.txt`); `.env.example`.
- Assinatura de release por `key.properties`; guia em
  `docs/publicacao-android.md`.

## 17. Arquivos criados

182 arquivos. Os principais: todo o `backend/` (72), `lib/app` (6), `lib/core`
(12), 40 em `lib/features` (auth, catalog, favoritos, fornecedor, páginas
novas), 31 arquivos de teste, `docs/` (3 documentos + 15 screenshots),
`.github/workflows/ci.yml`, `docker-compose.yml`, `dart_test.yaml`,
`.gitattributes`.

## 18. Arquivos modificados

63 arquivos: todo o `party_maker` (domínio, casos de uso, controller, telas),
tema (`app_colors`, `app_theme`, `app_typography`), telas de perfil, busca,
favoritos e fornecedor, `main.dart`, `pubspec.yaml`, `analysis_options.yaml`,
`.gitignore`, `README.md`, manifestos e `build.gradle.kts` do Android,
`web/index.html` e `web/manifest.json`.

## 19. Arquivos removidos

197 arquivos: 188 Dart (175 vazios e 13 de código substituído: estado global,
componentes duplicados, telas de dados falsos), 8 imagens soltas na raiz e
`.gitattributes.txt`. Nenhum dado real foi apagado; nenhuma operação destrutiva
em banco foi executada.

A lista completa dos três grupos: `git diff --name-status main..feat/professional-foundation`.

## 20. Validações executadas

| O quê | Como | Resultado |
|---|---|---|
| Análise estática do app | `flutter analyze` (modo estrito) | sem apontamentos |
| Formatação | `dart format --set-exit-if-changed` | nada a alterar |
| Testes do app | `flutter test` | 442 passam |
| Backend | `ruff`, `mypy --strict`, `pytest` | limpo; 339 passam |
| Backend em PostgreSQL | PostgreSQL 17.11 portátil, em pasta temporária | 329 passam, duas execuções |
| Migrações em PostgreSQL | `alembic upgrade head` + comparação com os modelos + `downgrade` | iguais |
| Concorrência | requisições realmente simultâneas (até 8 por cenário) no PostgreSQL | os dois cenários de fornecedor falham sem a correção e passam com ela |
| Integração | app contra a API em SQLite e em PostgreSQL | 26 e 25 cenários passam |
| Android real | APK de debug no emulador (Android 13) contra a API local: criar conta, favoritar, montar festa, pedir orçamento, reabrir o app | funcionou; sessão restaurada do Keystore |
| Release Android | build assinado com chave descartável, `apksigner`, instalado e aberto | assinatura correta; backup desligado |
| Fonte grande no aparelho | sistema em 150% | corrigido o que cortava |
| Web | `flutter build web` + Chrome sem janela | compila e desenha a tela inicial |
| Conteúdo da imagem Docker | só os arquivos que o `Dockerfile` copia, com o comando do contêiner, contra PostgreSQL | migra, popula e responde |

## 21. Problemas restantes

1. **Docker nunca rodou** (não há Docker na máquina). `Dockerfile` e
   `docker-compose.yml` foram revisados e simulados fora de contêiner, mas a
   primeira execução real será a do CI.
2. **O CI nunca rodou**: nada foi enviado ao GitHub. Os comandos dos jobs foram
   executados localmente, menos o de Docker.
3. **Identificador `com.example.yvenist`**: a Play Store não aceita. Precisa ser
   escolhido antes de publicar (passos em `docs/publicacao-android.md`).
4. **iOS não foi compilado** (exige um Mac).
5. **A fonte Inter é citada no código, mas os arquivos não estão no projeto**:
   cada plataforma usa a sua fonte padrão. Como incluir: `docs/arquitetura.md`.
6. **Termos de Uso e Política de Privacidade** não existem.
7. **Sem tela de administração**: aprovar fornecedor é só pela API.
8. Funcionalidades marcadas como "Em breve": pagamentos, chat, avaliações,
   notificações, envio de fotos, página de detalhe do anúncio, 2FA.
9. A versão web compila e abre, mas não foi exercitada contra a API.
10. Sem teste de carga.

Efeitos na máquina, além do repositório: Node.js LTS e a skill `find-skills`
(pedidos no início); `backend/.venv`; a plataforma Android SDK 35, que o Gradle
instalou sozinho no primeiro build; a pasta `build/` (ignorada pelo Git). O
PostgreSQL portátil, o banco de teste, a chave descartável e o app instalado no
emulador foram removidos.

## 22. Próximas melhorias

Na ordem em que destravam mais coisa:

1. Enviar a branch e ver o CI rodar; ajustar o job de Docker se preciso.
2. Decidir o identificador do app e criar a chave de publicação.
3. Publicar a API (PostgreSQL, `https`, `YVENIST_ENV=production`) e apontar o
   app para ela.
4. Tela de administração para a fila de análise.
5. Página de detalhe do anúncio e envio de fotos pelo fornecedor.
6. Textos legais; depois, a declaração de dados nas lojas.
7. Limite de tentativas por conta e no proxy.
8. Incluir a fonte Inter, se continuar sendo a escolha.
9. Pagamentos e chat, que são os próximos blocos de produto.
