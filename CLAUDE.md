# Yvenist

Marketplace de festas e eventos, de Rafael e Keven. Duas peças no mesmo
repositório: o app Flutter (`lib/`) e a API FastAPI com PostgreSQL
(`backend/`). Sem `API_BASE_URL` o app roda sozinho, em modo demonstração.

Fale com os donos em português do Brasil.

<!-- Para quem mantém este arquivo: ele é carregado inteiro em toda sessão.
     Mantenha abaixo de 200 linhas. O que vale só para uma área vai para
     .claude/rules/ (carrega sob demanda); o que é explicação vai para docs/. -->

## Memória do projeto

A Knowledge Base é a pasta `docs/`, que também é um cofre do Obsidian. O índice
é `docs/00-project/memory-system.md`.

**Ao começar uma sessão**, antes de qualquer tarefa:

1. Leia `docs/00-project/memory-system.md`.
2. Rode `git status` e `git log --oneline -10`.
3. Pelo mapa do índice, abra só os documentos da tarefa e os ADRs que eles citam.
4. Se um documento e o código discordarem, o código vence: corrija o documento
   na mesma tarefa.

**Para consultar**: parta do índice, ou busque o termo em `docs/` com Grep, e
abra o documento que responde. Nunca leia o cofre inteiro.

**Ao terminar uma tarefa relevante** (mudou comportamento, regra, estrutura,
decisão, limite conhecido ou o jeito de trabalhar): use a skill
`/atualizar-memoria`. Correção de texto e ajuste de estilo não entram.

No cofre, texto sem rótulo é fato do código, com o caminho ao lado.
`[DECISÃO]`, `[INFERÊNCIA]`, `[PROPOSTA]`, `TODO` e `OPEN QUESTION` marcam o
resto. Não escreva como fato o que não está no código.

## Arquitetura em cinco linhas

- **App**: pastas por funcionalidade, `lib/features/<x>/{domain,data,presentation}`.
  As telas conhecem contratos (`*Repository`); só `lib/app/app_dependencies.dart`
  escolhe entre as implementações `Api*` e `InMemory*`.
- **Estado**: Provider + `ChangeNotifier`. **Erros**: `AppFailure`, com mensagem
  em português e `code` estável; nenhuma exceção chega a um widget.
- **API**: `backend/app/modules/<módulo>/{router,service,models,schemas}.py`,
  SQLAlchemy síncrono, Alembic.
- **Party Maker**: as regras existem no app (`Party`) e na API
  (`reconcile` em `backend/app/modules/parties/domain.py`) e mudam juntas.
- Detalhes: `docs/01-architecture/overview.md`. Os princípios que o código
  segue em todo lugar: `docs/01-architecture/principles.md`.

## Comandos

Da raiz:

```bash
dart format lib test
flutter analyze
flutter test
python tools/check_docs.py
```

De `backend/` (com o ambiente virtual `.venv`):

```bash
ruff check . && ruff format --check .
mypy app tests
pytest -q
```

Integração, PostgreSQL, capturas de tela, web e publicação:
`docs/09-guides/development.md`.

## Regras críticas

1. **Operações destrutivas**: antes de apagar dados reais, rodar migração
   destrutiva, remover tabela ou zerar um banco, pare e explique o risco. Para
   código e arquivos do projeto há autonomia para reorganizar e remover o que
   for comprovadamente obsoleto.
2. **Git**: trabalhe em `feat/professional-foundation`, um commit por etapa
   concluída e verificada. Envio ao GitHub (`push`) e mesclagem na `main` só
   quando os donos pedirem.
3. **Segredos**: nunca em código, teste, documento, commit ou log. Credencial
   de teste só em banco descartável. Não exiba nem grave credenciais da máquina.
4. **Não invente** telas, funções ou dados. O que não existe aparece como
   "Em breve".
5. **Marca e textos jurídicos são dos donos**: o tom do laranja e a versão
   final dos termos não são decisões técnicas.
6. **Não desligue nem contorne** o Controle Inteligente de Aplicativos do
   Windows.
7. **Regra do Party Maker** muda no app e na API, com teste dos dois lados e o
   mesmo código de erro.
8. **Mudou um modelo** → migração nova. Nunca edite uma migração já enviada.
9. **Mudou o que o app coleta ou guarda** → atualize
   `assets/legal/politica-de-privacidade.md`.
10. **Defeito**: primeiro o teste que o reproduz (comentário `Regressão:`),
    depois a correção.
11. **Só diga "verificado" com evidência**: um comando que rodou ou um job do
    CI. O que não foi verificado é dito.

## Convenções

- Identificadores em inglês; comentários e textos de interface em português.
  Comentário explica o porquê.
- Commits em inglês, `tipo(escopo): resumo`. No PowerShell use
  `git commit -F arquivo.txt` (aspas duplas quebram o `-m`).
- Cor de texto só pelos tokens de `lib/core/theme/`. `AppColors.primary`
  (`#FF6600`) nunca é cor de texto.
- Nome de teste em português, descrevendo o comportamento.
- As regras de cada área estão em `.claude/rules/` e carregam sozinhas quando
  um arquivo da área é lido.

## Ambiente

Máquina de desenvolvimento: Windows 11 com PowerShell, sem Docker, sem `gh`.
Só o CI verifica PostgreSQL com concorrência, Docker e os testes dentro do
Chrome: uma mudança só está verificada depois que o CI passa
(`docs/09-guides/ci.md`).
