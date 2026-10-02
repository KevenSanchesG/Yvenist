---
title: "Pesquisa: rodar os testes do Flutter dentro do navegador"
type: research
date: 2026-10-02
---

# Pesquisa: rodar os testes do Flutter dentro do navegador

**Pergunta:** como provar que o app web conversa com a API (CORS, cliente HTTP
do navegador), e não só que ele compila?

**Fonte:** experimento neste projeto em 2026-10-02, com Flutter 3.41.7, Chrome
e a API local. Não é documentação: é o que foi observado.

## O que funciona

`flutter test --platform chrome` compila os testes para JavaScript e os roda
em um Chrome sem janela. Os testes de integração do projeto
(`test/integration/`) usam o código real do app; rodando ali, as chamadas saem
pelo cliente HTTP do navegador e passam pelo CORS da API.

No CI (Linux) isso roda a cada envio, com a API e o PostgreSQL no mesmo job:

```
flutter test --platform chrome --tags integration test/integration \
  --dart-define=YVENIST_API_URL=http://127.0.0.1:8000/api/v1 \
  --dart-define=YVENIST_ADMIN_EMAIL=… --dart-define=YVENIST_ADMIN_PASSWORD=…
```

A API precisa aceitar a origem do teste, que sai de uma porta sorteada: no CI,
`YVENIST_CORS_ORIGINS=*` (só porque o banco é descartável).

## O que não funciona: Windows

Na máquina de desenvolvimento o mesmo comando trava em "loading …". Inspeção
pela porta de depuração do Chrome mostrou duas falhas do executor de testes:

1. Com o teste em uma subpasta: `Web test for integrationapi_integration_test.dart
   not found`. O separador de pasta se perde.
2. Com o teste na raiz de `test/`: o servidor de testes responde 404 para
   `canvaskit/chromium/canvaskit.js`, embora o arquivo exista no cache do SDK.

`[INFERÊNCIA]` São defeitos do tratamento de caminhos da ferramenta no Windows:
o mesmo comando, o mesmo código e a mesma versão passam no Linux do CI. Não
foi procurado um relato no repositório do Flutter.

## O que os testes precisam para rodar nos dois lugares

| Cuidado | Por quê |
|---|---|
| Sem `dart:io` direto | não existe no navegador. A configuração é lida por `test/support/test_environment.dart`, com importação condicional |
| Valores por `--dart-define` | não há variáveis de ambiente no navegador |
| Nada de `1 << 32` | em JavaScript os deslocamentos são de 32 bits e o resultado é 0. `random.nextInt(1 << 32)` lançava `RangeError` em 22 dos 28 cenários; hoje a faixa é a constante `0xFFFFFFFF` |
| API com a origem liberada | senão toda chamada falha por CORS |

## Como o build web real foi conferido

Sem o executor de testes: `flutter build web` apontando para a API local, um
servidor de arquivos, e um Chrome sem janela controlado por script pelo
protocolo de depuração (toques, digitação, capturas e registro das chamadas à
API). Conferido: vitrine carregada da API, login, sessão recuperada ao
recarregar, fila de análise, tela de termos.

## Achados que viraram correção

- A API não expunha `Retry-After` nem `X-Request-ID` ao navegador (correção em
  `backend/app/main.py`).
- Os cartões e listas suspensas saíam rosados (tema; veja o
  [ADR-008](../05-decisions/ADR-008-acessibilidade-e-cores.md)).
