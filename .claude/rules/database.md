---
paths:
  - "backend/app/**/models.py"
  - "backend/migrations/**"
  - "backend/app/core/database.py"
---

# Banco de dados

Contexto completo: `docs/01-architecture/data-model.md`.

- Mudou um modelo → migração nova em `backend/migrations/versions/`
  (`alembic revision --autogenerate -m "…"`, revisada à mão).
- **Nunca edite uma migração que já foi enviada.** Corrija com outra.
- `backend/tests/test_migrations.py` tem de continuar verde: o banco criado
  pelas migrações é idêntico ao dos modelos, em SQLite e em PostgreSQL, e o
  `downgrade` funciona.
- Enum é texto + `CHECK` (`str_enum`), não o tipo `ENUM` do PostgreSQL.
- Regra do tipo "só pode existir um" vira índice único (parcial, se preciso).
- Chave estrangeira diz o que acontece ao apagar: `CASCADE` a partir da conta;
  `SET NULL` onde o registro deve sobreviver (item de festa, quem analisou).
- Coluna com dado pessoal novo → atualize
  `assets/legal/politica-de-privacidade.md` e `docs/01-architecture/security.md`.
- Migração que apaga coluna, tabela ou dados, ou qualquer comando contra um
  banco com dados reais: **pare e explique o risco antes**.
- Atualize `docs/01-architecture/data-model.md` na mesma tarefa.
