---
title: Implantação da API em produção
type: guide
updated: 2026-10-02
---

# Implantação da API em produção

**A API nunca foi implantada.** Não existe servidor, banco de produção nem
endereço público. Este guia diz o que o repositório já entrega para isso, o
que foi conferido e o que depende dos donos
([KI-03](../07-known-issues/README.md)).

## Os ambientes

| Ambiente | Onde roda | Banco | Endereço | Como é ligado |
|---|---|---|---|---|
| Desenvolvimento | a máquina de quem programa | SQLite em um arquivo local, ou o PostgreSQL do `docker-compose.yml` | `http://127.0.0.1:8000` | `YVENIST_ENV=development` (o padrão) |
| Teste | a suíte e o CI | SQLite em memória; PostgreSQL 17 no CI | sem rede (cliente de teste); `http://127.0.0.1:8000` no job de integração | `env="test"` em `backend/tests/conftest.py` |
| Produção | **não existe** | PostgreSQL | OPEN QUESTION | `YVENIST_ENV=production` |

O app conhece um endereço só, o de `--dart-define=API_BASE_URL`, fixado na
hora do build (`lib/core/config/app_config.dart`). Não há endereço de API
escrito no código do app nem da API.

## O que muda com `YVENIST_ENV=production`

A API **se recusa a subir** se (`backend/app/core/config.py`):

- `YVENIST_JWT_SECRET` for o de desenvolvimento ou tiver menos de 32 caracteres;
- `YVENIST_PASSWORD_HASH_PROFILE` for `test`;
- `YVENIST_CORS_ORIGINS` tiver `*` ou uma origem que não comece com `https://`.

E passa a:

- mandar `Strict-Transport-Security` (um ano) em toda resposta, para o
  navegador nunca mais tentar `http` (`backend/app/core/logging.py`);
- esconder `/docs` e `/openapi.json`;
- recusar o comando `seed-demo`.

O que **não** muda: o limite de tentativas continua na memória de cada
processo ([KI-20](../07-known-issues/README.md)), e com SQLite a API sobe, só
avisando no log.

A lista completa das variáveis está em
[`backend/README.md`](../../backend/README.md). Em produção são obrigatórias
`YVENIST_ENV`, `YVENIST_JWT_SECRET` e `YVENIST_DATABASE_URL`
(`postgresql+psycopg://…`).

## HTTPS: quem faz o quê

A API não fala HTTPS. Quem atende a internet é um **proxy** na frente dela.

| Quem | O que faz | Onde |
|---|---|---|
| Proxy | tem o certificado, redireciona `http` para `https`, repassa a requisição dizendo de quem ela veio (`X-Forwarded-For`) | `deploy/Caddyfile`, ou o da hospedagem |
| API | lê o endereço do cliente que o proxy informou; manda o cabeçalho HSTS | `--proxy-headers` no `backend/Dockerfile` |
| App | em release só aceita `API_BASE_URL` com `https` | `lib/core/config/app_config.dart` |
| Android | bloqueia `http` fora do build de debug | `android/app/src/debug/AndroidManifest.xml` |

Não há cookies: a sessão vai no cabeçalho `Authorization`.

### O endereço do cliente e o limite de tentativas

O login aceita 10 tentativas por minuto **por IP**. Atrás de um proxy, o IP
que a API enxerga é o do proxy, a não ser que ela confie nele. Quem diz em
quais proxies confiar é a variável `FORWARDED_ALLOW_IPS` (do servidor uvicorn,
sem o prefixo `YVENIST_`); o padrão é só a própria máquina.

| `FORWARDED_ALLOW_IPS` | Efeito |
|---|---|
| não inclui o proxy | **todos os clientes dividem o mesmo limite**: dez tentativas erradas de qualquer pessoa bloqueiam o login de todo mundo por um minuto |
| o IP ou a rede do proxy (`10.0.0.0/8`) | cada cliente tem o seu limite |
| `*` | idem, mas só é seguro se a API só for alcançável pelo proxy **e** ele descartar o `X-Forwarded-For` que vier do cliente. Senão o cliente inventa um IP a cada tentativa |

## Caminho A: servidor próprio, com a receita de `deploy/`

Um servidor Linux com Docker, um domínio e três arquivos:

| Arquivo | Papel |
|---|---|
| `deploy/docker-compose.yml` | PostgreSQL, migrações, API e proxy. Só o proxy publica portas (80 e 443) |
| `deploy/Caddyfile` | o proxy (Caddy): obtém e renova o certificado sozinho e redireciona `http` |
| `deploy/.env.example` | modelo do `deploy/.env`, com o domínio e os dois segredos |

1. No DNS do domínio, um registro `A` do nome da API apontando para o IP do
   servidor. Portas 80 e 443 abertas.
2. `cp deploy/.env.example deploy/.env` e preencher. Os dois segredos são
   gerados no próprio servidor (os comandos estão no arquivo) e não saem dele.
3. `docker compose -f deploy/docker-compose.yml up --detach --build`
4. Criar o primeiro administrador (a senha é pedida sem aparecer):
   `docker compose -f deploy/docker-compose.yml exec api python -m app.cli create-admin --email voce@dominio`
5. Conferir, como na seção [Conferência](#conferência).

Atualizar é repetir o passo 3 depois de `git pull`: as migrações rodam antes
de a API subir.

Nessa receita a API usa `FORWARDED_ALLOW_IPS=*`. É seguro ali porque a porta
dela não é publicada e o Caddy descarta o `X-Forwarded-For` do cliente.

## Caminho B: uma plataforma que roda contêineres

A plataforma cuida do certificado e do proxy. O que configurar:

| Item | Valor |
|---|---|
| Imagem | a de `backend/Dockerfile` (o comando de início já está nela) |
| Banco | um PostgreSQL gerenciado; a URL vai em `YVENIST_DATABASE_URL` |
| Antes de cada versão | `alembic upgrade head` |
| Verificação de saúde | `GET /health/ready` |
| Variáveis | `YVENIST_ENV=production`, `YVENIST_JWT_SECRET`, `YVENIST_DATABASE_URL` |
| `FORWARDED_ALLOW_IPS` | a rede do proxy da plataforma, conforme a documentação dela. Confira com o teste da seção [Conferência](#conferência) |

Se o comando de início for trocado, mantenha `--proxy-headers` e
`--no-access-log`: sem o segundo, o servidor passa a gravar o IP de cada
acesso, e a [política de privacidade](../03-features/legal.md) diz que o IP só
fica em memória.

## Rotina

| O quê | Como | Frequência |
|---|---|---|
| Cópia de segurança do banco | `pg_dump` (no caminho A: `docker compose -f deploy/docker-compose.yml exec -T db pg_dump -U yvenist yvenist`) | OPEN QUESTION: o prazo de guarda é uma das lacunas dos textos legais |
| Apagar sessões vencidas | `python -m app.cli purge-tokens --older-than-days 30` | semanal |
| Trocar `YVENIST_JWT_SECRET` | trocar o valor e reiniciar. **Encerra todas as sessões** | se houver suspeita de vazamento |

## Conferência

Depois de subir, com o endereço público no lugar de `API`:

```bash
curl -s https://API/health/ready                      # {"status":"ok"}
curl -s -o /dev/null -w '%{http_code}\n' http://API/health/live   # 301 ou 308: http redireciona
curl -s -D - -o /dev/null https://API/health/live | grep -i strict-transport-security
curl -s -o /dev/null -w '%{http_code}\n' https://API/docs          # 404
```

O endereço do cliente: de **duas redes diferentes** (o Wi-Fi e o 4G de um
celular, por exemplo), errar a senha onze vezes em uma delas. A décima primeira
responde 429; na outra rede o login continua respondendo 401. Se as duas
receberem 429, a API não está confiando no proxy.

Só então gerar o app apontando para ela
([android-release](android-release.md)):

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://API/api/v1
```

## O que foi conferido

| O quê | Como |
|---|---|
| A API em modo de produção: recusa segredo fraco e origem em `http`, manda HSTS, esconde a documentação, recusa `seed-demo`, migra o banco | testes em `backend/tests/` e, com o processo de verdade, na máquina de desenvolvimento em 2 de outubro de 2026 |
| O limite por IP com proxy confiável e sem | idem, com o processo de verdade |
| A receita de `deploy/`: sobe com HTTPS, redireciona `http`, e inventar `X-Forwarded-For` não zera o limite | job `docker` do [CI](ci.md), com o domínio `localhost` e o certificado de teste do Caddy |

**Não conferido:** um servidor de verdade, um certificado emitido pela Let's
Encrypt, o DNS, a restauração de uma cópia de segurança, carga.

## Decisões dos donos

Estão no [roadmap](../00-project/roadmap.md): onde hospedar, o endereço da API
e quem guarda os segredos.
