---
title: Guia de desenvolvimento
type: guide
updated: 2026-10-02
---

# Guia de desenvolvimento

Como rodar, testar e verificar. Configuração da API (variáveis `YVENIST_*`,
comandos de administração): [`backend/README.md`](../../backend/README.md).

## Versões

Flutter 3.41.7 (Dart 3.11), Python 3.14 (mínimo 3.12), PostgreSQL 17. São as
mesmas do CI (`.github/workflows/ci.yml`).

## Rodar o app

```bash
flutter pub get
flutter run                                    # modo demonstração, sem API
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1    # emulador Android → API local
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1   # web ou desktop → API local
```

`10.0.2.2` é como o emulador Android enxerga o computador. No modo
demonstração a conta é `demo@yvenist.com.br` / `demonstracao`.

## Rodar a API

```bash
cd backend
python -m venv .venv && .venv\Scripts\activate     # Linux/macOS: source .venv/bin/activate
pip install -r requirements-dev.txt
alembic upgrade head            # cria o banco (SQLite em ./yvenist.db)
python -m app.cli seed-demo     # anúncios de exemplo
uvicorn app.main:get_app --factory --reload
```

Documentação interativa em `http://127.0.0.1:8000/docs`.

## Verificar antes de enviar

É o que o CI roda. Da raiz:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
python tools/check_docs.py
python -m unittest discover -s tools -p "test_*.py"
```

De `backend/`:

```bash
ruff check . && ruff format --check .
mypy app tests
pytest -q
```

## Testes que pedem algo a mais

| Teste | Como |
|---|---|
| API em PostgreSQL (inclui concorrência) | `YVENIST_TEST_DATABASE_URL=postgresql+psycopg://usuario:senha@host/banco_vazio pytest -q`. **O banco é apagado e recriado** |
| Integração app ↔ API | subir a API com `YVENIST_RATE_LIMIT_ENABLED=false` e `YVENIST_PASSWORD_HASH_PROFILE=test`, depois `YVENIST_API_URL=http://127.0.0.1:8000/api/v1 flutter test --tags integration test/integration` |
| Cenários da fila de análise | além disso: `python -m app.cli create-admin --email admin@example.com` e as variáveis `YVENIST_ADMIN_EMAIL` / `YVENIST_ADMIN_PASSWORD` |
| Integração dentro do navegador | só no CI ([web](web.md)) |
| Regenerar as capturas de tela, nos dois temas | `flutter test --update-goldens --run-skipped --tags screenshots test/visual/screenshots_test.dart` ([screens](../04-ux/screens.md)) |

No PowerShell as variáveis são definidas antes do comando:
`$env:YVENIST_API_URL = 'http://127.0.0.1:8000/api/v1'`.

## Windows com Controle Inteligente de Aplicativos

A máquina de desenvolvimento tem essa proteção ligada. **Ela não deve ser
desligada nem contornada.** O que ela bloqueia e o que fazer:

| Bloqueado | Contorno |
|---|---|
| Extensões compiladas do SQLAlchemy e do mypy | instalar as versões em Python puro (comandos em `backend/README.md`) |
| `psql.exe` | não é necessário: o driver `psycopg` funciona |
| Docker | não está instalado; a imagem é conferida pelo CI |

Para testar em PostgreSQL sem instalar: os binários portáteis do PostgreSQL 17
em uma pasta temporária (`initdb`, `pg_ctl start` em uma porta livre,
`createdb`), apagados ao terminar. Ou deixar para o CI, que roda a suíte em
PostgreSQL a cada envio.

No PowerShell, mensagens de commit com aspas duplas quebram o `git commit -m`:
use `git commit -F arquivo.txt`.

## Git

- Branch de trabalho: `feat/professional-foundation`. Um commit por etapa
  concluída e verificada. Mensagens em inglês, no formato
  `tipo(escopo): resumo` (`feat`, `fix`, `test`, `docs`, `ci`, `chore`,
  `refactor`, `style`).
- **Nada é enviado ao GitHub nem mesclado na `main` sem o pedido dos donos.**
  Quando pedirem: enviar a branch, esperar o CI passar e só então avançar a
  `main` até o mesmo commit (`git push origin feat/professional-foundation:main`),
  sem commit de mesclagem. Foi assim em 2 de outubro de 2026.
- A identidade do Git está configurada só neste repositório, não globalmente.

## Antes de mexer no banco

Mudou um modelo → migração nova (`alembic revision --autogenerate -m "…"`,
revisada à mão) e `tests/test_migrations.py` verde. Antes de apagar dados
reais, executar migração destrutiva ou zerar um banco: **parar e explicar o
risco**. Hoje não existe banco de produção.
