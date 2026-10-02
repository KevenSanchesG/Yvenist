---
title: CI (GitHub Actions)
type: guide
updated: 2026-10-02
---

# CI (GitHub Actions)

Arquivo: `.github/workflows/ci.yml`. Motivo do desenho:
[ADR-012](../05-decisions/ADR-012-ci-a-cada-envio.md).

## Quando roda

Em todo `push`, em qualquer branch, e por disparo manual (aba *Actions* →
*CI* → *Run workflow*). Um envio novo cancela a execução anterior da mesma
branch.

## O que cada job garante

| Job | Passos | Garante |
|---|---|---|
| `app` | `dart format`, `flutter analyze`, `flutter test`, `python tools/check_docs.py`, os testes de `tools/` e a geração das páginas legais | código formatado, sem apontamentos, testes verdes, Knowledge Base íntegra, páginas legais geradas dos textos do app |
| `backend` | `ruff`, `mypy`, `pytest` em SQLite e depois em PostgreSQL 17 | a API, com os testes de concorrência e as migrações no banco de produção |
| `integration` | migra, semeia, cria um administrador, sobe a API; `flutter test --tags integration` na máquina e com `--platform chrome` | o app real conversa com a API real, também de dentro do navegador |
| `android` | `flutter build apk --debug`; depois cria uma chave de teste, compila `flutter build appbundle --release` e confere quem assinou | o app compila para Android; o pacote de release compila e é assinado pela chave de `android/key.properties` |
| `docker` | `docker compose up --build`, espera `/health/ready`, confere o usuário do processo, semeia e consulta o catálogo; depois sobe a receita de produção de `deploy/` e confere HTTPS, o redirecionamento de `http`, o cabeçalho HSTS, a documentação desligada, a recusa de `seed-demo` e o limite de login atrás do proxy | a imagem e o compose funcionam; a receita de [implantação](deployment.md) sobe com HTTPS e com as travas de produção |

Versões fixadas no topo do arquivo: Flutter 3.41.7, Python 3.14.

## O que o CI cobre e a máquina local não

PostgreSQL com requisições simultâneas, Docker, e os testes dentro do Chrome
(que travam no Windows). Por isso **uma mudança só é dada por verificada
depois que o CI passa**.

## Ler o resultado sem abrir o navegador

O repositório é público: a situação das execuções, dos jobs e de cada passo
pode ser lida pela API do GitHub **sem nenhuma credencial**.

```bash
curl -s "https://api.github.com/repos/KevenSanchesG/Yvenist/actions/runs?per_page=5"
curl -s "https://api.github.com/repos/KevenSanchesG/Yvenist/actions/runs/<id>/jobs"
```

A primeira diz o commit, a situação e a conclusão de cada execução; a segunda,
qual job e qual passo falhou. Sem credencial o limite é de 60 consultas por
hora.

O **log** de um job (`/actions/jobs/<id>/logs`) exige estar autenticado.
Caminhos, do mais simples para o que pede autorização:

1. abrir a aba *Actions* no navegador;
2. instalar a ferramenta oficial `gh` e entrar com `gh auth login`
   (`gh run view <id> --log-failed`). A máquina de desenvolvimento não a tem;
3. usar a credencial que o Git guarda na máquina. **Só com autorização dos
   donos para a tarefa em questão**, e sem nunca exibir, registrar ou gravar o
   valor. Foi o que se fez em 2 de outubro de 2026, com essa autorização.

## Quando um job falha

1. Achar o passo que falhou em `/actions/runs/<id>/jobs`.
2. Ler o log do job e procurar `##[error]` e a linha do teste.
3. Reproduzir localmente, se a máquina conseguir; senão, raciocinar pelo log.
4. Corrigir a causa e enviar de novo. Não desligar o passo nem marcar o teste
   como pulado para "passar".

## O que o CI não cobre

iOS (pediria um executor macOS), a chave de envio de verdade (o pacote de
release é assinado com uma chave de teste criada no próprio job), desempenho, e
qualquer coisa em um servidor de verdade (não existe): a receita de produção é
conferida com o domínio `localhost` e um certificado de teste.
