---
title: Relatório — memória persistente do projeto
type: changelog
updated: 2026-10-02
---

# Relatório — memória persistente do projeto

> **Documento histórico**, de 2 de outubro de 2026. Descreve como a Knowledge
> Base, o `CLAUDE.md`, as regras e a integração com o Obsidian foram montados.
> O funcionamento atual está em [memory-system](../00-project/memory-system.md).

## 1. O que foi encontrado

- Repositório na branch `feat/professional-foundation`, 20 commits sobre a
  `main`, árvore limpa, **nada enviado ao GitHub**.
- Nenhum `CLAUDE.md`, nenhuma pasta `.claude/`, nenhum `.mcp.json`.
- Em `docs/`: três documentos longos (arquitetura, publicação no Android,
  relatório de evolução) e as capturas de tela.
- Na conta do usuário (`~/.claude`): as skills `find-skills` e `synced` e três
  notas de memória automática, que só existem na máquina.
- Obsidian 1.13.7 instalado, com um cofre registrado
  (`Documentos\Obsidian Vault`) **vazio**; CLI oficial disponível e não
  ativada; nenhum plugin da comunidade.
- A sessão do Claude Code era aberta uma pasta acima do repositório.
- Máquina sem Docker e sem `gh`.

## 2. O que foi criado

| O quê | Onde |
|---|---|
| Memória global | `CLAUDE.md` (118 linhas) |
| Regras por área | `.claude/rules/` (7 arquivos, todos com `paths`) |
| Skill | `.claude/skills/atualizar-memoria/SKILL.md` |
| Knowledge Base | `docs/` — 73 documentos, com este |
| Configuração do cofre | `docs/.obsidian/` (`app.json`, `core-plugins.json`, `templates.json`) |
| Conferidor | `tools/check_docs.py`, rodando também no CI |
| Ponteiro para sessões abertas acima do repositório | `…\Projeto\CLAUDE.md` (fora do Git) |

## 3. O que foi modificado

- `docs/arquitetura.md` foi dividido entre `01-architecture/`, `02-domain/`,
  `04-ux/` e os ADRs, e removido. `docs/publicacao-android.md` e
  `docs/relatorio-evolucao.md` foram movidos (o relatório fica como história).
- `README.md` e `backend/README.md` apontam para a Knowledge Base em vez de
  repetir o conteúdo, e não trazem mais contagens de testes.
- `.gitignore`: arquivos locais do Obsidian e do Claude Code.
- `.github/workflows/ci.yml`: passo "Knowledge Base" no job `app`.
- Um comentário em `android/app/build.gradle.kts` (caminho do guia).
- Fora do repositório: o registro de cofres do Obsidian (o cofre `docs` foi
  acrescentado e passou a ser o que abre; o cofre vazio continua lá) e as
  três notas de memória automática, que agora apontam para a Knowledge Base.

## 4. Estrutura final

```
CLAUDE.md
.claude/
  rules/      flutter-app · ui-accessibility · backend · database · party-maker · testing · documentation
  skills/     atualizar-memoria/SKILL.md
docs/                      ← Knowledge Base e cofre do Obsidian
  README.md
  00-project/      memory-system (índice) · vision · glossary · roadmap
  01-architecture/ overview · principles · clean-architecture · backend · data-model · security · testing
  02-domain/       README · accounts · catalog · vendors-and-review · business-rules
  03-features/     README · browse-and-search · auth-and-account · vendor-onboarding · admin-review · legal
    party-maker/   README · vision · domain · entities · business-rules · user-flows · ux
                   architecture · integrations · known-issues · roadmap
  04-ux/           design-system · accessibility · screens
  05-decisions/    README · ADR-001 … ADR-014
  06-research/     README · claude-code-memory · obsidian-integration · flutter-web-testing
  07-known-issues/ README
  08-changelog/    README · 2026-10 · 2026-10-fundacao-profissional · 2026-10-memoria-persistente
  09-guides/       development · ci · web · android-release · obsidian
  templates/       adr · feature · business-rule · entity · research · known-issue · meeting
  screenshots/     18 capturas geradas por teste
  .obsidian/       configuração do cofre
tools/check_docs.py
```

## 5. Plugins instalados

**Nenhum.** Nada foi instalado na máquina. O cofre usa só plugins internos do
Obsidian (explorador, busca, grafo, links de volta, propriedades, modelos,
estrutura); notas diárias e Obsidian Sync ficaram desligados.

## 6. MCP configurado

**Nenhum, por decisão** ([ADR-011](../05-decisions/ADR-011-knowledge-base-em-docs.md)).
Não existe servidor MCP oficial do Obsidian; os da comunidade pedem um plugin e
uma chave de API ou repetem o que as ferramentas de arquivo do Claude Code já
fazem. O cofre são arquivos dentro do repositório, lidos com `Glob`, `Grep` e
`Read`. É também o menor privilégio possível: nenhum processo a mais, nenhuma
credencial, nenhum acesso fora do repositório.

## 7. Skills criadas ou modificadas

Criada: `/atualizar-memoria`, o passo a passo para registrar uma tarefa
relevante (o que vale registrar, onde cada fato mora, quando criar um ADR,
changelog, conferência). O corpo só entra no contexto quando a skill é
invocada. As skills que já existiam na conta do usuário não foram tocadas.

## 8. CLAUDE.md

Criado na raiz do repositório: identidade do projeto, os três protocolos
(início de sessão, consulta, atualização), arquitetura em cinco linhas,
comandos essenciais, onze regras críticas, convenções e o ambiente. Explicações
ficam em `docs/`, citadas por caminho e não importadas com `@` (a importação
carregaria tudo na largada).

## 9. Regras criadas

| Regra | Carrega ao ler |
|---|---|
| `flutter-app.md` | `lib/**/*.dart` |
| `ui-accessibility.md` | telas, tema, widgets compartilhados, `lib/app/` |
| `backend.md` | `backend/**/*.py` |
| `database.md` | modelos, migrações, `core/database.py` |
| `party-maker.md` | o Party Maker no app, na API e nos testes |
| `testing.md` | `test/**`, `backend/tests/**` |
| `documentation.md` | `docs/**`, `CLAUDE.md`, os README, `.claude/**` |

## 10. Knowledge Base criada

73 documentos em Markdown, todos alcançáveis a partir de
[memory-system](../00-project/memory-system.md). Cada afirmação foi conferida
contra o código; o que não é fato do código leva rótulo (`[DECISÃO]`,
`[INFERÊNCIA]`, `[PROPOSTA]`, `TODO`, `OPEN QUESTION`). Cada fato mora em um
lugar; os outros documentos apontam para ele.

## 11. ADRs criados

Catorze, listados em [05-decisions](../05-decisions/README.md): camadas por
funcionalidade; Provider; API em monólito modular; autenticação; festa gravada
por estado; concorrência pelo banco; dinheiro e cópias; acessibilidade e cores;
erros uniformes; fila de análise; Knowledge Base em `docs/`; CI a cada envio;
identificador do app; textos legais como arquivos do app. Dois aguardam os
donos: o tom do laranja (008) e a regra da fila de análise (010).

## 12. Party Maker documentado

Onze documentos em [party-maker](../03-features/party-maker/README.md),
escritos depois de ler o domínio do app, a camada de dados, as telas e o módulo
`parties` da API. O que a leitura mostrou e ficou registrado:

- 22 regras, cada uma com onde é garantida no app, na API e no banco, e o
  código do erro;
- as regras existem em duas implementações que precisam mudar juntas;
- sete diferenças entre o que o app aceita e o que a API aceita;
- o que o domínio já permite e a tela não oferece: data e convidados, renomear,
  cancelar, editar quantidade, ver o orçamento registrado;
- **o orçamento solicitado não chega a nenhum fornecedor**;
- 15 limites conhecidos e 5 perguntas em aberto para os donos.

## 13. Integração com o Git

A Knowledge Base, o `CLAUDE.md`, as regras, a skill e a configuração do cofre
são versionados. Ficam fora: disposição das janelas, tema, atalhos, plugins e
lixeira do Obsidian; `CLAUDE.local.md` e `.claude/settings.local.json`. O
conferidor roda no CI a cada envio. Commits desta etapa: `eae0e6b`, `36086ae`,
`331a969` e o deste relatório, enviados para `feat/professional-foundation`.
Nada foi mesclado na `main`.

## 14. Estratégia de recuperação de memória

1. O Claude Code carrega o `CLAUDE.md` sozinho.
2. O `CLAUDE.md` manda ler o índice, conferir o Git e abrir só os documentos da
   tarefa.
3. As regras da área carregam quando um arquivo dela é lido.
4. Se documento e código divergem, o código vence e o documento é corrigido.
5. Ao terminar uma tarefa relevante, a skill `/atualizar-memoria` registra o
   que mudou e o conferidor valida.

## 15. Estratégia de economia de tokens

Quatro camadas, cada uma carregada só quando precisa. Medido em sessões reais:

| Medida | Tokens |
|---|---|
| custo fixo da memória do projeto ao abrir uma sessão | 2 734 |
| Knowledge Base inteira, se fosse carregada de uma vez (estimativa) | cerca de 55 000 |
| sessão que respondeu a seis perguntas transversais, lendo 8 de 72 documentos | 44 592 no total, dos quais 24 770 são do próprio Claude Code |

Além disso: `CLAUDE.md` abaixo de 200 linhas; documentos pequenos (o maior
documento vivo tem 7,8 KB); nada de importação com `@`; nenhuma definição de
ferramenta MCP no contexto; números que envelhecem só no changelog.

## 16. Testes realizados

- `python tools/check_docs.py`: sem apontamentos. O conferidor foi visto
  acusar, em um arquivo de sonda, link quebrado, âncora inexistente, caminho
  citado que não existe, documento fora do índice e valor com formato de token.
- CI: os cinco jobs passaram com a Knowledge Base e o conferidor (`eae0e6b`).
- App e API seguem como estavam: 509 testes do app e 346 da API passando
  localmente; nenhuma linha de código de produção mudou nesta etapa.
- Obsidian 1.13.7 abriu o cofre na nota do índice e manteve a configuração.

## 17. Teste de nova sessão

Uma sessão nova do Claude Code 2.1.287 foi aberta na raiz do repositório, sem
nenhum contexto, só com permissão de leitura, e recebeu seis perguntas. Ela já
tinha o `CLAUDE.md` e a skill no contexto; a regra de documentação carregou
sozinha ao ler o primeiro documento; seguiu o protocolo; leu 8 documentos;
conferiu dois pontos contra o código; e respondeu certo: o estado do projeto, a
regra do salão único com arquivo, linha e código de erro, o que falta para a
Play Store, por que não há MCP, e a regra da fila de análise com a observação
de que ainda não foi confirmada pelos donos.

## 18. Problemas encontrados

- Abrir o Claude Code uma pasta acima do repositório não carrega o `CLAUDE.md`
  na largada. Resolvido com um ponteiro nessa pasta, fora do Git.
- O Obsidian regrava os arquivos de configuração sem a quebra de linha final:
  a versão dele é a que ficou no repositório, para não gerar diferença a cada
  abertura.
- Os nomes das chaves de `app.json` não estão na ajuda oficial do Obsidian;
  foram confirmados em páginas de terceiros e pelo próprio aplicativo, que as
  manteve.
- A ajuda oficial não cobre servidores MCP; essa parte da pesquisa vem de
  terceiros e está marcada assim.
- Um link para um título com mais de uma palavra não funciona igual no GitHub
  e no Obsidian: a convenção é evitá-los.

## 19. Pontos que exigem intervenção manual

- **Abrir o Claude Code dentro de `Yvenist\`** (recomendado), e não na pasta
  acima.
- Para outra pessoa ou outra máquina: abrir a pasta `docs` como cofre no
  Obsidian uma vez.
- Opcional: ativar a CLI do Obsidian (*Settings → General → Command line
  interface*) e instalar a ferramenta `gh`.
- O cofre vazio `Documentos\Obsidian Vault` não foi apagado: pode ser removido
  pelo próprio Obsidian, se não for usado.
- Decisões dos donos pendentes: [roadmap](../00-project/roadmap.md).

## 20. Próximos passos

1. Usar: a cada tarefa relevante, `/atualizar-memoria`.
2. Responder às perguntas em aberto do [roadmap](../00-project/roadmap.md)
   (cada resposta vira um ADR ou fecha uma `OPEN QUESTION`).
3. Confirmar ou rever o [ADR-010](../05-decisions/ADR-010-fila-de-analise.md).
4. Reavaliar a decisão sobre MCP se o cofre passar a ter conteúdo fora do
   repositório, ou se fizer falta consultar o grafo.
