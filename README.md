# Yvenist 🎉

### The All-in-One Marketplace for Events & Parties

> Connecting people who want to celebrate with the best venues and service providers — all in one place.

---

## 📱 About

**Yvenist** is a marketplace dedicated to the events and parties sector, inspired by Airbnb's model. Instead of searching for venues on Google and collecting quotes over WhatsApp, the organizer discovers venues and services, assembles the whole party in one place and requests a single quote. Suppliers register their business, go through a review step and get their listings published.

The repository holds two pieces:

| Piece | Where | What it is |
|---|---|---|
| **App** | `lib/` | Flutter app (Android, iOS, web) for clients and suppliers |
| **API** | `backend/` | FastAPI + PostgreSQL service the app talks to |

The app also runs **without the API**, in *demo mode*, with sample data kept in memory. That is the default: `flutter run` is enough to see every screen working.

---

## ✅ What works today

| Area | Status |
|---|---|
| Browse the catalog: home showcase, categories, event types, sorting, infinite scroll | Working |
| Search by text (ignores accents and capitalization) | Working |
| Accounts: sign up, sign in, restore session, edit profile, change password, delete account | Working |
| Favorites, synced per account | Working |
| **Party Maker**: build a party from listings, running total, request a quote (locks the party), unlock to edit | Working |
| Supplier onboarding: 6-step venue registration with CPF/CNPJ validation | Working |
| Review pipeline: suppliers and listings are published only after approval | Working in the API (admin endpoints; no admin screen yet) |
| Client / Supplier mode switch on the Profile tab | Working (supplier mode shows listing counters) |

### 🚧 Planned, not built yet

The app shows these as "Em breve" ("coming soon") instead of pretending they exist:

- Payments, payment history and payouts
- Chat between clients and suppliers
- Reviews and ratings written by users
- Notifications
- Listing photos upload, availability calendar, listing details page
- Two-factor authentication and the "connected devices" screen (the API already lists and revokes sessions)
- Supplier registration for categories other than venues
- Terms of Use and Privacy Policy texts

---

## 📸 Screenshots

Generated from the real screens by an automated test (`test/visual/screenshots_test.dart`), so they never drift from the code.

| Home | Explore | Party Maker | Profile |
|---|---|---|---|
| ![Home](docs/screenshots/home.png) | ![Explore](docs/screenshots/explorar.png) | ![Party Maker](docs/screenshots/party-maker.png) | ![Profile](docs/screenshots/perfil.png) |

| Add to a party | Sign in | Supplier invitation | Supplier form |
|---|---|---|---|
| ![Add to party](docs/screenshots/adicionar-a-festa.png) | ![Sign in](docs/screenshots/entrar.png) | ![Supplier invitation](docs/screenshots/fornecedor-convite.png) | ![Supplier form](docs/screenshots/fornecedor-validacao.png) |

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| App | Flutter 3.41 · Dart 3.11 |
| App state | Provider + `ChangeNotifier` controllers |
| App networking | `http`, tokens in the system keystore (`flutter_secure_storage`) |
| API | Python 3.14 · FastAPI · Pydantic 2 |
| Persistence | SQLAlchemy 2 · Alembic migrations · PostgreSQL 17 (SQLite for local development) |
| Authentication | Short-lived JWT access token + rotating refresh token, Argon2id password hashing |
| Quality | `flutter analyze` (strict), `ruff`, `mypy --strict`, GitHub Actions |

---

## 🚀 Getting Started

### Demo mode (no backend)

```bash
git clone https://github.com/KevenSanchesG/Yvenist.git
cd Yvenist
flutter pub get
flutter run
```

The app opens signed in with a demo account. After signing out, use `demo@yvenist.app` / `demonstracao`. Everything lives in memory and is reset when the app restarts.

### With the API

```bash
# 1. Start the API (details and Docker option in backend/README.md)
cd backend
python -m venv .venv
.venv\Scripts\activate                 # Linux/macOS: source .venv/bin/activate
pip install -r requirements-dev.txt
alembic upgrade head
python -m app.cli seed-demo            # sample listings
uvicorn app.main:get_app --factory

# 2. Run the app pointing at it
cd ..
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1    # Android emulator
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1   # web / desktop
```

`10.0.2.2` is how the Android emulator reaches the computer it runs on. Plain `http` is accepted only in debug builds; a release build refuses an `API_BASE_URL` that is not `https`.

---

## 🧪 Tests

```bash
flutter analyze
flutter test                         # 442 tests: units, widget flows, accessibility

cd backend
pytest                               # 339 tests on in-memory SQLite
ruff check . && mypy app tests
```

| Suite | What it proves |
|---|---|
| App unit tests | Domain rules, controllers, repositories (API ones against a fake HTTP layer) |
| App flow tests | The whole app in demo mode on a phone-sized screen: browse, search, sign in, build a party, supplier onboarding |
| Accessibility tests | 48×48 touch targets, labels for screen readers, color contrast (WCAG AA), no layout overflow with the system font at 200% |
| Backend tests | Every endpoint, the party rules, migrations equal to the models |
| Backend on PostgreSQL | Same suite plus truly simultaneous requests: `YVENIST_TEST_DATABASE_URL=postgresql+psycopg://... pytest` |
| Integration tests | The real app code against a running API: `YVENIST_API_URL=http://127.0.0.1:8000/api/v1 flutter test --tags integration test/integration` |

CI (`.github/workflows/ci.yml`) runs all of the above, builds the Android APK and boots the Docker image on every push.

---

## 🏗️ Architecture

Feature-first folders with Clean Architecture layers inside each feature; the screens depend on repository *contracts*, and one composition root decides whether they are served by the API or by the in-memory demo data.

```
lib/
  app/        composition root, app-wide state, shell with the bottom navigation
  core/       config, HTTP client, token storage, theme, shared widgets, errors
  features/
    auth/          session, sign in, sign up
    catalog/       listings, categories, search (domain + data)
    client/        home, explore, search, favorites, profile screens
    party_maker/   the party aggregate, its rules and screens
    vendor/        supplier registration and status
    shared_features/  chat, notifications, payments, legal, security
backend/      the API (see backend/README.md)
docs/         architecture notes, Android release guide, screenshots
test/         unit, widget-flow, accessibility and integration tests
```

Developer documentation is written in Portuguese, like the code comments:

- [`docs/arquitetura.md`](docs/arquitetura.md) — how the app and the API are organized, and why
- [`docs/publicacao-android.md`](docs/publicacao-android.md) — signing and publishing checklist
- [`backend/README.md`](backend/README.md) — running, configuring and testing the API

---

## 👨‍💻 Author

**Keven Gualandi**
CS Student @ UERJ | Flutter & Python Developer

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0A66C2?style=flat&logo=linkedin&logoColor=white)](https://linkedin.com/in/keven-gualandi)
[![GitHub](https://img.shields.io/badge/GitHub-181717?style=flat&logo=github&logoColor=white)](https://github.com/KevenSanchesG)

---

## 📄 License

This project is currently in stealth mode. All rights reserved.
