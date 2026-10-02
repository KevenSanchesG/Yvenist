---
title: Versão web
type: guide
updated: 2026-10-02
---

# Versão web

A versão web compila, funciona contra a API e é testada a cada envio. Ela
**não é tratada como produto**: o desenho é de celular e há limites conhecidos
([problemas conhecidos](../07-known-issues/README.md), itens KI-30 a KI-33).

## Compilar e servir

```bash
flutter build web --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
python -m http.server 8123 --bind 127.0.0.1 --directory build/web
```

Um build de release só aceita `http` para o próprio computador; para qualquer
outro endereço a API precisa estar em `https`.

## A API precisa autorizar a origem

O navegador só deixa o app chamar a API se ela listar a origem:

```
YVENIST_CORS_ORIGINS=http://127.0.0.1:8123
```

Sem essa variável o CORS fica desligado e toda chamada do navegador falha. Em
produção a API se recusa a subir com `*` ou com uma origem em `http`.

O que a API responde ao navegador (`backend/app/main.py`): métodos `GET`,
`POST`, `PUT`, `PATCH`, `DELETE`; cabeçalhos aceitos `Authorization`,
`Content-Type`, `X-Request-ID`; cabeçalhos expostos `Retry-After`,
`X-Request-ID`; sem cookies.

## Como é testada

No CI, o job `integration` roda os mesmos cenários de integração dentro do
Chrome (`flutter test --platform chrome`). É isso que exercita o CORS e o
cliente HTTP do navegador a cada envio.

No Windows esse comando trava (defeito da ferramenta): detalhes e o jeito de
conferir o build à mão em
[flutter-web-testing](../06-research/flutter-web-testing.md).

## O que muda na web

| Assunto | No celular | Na web |
|---|---|---|
| Tokens | cofre do sistema | armazenamento do navegador (`localStorage`) |
| Imagens de anúncio | qualquer URL `https` | o servidor da imagem precisa permitir CORS |
| Rede | sem restrição de origem | CORS |
| Números | `int` de 64 bits | números de JavaScript: nada de `1 << 32` |
