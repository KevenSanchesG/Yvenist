@Tags(['integration'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/app/app_dependencies.dart';
import 'package:yvenist/app/app_state.dart';
import 'package:yvenist/core/config/app_config.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/network/api_client.dart';
import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/core/storage/token_storage.dart';
import 'package:yvenist/core/utils/brazilian_documents.dart';
import 'package:yvenist/core/utils/id_generator.dart';
import 'package:yvenist/features/admin/domain/review_models.dart';
import 'package:yvenist/features/auth/presentation/controllers/session_controller.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/client/shared/listing_party_item_catalog.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_history_entry.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/configured_item.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_date.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_details.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/guest_count.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_relation.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_draft.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/pricing.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/vendor_response.dart';
import 'package:yvenist/features/vendor/domain/vendor_models.dart';

import '../support/test_environment.dart';

/// O app de verdade contra a API de verdade.
///
/// Cada "aparelho" é montado como em produção (`AppDependencies.api` e
/// `AppState`), só que com os tokens em memória. Nada é simulado: as chamadas
/// saem pela rede e batem no banco.
///
/// Como rodar (veja `backend/README.md` para subir a API):
///
/// ```
/// $env:YVENIST_API_URL = 'http://127.0.0.1:8000/api/v1'
/// flutter test --tags integration test/integration
/// ```
///
/// Sem `YVENIST_API_URL` os testes são pulados. A API precisa:
/// - ter os anúncios de demonstração (`python -m app.cli seed-demo`);
/// - estar com o limite de requisições desligado
///   (`YVENIST_RATE_LIMIT_ENABLED=false`): os testes criam várias contas.
///
/// Os testes da fila de análise só rodam se `YVENIST_ADMIN_EMAIL` e
/// `YVENIST_ADMIN_PASSWORD` apontarem para uma conta criada com
/// `python -m app.cli create-admin`.
///
/// Os mesmos testes rodam dentro do navegador, que é o que prova que o app
/// web conversa com a API (CORS e o cliente HTTP do navegador). Lá os valores
/// vão por `--dart-define`, e a API precisa autorizar a origem do teste:
///
/// ```
/// flutter test --platform chrome --tags integration test/integration `
///   --dart-define=YVENIST_API_URL=http://127.0.0.1:8000/api/v1
/// ```
void main() {
  final apiUrl = AppConfig.parseBaseUrl(
    testEnvironment('YVENIST_API_URL') ?? '',
  );
  final adminEmail = testEnvironment('YVENIST_ADMIN_EMAIL');
  final adminPassword = testEnvironment('YVENIST_ADMIN_PASSWORD');

  final random = Random();
  final devices = <Device>[];

  /// Liga um aparelho novo; ele é desligado ao fim do teste.
  Future<Device> device() async {
    final created = Device(apiUrl!);
    devices.add(created);
    await created.start();
    return created;
  }

  /// Um aparelho com uma conta recém-criada já autenticada.
  Future<(Device, Account)> signedUpDevice() async {
    final account = Account.unique(random);
    final created = await device();
    await created.signUp(account);
    return (created, account);
  }

  tearDown(() {
    for (final created in devices) {
      created.dispose();
    }
    devices.clear();
  });

  group(
    'app contra a API',
    skip: apiUrl == null
        ? 'Defina YVENIST_API_URL para rodar os testes de integração.'
        : null,
    () {
      group('catálogo público', () {
        test('categorias e tipos de evento vêm do servidor', () async {
          final catalog = (await device()).deps.catalog;

          final categories = await catalog.categories();
          final eventTypes = await catalog.eventTypes();

          expect(categories.first.slug, 'venue');
          expect(categories.first.name, 'Salões');
          expect(categories.map((c) => c.slug), contains('decoration'));
          expect(eventTypes.map((e) => e.slug), contains('wedding'));
        });

        test('a busca ignora acentos e maiúsculas', () async {
          final catalog = (await device()).deps.catalog;

          final page = await catalog.search(
            const ListingQuery(text: 'SALAO GLAMOUR 3'),
          );

          expect(page.items.map((l) => l.title), ['Salão Glamour 3']);
          expect(page.items.single.locationLabel, 'Campo Grande, RJ');
          expect(page.items.single.priceFromCents, 120000);
        });

        test('filtra por categoria e tipo de evento, e ordena', () async {
          final catalog = (await device()).deps.catalog;

          final cheapestVenues = await catalog.search(
            const ListingQuery(
              categorySlug: 'venue',
              sort: ListingSort.priceAsc,
            ),
            limit: 3,
          );
          final prices = [
            for (final listing in cheapestVenues.items) listing.priceFromCents,
          ];
          expect(
            cheapestVenues.items.every((l) => l.categorySlug == 'venue'),
            isTrue,
          );
          expect(prices, [...prices]..sort());

          final weddingDecoration = await catalog.search(
            const ListingQuery(
              text: 'decoração encanto',
              categorySlug: 'decoration',
              eventTypeSlug: 'wedding',
            ),
            limit: 50,
          );
          expect(weddingDecoration.items, hasLength(8));

          // As atrações de demonstração não atendem casamentos.
          final none = await catalog.search(
            const ListingQuery(
              text: 'atração festiva',
              eventTypeSlug: 'wedding',
            ),
          );
          expect(none.items, isEmpty);
          expect(none.hasMore, isFalse);
        });

        test('a paginação por cursor percorre tudo sem repetir', () async {
          final catalog = (await device()).deps.catalog;
          const query = ListingQuery(text: 'glamour');
          final ids = <String>[];
          String? cursor;
          var pages = 0;

          do {
            final page = await catalog.search(query, cursor: cursor, limit: 3);
            ids.addAll(page.items.map((l) => l.id));
            cursor = page.nextCursor;
            pages++;
          } while (cursor != null);

          expect(ids, hasLength(8));
          expect(ids.toSet(), hasLength(8));
          expect(pages, 3);
        });

        test('cursor adulterado é recusado com mensagem', () async {
          final catalog = (await device()).deps.catalog;

          await expectLater(
            catalog.search(const ListingQuery(), cursor: 'adulterado'),
            throwsA(
              isA<ValidationFailure>().having(
                (f) => f.code,
                'code',
                'invalid_cursor',
              ),
            ),
          );
        });
      });

      group('conta', () {
        test(
          'criar conta, reabrir o app, editar dados, trocar senha',
          () async {
            final (phone, account) = await signedUpDevice();
            final session = phone.state.session;
            expect(session.user!.email, account.email);
            expect(session.user!.fullName, account.name);

            // Fechar e abrir o app: a sessão guardada é restaurada.
            await phone.restart();
            expect(phone.state.session.status, SessionStatus.signedIn);
            expect(phone.state.session.user!.email, account.email);

            final saved = await phone.state.session.updateProfile(
              fullName: '  Maria Clara  ',
              phone: '(21) 99999-8888',
              birthDate: DateTime(1995, 5, 20),
            );
            expect(saved, isTrue, reason: phone.state.session.error);
            final user = phone.state.session.user!;
            expect(user.fullName, 'Maria Clara');
            expect(user.phone, '21999998888');
            expect(user.birthDate, DateTime(1995, 5, 20));

            expect(
              await phone.state.session.changePassword(
                currentPassword: 'senha-errada',
                newPassword: 'nova-senha-456',
              ),
              isFalse,
            );
            expect(phone.state.session.error, 'Senha atual incorreta.');

            final before = await phone.tokens.read();
            expect(
              await phone.state.session.changePassword(
                currentPassword: account.password,
                newPassword: 'nova-senha-456',
              ),
              isTrue,
            );
            // A troca encerra as sessões antigas e entrega tokens novos.
            final after = await phone.tokens.read();
            expect(after!.refreshToken, isNot(before!.refreshToken));

            await phone.state.session.signOut();
            expect(await phone.tokens.read(), isNull);

            expect(
              await phone.state.session.signIn(
                email: account.email,
                password: account.password,
              ),
              isFalse,
            );
            expect(phone.state.session.failure, isA<UnauthorizedFailure>());
            expect(phone.state.session.error, 'E-mail ou senha inválidos.');

            expect(
              await phone.state.session.signIn(
                email: account.email.toUpperCase(),
                password: 'nova-senha-456',
              ),
              isTrue,
            );
            expect(phone.state.session.user!.fullName, 'Maria Clara');
          },
        );

        test('e-mail repetido e dados inválidos voltam com o motivo', () async {
          final (_, account) = await signedUpDevice();
          final other = await device();

          expect(
            await other.state.session.signUp(
              fullName: 'Outra Pessoa',
              email: account.email,
              password: 'senha-de-teste-123',
            ),
            isFalse,
          );
          expect(other.state.session.failure, isA<ConflictFailure>());
          expect(
            other.state.session.error,
            'Já existe uma conta com este e-mail.',
          );

          // A tela valida antes; se algo escapar, o servidor aponta o campo.
          expect(
            await other.state.session.signUp(
              fullName: 'Outra Pessoa',
              email: Account.unique(random).email,
              password: 'curta',
            ),
            isFalse,
          );
          final failure = other.state.session.failure;
          expect(failure, isA<ValidationFailure>());
          expect((failure! as ValidationFailure).fieldErrors, {
            'password': 'Use pelo menos 8 caracteres.',
          });
        });

        test('senha muito comum é recusada, e o servidor explica', () async {
          const tooCommon = 'Esta senha é muito comum. Escolha outra.';
          final (phone, account) = await signedUpDevice();
          final session = phone.state.session;

          // Na troca de senha...
          expect(
            await session.changePassword(
              currentPassword: account.password,
              newPassword: 'Password123',
            ),
            isFalse,
          );
          expect(session.error, tooCommon);
          expect((session.failure! as ValidationFailure).fieldErrors, {
            'new_password': tooCommon,
          });

          // ...e no cadastro.
          final other = await device();
          expect(
            await other.state.session.signUp(
              fullName: 'Outra Pessoa',
              email: Account.unique(random).email,
              password: '12345678',
            ),
            isFalse,
          );
          expect(other.state.session.error, tooCommon);
          expect(other.state.session.isSignedIn, isFalse);
        });

        test('token de acesso vencido é renovado sem interromper', () async {
          final (phone, account) = await signedUpDevice();
          final original = (await phone.tokens.read())!;
          await phone.expireAccessToken();

          // Qualquer chamada autenticada: recebe 401, renova e repete.
          final user = await phone.deps.auth.restoreSession();

          expect(user!.email, account.email);
          final renewed = (await phone.tokens.read())!;
          expect(renewed.refreshToken, isNot(original.refreshToken));
          expect(phone.state.session.isSignedIn, isTrue);
        });

        test('várias chamadas com token vencido renovam uma vez só', () async {
          final (phone, _) = await signedUpDevice();
          await phone.expireAccessToken();

          // Renovar em paralelo com o mesmo token seria visto pelo servidor
          // como reuso e encerraria a sessão.
          final results = await Future.wait([
            phone.deps.favorites.list(),
            phone.deps.parties.listByOwner('ignorado'),
            phone.deps.vendors.myProfile(),
          ]);

          expect(results, hasLength(3));
          expect(phone.state.session.isSignedIn, isTrue);
          expect(await phone.tokens.read(), isNotNull);
        });

        test('token de renovação reutilizado encerra a sessão', () async {
          final (phone, _) = await signedUpDevice();
          final stolen = (await phone.tokens.read())!;
          await phone.expireAccessToken();
          await phone.deps.auth.restoreSession(); // renova: `stolen` é passado
          final current = (await phone.tokens.read())!;

          // Alguém com uma cópia do token antigo tenta usá-lo.
          await phone.tokens.write(
            AuthTokens(
              accessToken: 'vencido',
              refreshToken: stolen.refreshToken,
            ),
          );
          await expectLater(
            phone.deps.favorites.list(),
            throwsA(isA<UnauthorizedFailure>()),
          );

          // O app percebe que a sessão acabou e volta a ser visitante...
          expect(phone.state.session.status, SessionStatus.signedOut);
          expect(await phone.tokens.read(), isNull);
          // ...e o token legítimo, da mesma família, também deixa de valer.
          await phone.tokens.write(
            AuthTokens(
              accessToken: 'vencido',
              refreshToken: current.refreshToken,
            ),
          );
          expect(await phone.deps.auth.restoreSession(), isNull);
        });

        test('sair invalida a sessão também no servidor', () async {
          final (phone, _) = await signedUpDevice();
          final tokens = (await phone.tokens.read())!;

          await phone.state.session.signOut();

          await phone.tokens.write(
            AuthTokens(
              accessToken: 'vencido',
              refreshToken: tokens.refreshToken,
            ),
          );
          expect(await phone.deps.auth.restoreSession(), isNull);
        });

        test('excluir a conta exige a senha e apaga o acesso', () async {
          final (phone, account) = await signedUpDevice();

          expect(
            await phone.state.session.deleteAccount(password: 'errada'),
            isFalse,
          );
          expect(phone.state.session.isSignedIn, isTrue);

          expect(
            await phone.state.session.deleteAccount(password: account.password),
            isTrue,
          );
          expect(phone.state.session.status, SessionStatus.signedOut);
          expect(
            await phone.state.session.signIn(
              email: account.email,
              password: account.password,
            ),
            isFalse,
          );
        });
      });

      group('favoritos', () {
        test('favoritar aparece no outro aparelho da mesma conta', () async {
          final (phone, account) = await signedUpDevice();
          final salao = await phone.firstListing('venue');

          expect(await phone.state.favorites.toggle(salao), isTrue);
          // Favoritar duas vezes pelo repositório não duplica.
          await phone.deps.favorites.add(salao);

          final tablet = await device();
          await tablet.signIn(account);
          expect(tablet.state.favorites.items.map((l) => l.id), [salao.id]);
          expect(tablet.state.favorites.items.single.title, salao.title);

          expect(await tablet.state.favorites.toggle(salao), isTrue);
          await phone.state.favorites.load();
          expect(phone.state.favorites.items, isEmpty);
        });

        test('favoritos são de cada conta', () async {
          final (ana, _) = await signedUpDevice();
          final (bruno, _) = await signedUpDevice();
          final salao = await ana.firstListing('venue');

          await ana.state.favorites.toggle(salao);
          await bruno.state.favorites.load();

          expect(ana.state.favorites.isFavorite(salao.id), isTrue);
          expect(bruno.state.favorites.items, isEmpty);
        });

        test(
          'anúncio que não existe é recusado e a tela volta atrás',
          () async {
            final (phone, _) = await signedUpDevice();
            final ghost = Listing(
              id: UuidGenerator().newId(),
              title: 'Anúncio apagado',
              categorySlug: 'venue',
              city: 'Rio de Janeiro',
              state: 'RJ',
              priceFromCents: 100000,
            );

            expect(await phone.state.favorites.toggle(ghost), isFalse);

            expect(phone.state.favorites.isFavorite(ghost.id), isFalse);
            expect(phone.state.favorites.error, 'Anúncio não encontrado.');
          },
        );

        test('sem sessão, favoritos não são acessíveis', () async {
          final guest = await device();

          await expectLater(
            guest.deps.favorites.list(),
            throwsA(isA<UnauthorizedFailure>()),
          );
        });
      });

      group('festas', () {
        test(
          'o que é copiado do catálogo vem do servidor, não do app',
          () async {
            final (phone, _) = await signedUpDevice();
            final salao = await phone.firstListing('venue');
            final real = await phone.draftOf(salao);
            // Um app adulterado tentando gravar outro nome e outro preço.
            final tampered = PartyItemDraft(
              externalRef: real.externalRef,
              category: real.category,
              name: 'Nome inventado',
              pricing: Pricing.fixed(Money.fromCents(1)),
              ownServices: real.ownServices,
            );

            final party = await phone.state.parties.addItemToNewParty(
              event('Casamento'),
              venueSelection(tampered),
            );

            expect(party, isNotNull, reason: phone.state.parties.error);
            final item = party!.budget.venue!;
            expect(party.status, PartyStatus.planning);
            expect(party.ownerId, phone.state.session.user!.id);
            expect(item.nameSnapshot, salao.title);
            expect(item.pricing.model, PricingModel.fixed);
            expect(item.pricing.amount!.cents, salao.priceFromCents);
            expect(item.category, PartyItemCategory.venue);
            expect(item.imageUrlSnapshot, salao.coverImageUrl);
            expect(item.capacity, real.capacity);
            expect(item.vendorId, isNotNull);
            expect(item.estimate(guests: 80)!.cents, salao.priceFromCents);
          },
        );

        test('a configuração é conferida pela categoria de verdade', () async {
          final (phone, _) = await signedUpDevice();
          final real = await phone.draftOf(await phone.firstListing('venue'));
          // Um app adulterado dizendo que o salão é um "produto", para não
          // informar a duração nem os serviços obrigatórios.
          final tampered = PartyItemDraft(
            externalRef: real.externalRef,
            category: PartyItemCategory.other,
            name: real.name,
            pricing: real.pricing,
          );

          final party = await phone.state.parties.addItemToNewParty(
            event('Casamento'),
            ConfiguredItem(draft: tampered),
          );

          expect(party, isNull);
          expect(phone.state.parties.error, isNotNull);
          await phone.state.parties.load();
          expect(phone.state.parties.parties, isEmpty);
        });

        test('montar com serviços do salão, pedir o orçamento, voltar a '
            'editar e desmontar', () async {
          final (phone, account) = await signedUpDevice();
          final parties = phone.state.parties;
          final salao = await phone.firstListing('venue');
          final atracao = await phone.firstListing('attraction');
          final venue = await phone.draftOf(salao);

          // O salão entra com o buffet da casa (por pessoa) e a taxa
          // obrigatória.
          final created = await parties.addItemToNewParty(
            event('15 anos'),
            venueSelection(venue, services: ['Buffet do salão']),
          );
          expect(created, isNotNull, reason: parties.error);
          final partyId = created!.id;
          expect(created.budget.items.map((item) => item.nameSnapshot), [
            salao.title,
            'Buffet do salão',
            'Taxa de limpeza',
          ]);
          expect(created.budget.items.map((item) => item.relation.kind), [
            ItemRelationKind.independent,
            ItemRelationKind.linked,
            ItemRelationKind.required,
          ]);

          final withAttraction = await parties.addItem(
            partyId,
            ConfiguredItem(
              draft: await phone.draftOf(atracao),
              configuration: const {'duration_hours': 4},
            ),
          );
          expect(withAttraction, isNotNull, reason: parties.error);
          expect(parties.isInAnyParty(atracao.id), isTrue);

          // A conta do app e a do servidor dão o mesmo resultado: o salão, o
          // buffet por 80 pessoas, a taxa e a atração por 4 horas.
          final total =
              salao.priceFromCents! +
              4500 * 80 +
              15000 +
              atracao.priceFromCents! * 4;
          expect(withAttraction!.estimate.total.cents, total);
          expect(withAttraction.estimate.isComplete, isTrue);
          final onServer =
              await phone.api.get(
                    '/parties/${partyId.value}',
                    authenticated: true,
                  )
                  as Json;
          expect(onServer['estimate_cents'], total);
          expect(onServer['unpriced_items'], 0);
          expect(onServer['quoted_cents'], isNull);

          expect(await parties.requestQuote(partyId), isTrue);
          final requested = parties.activeParty!;
          expect(requested.status, PartyStatus.locked);
          expect(requested.quoteRound, 1);
          expect(requested.quoteSnapshot!.estimatedTotal.cents, total);
          expect(
            requested.budget.items.map((item) => item.quote.status),
            everyElement(QuoteStatus.pending),
          );
          expect(
            requested.history.single.kind,
            PartyHistoryKind.quoteRequested,
          );

          // Outro aparelho da mesma conta vê a festa como ficou no servidor.
          final tablet = await device();
          await tablet.signIn(account);
          final seen = tablet.state.parties.parties.single;
          expect(seen.title.value, '15 anos');
          expect(seen.status, PartyStatus.locked);
          expect(seen.guestCount!.value, 80);
          expect(seen.estimate.total.cents, total);
          expect(seen.budget.items, hasLength(4));

          // Com o pedido nas mãos dos fornecedores, nada muda...
          expect(
            await parties.removeItem(partyId, requested.budget.venue!.id),
            isNull,
          );
          // ...até a pessoa voltar a editar: o pedido é retirado.
          expect(await parties.reopen(partyId), isTrue);
          final reopened = parties.activeParty!;
          expect(reopened.status, PartyStatus.planning);
          expect(reopened.quoteSnapshot, isNull);
          expect(
            reopened.budget.items.map((item) => item.quote.status),
            everyElement(QuoteStatus.none),
          );

          // Tirar o salão leva os serviços dele; a atração continua.
          final removal = await parties.removeItem(
            partyId,
            reopened.budget.venue!.id,
          );
          expect(removal!.removedWith, hasLength(2));
          expect(
            parties.activeParty!.budget.items.single.nameSnapshot,
            atracao.title,
          );

          // Sem itens, a festa continua existindo, até ser apagada.
          await parties.removeItem(
            partyId,
            parties.activeParty!.budget.items.single.id,
          );
          expect(parties.activeParty!.budget.isEmpty, isTrue);
          await tablet.state.parties.load();
          expect(tablet.state.parties.parties.single.budget.isEmpty, isTrue);

          expect(await parties.deleteParty(partyId), isTrue);
          await tablet.state.parties.load();
          expect(tablet.state.parties.parties, isEmpty);
        });

        test('um item sob consulta entra sem valor, e a estimativa diz o '
            'que ficou de fora', () async {
          final (phone, _) = await signedUpDevice();
          final found = await phone.deps.catalog.search(
            const ListingQuery(text: 'decoração encanto 8'),
          );
          final decoration = found.items.single;
          expect(decoration.pricingModel, PricingModel.onRequest);
          expect(decoration.priceFromCents, isNull);

          final party = await phone.state.parties.addItemToNewParty(
            event('Aniversário'),
            ConfiguredItem(
              draft: await phone.draftOf(decoration),
              configuration: const {'theme': 'Safari'},
            ),
          );

          expect(party, isNotNull, reason: phone.state.parties.error);
          final item = party!.budget.items.single;
          expect(item.pricing.isOnRequest, isTrue);
          expect(item.pricing.amount, isNull);
          expect(item.configuration['theme'], 'Safari');
          expect(party.estimate.total.cents, 0);
          expect(party.estimate.unpricedItems, 1);
        });

        test('o servidor confere de novo o que o app confere', () async {
          final (phone, _) = await signedUpDevice();
          final venues = await phone.deps.catalog.search(
            const ListingQuery(categorySlug: 'venue'),
            limit: 2,
          );
          final first = await phone.draftOf(venues.items.first);
          final second = await phone.draftOf(venues.items.last);
          final ids = UuidGenerator();
          final partyId = ids.newId();
          final eventAt = DateTime.now()
              .add(const Duration(days: 60))
              .toUtc()
              .toIso8601String();

          /// Um salão com a duração e a taxa obrigatória dele.
          List<Json> venueItems(PartyItemDraft venue) {
            final id = ids.newId();
            return [
              {
                'id': id,
                'listing_id': venue.externalRef.id,
                'configuration': {'duration_hours': 4},
              },
              for (final service in venue.ownServices)
                if (service.isRequired)
                  {
                    'id': ids.newId(),
                    'offer_id': service.externalRef.id,
                    'parent_item_id': id,
                  },
            ];
          }

          // Direto na API, pulando as regras que o app aplica antes de enviar.
          Future<Object?> put(
            List<Json> items, {
            String status = 'planning',
            int? guests = 80,
          }) {
            return phone.api.put(
              '/parties/$partyId',
              authenticated: true,
              body: {
                'title': 'Festa adulterada',
                'event_at': eventAt,
                'guest_count': guests,
                'status': status,
                'items': items,
              },
            );
          }

          Matcher refusedWith(String code) =>
              throwsA(isA<AppFailure>().having((f) => f.code, 'code', code));

          await expectLater(
            put([...venueItems(first), ...venueItems(second)]),
            refusedWith('venue_already_selected'),
          );
          // O salão sem a taxa obrigatória dele.
          await expectLater(
            put([venueItems(first).first]),
            refusedWith('required_item_missing'),
          );
          // O salão sem a duração.
          await expectLater(
            put([
              {...venueItems(first).first, 'configuration': <String, Object>{}},
              ...venueItems(first).skip(1),
            ]),
            refusedWith('invalid_item_configuration'),
          );
          // Mais convidados do que o salão comporta.
          await expectLater(
            put(venueItems(first), guests: 100000),
            refusedWith('guest_count_exceeds_capacity'),
          );
          // Um serviço do salão sem o salão na festa.
          await expectLater(
            put([
              {
                'id': ids.newId(),
                'offer_id': first.ownServices.first.externalRef.id,
                'parent_item_id': ids.newId(),
              },
            ]),
            refusedWith('parent_item_missing'),
          );
          // Marcar como paga, ou como "orçamento recebido", não é algo que o
          // cliente possa pedir.
          for (final status in ['paid', 'quoted', 'confirmed']) {
            await expectLater(
              put(venueItems(first), status: status),
              throwsA(isA<AppFailure>()),
              reason: status,
            );
          }

          await phone.state.parties.load();
          expect(phone.state.parties.parties, isEmpty);
        });

        test('edição em dois aparelhos: o atrasado recebe o conflito', () async {
          final (phone, account) = await signedUpDevice();
          final salao = await phone.firstListing('venue');
          final atracao = await phone.firstListing('attraction');
          final buffet = await phone.firstListing('buffet');
          final created = await phone.state.parties.addItemToNewParty(
            event('Formatura'),
            venueSelection(await phone.draftOf(salao)),
          );
          final partyId = created!.id;

          final tablet = await device();
          await tablet.signIn(account);
          expect(
            tablet.state.parties.parties.single.budget.items,
            hasLength(2),
          );

          // O celular altera primeiro; o tablet ainda tem a versão anterior.
          final attraction = ConfiguredItem(
            draft: await phone.draftOf(atracao),
            configuration: const {'duration_hours': 4},
          );
          expect(
            await phone.state.parties.addItem(partyId, attraction),
            isNotNull,
          );
          final buffetSelection = ConfiguredItem(
            draft: await tablet.draftOf(buffet),
            configuration: const {'service_style': 'plated'},
          );
          final stale = await tablet.state.parties.addItem(
            partyId,
            buffetSelection,
          );

          expect(stale, isNull);
          expect(
            tablet.state.parties.error,
            'A festa foi alterada em outro dispositivo. '
            'Atualize e tente novamente.',
          );
          // O tablet já recarregou: vê o que o celular gravou, sem ter perdido
          // nem sobrescrito nada.
          final refreshed = tablet.state.parties.parties.single;
          expect(refreshed.budget.items, hasLength(3));

          // Tentar de novo, agora sobre a versão atual, funciona.
          expect(
            await tablet.state.parties.addItem(partyId, buffetSelection),
            isNotNull,
            reason: tablet.state.parties.error,
          );
          await phone.state.parties.load();
          expect(phone.state.parties.parties.single.budget.items, hasLength(4));
        });

        test('uma festa com o orçamento solicitado só é apagada depois de '
            'cancelada', () async {
          final (phone, _) = await signedUpDevice();
          final parties = phone.state.parties;
          final created = await parties.addItemToNewParty(
            event('Formatura'),
            venueSelection(
              await phone.draftOf(await phone.firstListing('venue')),
            ),
          );
          final partyId = created!.id;
          expect(await parties.requestQuote(partyId), isTrue);

          // O app barra antes; pedindo direto, o servidor também barra.
          expect(await parties.deleteParty(partyId), isFalse);
          await expectLater(
            phone.api.delete('/parties/${partyId.value}', authenticated: true),
            throwsA(
              isA<ConflictFailure>().having(
                (f) => f.code,
                'code',
                'party_has_open_quote',
              ),
            ),
          );

          expect(await parties.cancelParty(partyId), isTrue);
          expect(parties.activeParty!.status, PartyStatus.cancelled);
          expect(
            parties.activeParty!.history.last.kind,
            PartyHistoryKind.cancelled,
          );

          expect(await parties.deleteParty(partyId), isTrue);
          await parties.load();
          expect(parties.parties, isEmpty);
        });

        test('uma conta não lê nem altera a festa de outra', () async {
          final (ana, _) = await signedUpDevice();
          final (bruno, _) = await signedUpDevice();
          final salao = await ana.firstListing('venue');
          await ana.state.parties.addItemToNewParty(
            event('Festa da Ana'),
            venueSelection(await ana.draftOf(salao)),
          );
          final partyId = ana.state.parties.activePartyId!.value;

          await expectLater(
            bruno.api.get('/parties/$partyId', authenticated: true),
            throwsA(isA<NotFoundFailure>()),
          );
          await expectLater(
            bruno.api.put(
              '/parties/$partyId',
              authenticated: true,
              body: {
                'title': 'Agora é do Bruno',
                'status': 'planning',
                'items': <Object>[],
              },
            ),
            throwsA(isA<AppFailure>()),
          );
          await expectLater(
            bruno.api.delete('/parties/$partyId', authenticated: true),
            throwsA(isA<NotFoundFailure>()),
          );

          await ana.state.parties.load();
          final party = ana.state.parties.parties.single;
          expect(party.title.value, 'Festa da Ana');
          expect(party.budget.items, hasLength(2));
          await bruno.state.parties.load();
          expect(bruno.state.parties.parties, isEmpty);
        });

        test('quem não é fornecedor não vê nem responde pedidos de '
            'orçamento', () async {
          final (ana, _) = await signedUpDevice();
          final (bruno, _) = await signedUpDevice();
          final created = await ana.state.parties.addItemToNewParty(
            event('Festa da Ana'),
            venueSelection(await ana.draftOf(await ana.firstListing('venue'))),
          );
          expect(await ana.state.parties.requestQuote(created!.id), isTrue);
          final itemId = created.budget.venue!.id.value;

          // Nem a própria dona da festa responde ao pedido que fez...
          for (final phone in [ana, bruno]) {
            await expectLater(
              phone.deps.quoteInbox.list(),
              throwsA(isA<NotFoundFailure>()),
            );
            await expectLater(
              phone.deps.quoteInbox.respond(
                itemId,
                VendorResponse.quote(Money.fromCents(1)),
              ),
              throwsA(isA<NotFoundFailure>()),
            );
          }
          // ...e a festa continua esperando o fornecedor de verdade.
          await ana.state.parties.load();
          expect(ana.state.parties.parties.single.status, PartyStatus.locked);
          expect(ana.state.parties.parties.single.quotedTotal, isNull);
        });
      });

      group('fornecedor', () {
        HallListingDraft hall({
          required String document,
          String? title,
          List<OfferDraft> offers = const [],
        }) {
          return HallListingDraft(
            personType: PersonType.individual,
            document: document,
            legalName: 'Maria Oliveira',
            title: title ?? 'Espaço Crystal ${random.nextInt(_randomRange)}',
            description: 'Salão amplo, climatizado, com cozinha equipada.',
            neighborhood: 'Pituba',
            city: 'Salvador',
            state: 'BA',
            priceFromCents: 250000,
            offers: offers,
            areaM2: 300,
            capacity: 150,
            eventTypes: const {'wedding', 'debutante'},
            amenities: const {'wifi', 'kitchen'},
            cancellationPolicy: CancellationPolicy.moderate,
          );
        }

        /// Um fornecedor aprovado, com um salão publicado que cobra uma taxa
        /// obrigatória e oferece um buffet por pessoa. Devolve o aparelho
        /// dele e o anúncio como o catálogo o mostra.
        Future<(Device, Listing)> publishedHall(Device admin) async {
          final (vendorPhone, _) = await signedUpDevice();
          final draft = hall(
            document: randomCpf(random),
            offers: const [
              OfferDraft(
                categorySlug: 'other',
                name: 'Taxa de limpeza',
                priceCents: 15000,
                isRequired: true,
              ),
              OfferDraft(
                categorySlug: 'buffet',
                name: 'Buffet da casa',
                pricingModel: PricingModel.perPerson,
                priceCents: 5000,
              ),
            ],
          );
          expect(
            await vendorPhone.state.vendor.submitHall(draft),
            isTrue,
            reason: '${vendorPhone.state.vendor.failure}',
          );
          final queue = await admin.deps.reviews.pending();
          final pending = queue.listings.singleWhere(
            (listing) => listing.title == draft.title,
          );
          await admin.deps.reviews.approveVendor(
            pending.vendorId,
            publishListings: true,
          );

          final found = await vendorPhone.deps.catalog.search(
            ListingQuery(text: draft.title),
          );
          return (vendorPhone, found.items.single);
        }

        test('enviar o salão: fica em análise e fora do catálogo', () async {
          final (phone, _) = await signedUpDevice();
          final vendor = phone.state.vendor;
          expect(vendor.status, VendorStatus.none);
          final cpf = randomCpf(random);
          final draft = hall(document: cpf);

          expect(await vendor.submitHall(draft), isTrue, reason: '$vendor');

          expect(vendor.status, VendorStatus.pendingReview);
          expect(vendor.profile!.legalName, 'Maria Oliveira');
          // O documento volta mascarado: só as pontas.
          expect(
            vendor.profile!.documentMasked,
            '${cpf.substring(0, 3)}.***.***-${cpf.substring(9)}',
          );
          expect(vendor.listings.single.title, draft.title);
          expect(
            vendor.listings.single.status,
            VendorListingStatus.pendingReview,
          );

          // Enquanto não for aprovado, ninguém encontra o anúncio.
          final found = await phone.deps.catalog.search(
            ListingQuery(text: draft.title),
          );
          expect(found.items, isEmpty);
        });

        test('documento inválido ou já usado é recusado', () async {
          final (ana, _) = await signedUpDevice();
          final (bruno, _) = await signedUpDevice();
          final cpf = randomCpf(random);

          expect(
            await ana.state.vendor.submitHall(hall(document: '12345678900')),
            isFalse,
          );
          expect(ana.state.vendor.failure, isA<ValidationFailure>());
          expect(ana.state.vendor.status, VendorStatus.none);

          expect(
            await ana.state.vendor.submitHall(hall(document: cpf)),
            isTrue,
          );
          expect(
            await bruno.state.vendor.submitHall(hall(document: cpf)),
            isFalse,
          );
          expect(bruno.state.vendor.failure, isA<ConflictFailure>());
          expect(
            bruno.state.vendor.failure!.code,
            'document_already_registered',
          );
          expect(bruno.state.vendor.status, VendorStatus.none);
        });

        test('a fila de análise é só para administradores', () async {
          final (phone, _) = await signedUpDevice();

          await expectLater(
            phone.deps.reviews.pending(),
            throwsA(isA<ForbiddenFailure>()),
          );
          await expectLater(
            phone.deps.reviews.approveVendor(
              '00000000-0000-4000-8000-000000000000',
              publishListings: true,
            ),
            throwsA(isA<ForbiddenFailure>()),
          );
        });

        final adminSkip = adminEmail == null || adminPassword == null
            ? 'Defina YVENIST_ADMIN_EMAIL e YVENIST_ADMIN_PASSWORD.'
            : null;

        /// Um aparelho com a conta de administração autenticada.
        Future<Device> adminDevice() async {
          final admin = await device();
          await admin.signIn(
            Account(
              name: 'Administração',
              email: adminEmail!,
              password: adminPassword!,
            ),
          );
          expect(admin.state.session.user!.isAdmin, isTrue);
          return admin;
        }

        /// O anúncio com este título na fila de análise, ou `null`.
        Future<ListingReview?> queued(Device admin, String title) async {
          final queue = await admin.deps.reviews.pending();
          return queue.listings.where((l) => l.title == title).firstOrNull;
        }

        test(
          'aprovado pela administração, o anúncio chega até a festa',
          skip: adminSkip,
          () async {
            final (vendorPhone, _) = await signedUpDevice();
            final cpf = randomCpf(random);
            final draft = hall(document: cpf);
            expect(await vendorPhone.state.vendor.submitHall(draft), isTrue);

            // A administração encontra o anúncio na fila, com o cadastro de
            // quem anuncia, e vê o documento completo para conferir.
            final admin = await adminDevice();
            final queue = await admin.deps.reviews.pending();
            final pendingListing = queue.listings.singleWhere(
              (l) => l.title == draft.title,
            );
            expect(pendingListing.vendorName, 'Maria Oliveira');
            expect(pendingListing.location, 'Pituba, Salvador, BA');
            expect(pendingListing.priceFromCents, 250000);
            expect(pendingListing.eventTypes, ['wedding', 'debutante']);
            expect(
              pendingListing.cancellationPolicy,
              CancellationPolicy.moderate,
            );
            expect(pendingListing.canBePublished, isFalse);
            final pendingVendor = queue.vendors.singleWhere(
              (v) => v.id == pendingListing.vendorId,
            );
            expect(pendingVendor.document, cpf);
            expect(pendingVendor.personType, PersonType.individual);
            expect(queue.listingsOf(pendingVendor.id), hasLength(1));

            // Antes do cadastro, o anúncio não pode ser publicado.
            await expectLater(
              admin.deps.reviews.approveListing(pendingListing.id),
              throwsA(
                isA<ConflictFailure>().having(
                  (f) => f.code,
                  'code',
                  'vendor_not_approved',
                ),
              ),
            );

            await admin.deps.reviews.approveVendor(
              pendingVendor.id,
              publishListings: true,
            );
            expect(await queued(admin, draft.title), isNull);
            // A mesma decisão duas vezes é recusada.
            await expectLater(
              admin.deps.reviews.approveVendor(
                pendingVendor.id,
                publishListings: true,
              ),
              throwsA(
                isA<ConflictFailure>().having(
                  (f) => f.code,
                  'code',
                  'already_reviewed',
                ),
              ),
            );

            await vendorPhone.state.vendor.load();
            expect(vendorPhone.state.vendor.isApproved, isTrue);
            expect(
              vendorPhone.state.vendor.listings.single.status,
              VendorListingStatus.published,
            );

            // Uma cliente encontra o salão novo e o coloca na festa dela.
            final (client, _) = await signedUpDevice();
            final found = await client.deps.catalog.search(
              ListingQuery(text: draft.title, eventTypeSlug: 'wedding'),
            );
            final listing = found.items.single;
            expect(listing.locationLabel, 'Pituba, BA');
            expect(listing.priceFromCents, 250000);
            expect(listing.hasRatings, isFalse);

            final party = await client.state.parties.addItemToNewParty(
              event('Casamento'),
              venueSelection(await client.draftOf(listing)),
            );
            expect(party, isNotNull, reason: client.state.parties.error);
            expect(party!.estimate.total.cents, 250000);
            expect(party.budget.venue!.capacity, 150);
          },
        );

        test(
          'o pedido de orçamento chega ao fornecedor, que responde; o '
          'cliente vê o valor e aceita',
          skip: adminSkip,
          () async {
            final admin = await adminDevice();
            final (vendorPhone, listing) = await publishedHall(admin);
            final (client, _) = await signedUpDevice();
            final parties = client.state.parties;

            // A cliente monta a festa com o salão, o buffet da casa e a taxa
            // obrigatória, e pede o orçamento.
            final details = event('Casamento da Bia', guests: 100);
            final created = await parties.addItemToNewParty(
              details,
              venueSelection(
                await client.draftOf(listing),
                services: ['Buffet da casa'],
              ),
            );
            expect(created, isNotNull, reason: parties.error);
            final partyId = created!.id;
            // 2.500 + 150 + 50 x 100 convidados
            expect(created.estimate.total.cents, 250000 + 15000 + 500000);
            expect(await parties.requestQuote(partyId), isTrue);

            // O fornecedor vê um pedido por item, com o evento e a
            // configuração, e nada sobre quem pediu.
            final inbox = vendorPhone.deps.quoteInbox;
            final requests = await inbox.list();
            expect(requests.map((request) => request.name), [
              listing.title,
              'Taxa de limpeza',
              'Buffet da casa',
            ]);
            final hallRequest = requests.first;
            expect(hallRequest.partyStatus, PartyStatus.locked);
            expect(hallRequest.round, 1);
            expect(hallRequest.guestCount, 100);
            expect(
              hallRequest.eventDate!.isAtSameMomentAs(details.eventDate!.value),
              isTrue,
            );
            expect(hallRequest.configuration.durationHours, 4);
            expect(hallRequest.estimate!.cents, 250000);
            expect(hallRequest.quote.status, QuoteStatus.pending);
            expect(requests[1].relation, ItemRelationKind.required);
            expect(requests[1].parentName, listing.title);
            expect(requests[2].estimate!.cents, 500000);
            final raw =
                await vendorPhone.api.get(
                      '/vendors/me/quote-requests',
                      authenticated: true,
                    )
                    as Json;
            final rawRequest = (raw['items'] as List).first as Json;
            expect(rawRequest.containsKey('title'), isFalse);
            expect(rawRequest.containsKey('owner_id'), isFalse);

            // Uma resposta sem o motivo, ou com um valor fora do limite, é
            // recusada.
            await expectLater(
              inbox.respond(
                hallRequest.itemId,
                const VendorResponse.decline('não'),
              ),
              throwsA(isA<ValidationFailure>()),
            );

            final answered = await inbox.respond(
              hallRequest.itemId,
              VendorResponse.quote(
                Money.fromCents(260000),
                message: '  Inclui a montagem.  ',
              ),
            );
            expect(answered.quote.amount!.cents, 260000);
            expect(answered.quote.message, 'Inclui a montagem.');
            // Ainda faltam dois itens.
            expect(answered.partyStatus, PartyStatus.locked);

            // A cliente tinha a festa de antes da resposta: uma gravação
            // sobre ela é recusada, e a tela passa a mostrar o que chegou.
            expect(await parties.cancelParty(partyId), isFalse);
            final updated = parties.activeParty!;
            expect(updated.status, PartyStatus.locked);
            expect(updated.quotedTotal!.cents, 260000);
            expect(updated.budget.venue!.quote.message, 'Inclui a montagem.');
            // A estimativa continua sendo a conta do app, ao lado.
            expect(updated.estimate.total.cents, 250000 + 15000 + 500000);
            expect(updated.history.last.kind, PartyHistoryKind.vendorQuoted);
            expect(updated.history.last.itemName, listing.title);

            await inbox.respond(
              requests[1].itemId,
              VendorResponse.quote(Money.fromCents(15000)),
            );
            final last = await inbox.respond(
              requests[2].itemId,
              VendorResponse.quote(Money.fromCents(480000)),
            );
            expect(last.partyStatus, PartyStatus.quoted);

            // O fornecedor corrige um valor enquanto a cliente não aceita.
            await inbox.respond(
              requests[2].itemId,
              VendorResponse.quote(Money.fromCents(470000)),
            );

            await parties.load();
            final quoted = parties.activeParty!;
            expect(quoted.status, PartyStatus.quoted);
            expect(quoted.quotedTotal!.cents, 260000 + 15000 + 470000);

            expect(await parties.confirmQuote(partyId), isTrue);
            expect(parties.activeParty!.status, PartyStatus.confirmed);
            expect(
              parties.activeParty!.history.last.kind,
              PartyHistoryKind.confirmed,
            );

            // Aceito, o pedido se fecha para o fornecedor.
            final closed = await inbox.list();
            expect(
              closed.map((request) => request.partyStatus),
              everyElement(PartyStatus.confirmed),
            );
            expect(closed.first.canRespond, isFalse);
            await expectLater(
              inbox.respond(
                hallRequest.itemId,
                VendorResponse.quote(Money.fromCents(1)),
              ),
              throwsA(
                isA<ConflictFailure>().having(
                  (f) => f.code,
                  'code',
                  'quote_request_closed',
                ),
              ),
            );
          },
        );

        test(
          'edição solicitada: o fornecedor pede uma alteração, a cliente '
          'ajusta e reenvia',
          skip: adminSkip,
          () async {
            final admin = await adminDevice();
            final (vendorPhone, listing) = await publishedHall(admin);
            final (otherVendorPhone, _) = await publishedHall(admin);
            final (client, _) = await signedUpDevice();
            final parties = client.state.parties;
            final inbox = vendorPhone.deps.quoteInbox;

            final created = await parties.addItemToNewParty(
              event('Formatura', guests: 120),
              venueSelection(await client.draftOf(listing)),
            );
            final partyId = created!.id;
            expect(await parties.requestQuote(partyId), isTrue);

            // Outro fornecedor não vê o pedido nem consegue respondê-lo.
            final requests = await inbox.list();
            expect(await otherVendorPhone.deps.quoteInbox.list(), isEmpty);
            await expectLater(
              otherVendorPhone.deps.quoteInbox.respond(
                requests.first.itemId,
                VendorResponse.quote(Money.fromCents(1)),
              ),
              throwsA(isA<NotFoundFailure>()),
            );

            await inbox.respond(
              requests.last.itemId,
              VendorResponse.quote(Money.fromCents(15000)),
            );
            final changes = await inbox.respond(
              requests.first.itemId,
              const VendorResponse.requestChanges(
                'Neste dia só atendo até 6 horas de festa.',
              ),
            );
            expect(changes.partyStatus, PartyStatus.editRequested);

            await parties.load();
            final returned = parties.activeParty!;
            expect(returned.status, PartyStatus.editRequested);
            expect(
              returned.itemsNeedingAttention.single.nameSnapshot,
              listing.title,
            );
            expect(
              returned.budget.venue!.quote.message,
              'Neste dia só atendo até 6 horas de festa.',
            );

            // A cliente volta a editar: a festa some da caixa do fornecedor.
            expect(await parties.reopen(partyId), isTrue);
            expect(await inbox.list(), isEmpty);

            // Ajusta o salão e reenvia. Quem já tinha dado o valor, e nada
            // mudou para ele, não responde de novo.
            expect(
              await parties.updateItem(
                partyId,
                returned.budget.venue!.id,
                quantity: 1,
                configuration: const {'duration_hours': 6},
              ),
              isTrue,
              reason: parties.error,
            );
            expect(await parties.requestQuote(partyId), isTrue);
            final again = parties.activeParty!;
            expect(again.quoteRound, 2);
            expect(again.status, PartyStatus.locked);
            expect(again.budget.venue!.quote.status, QuoteStatus.pending);
            expect(again.budget.items.last.quote.isQuoted, isTrue);

            final second = await inbox.list();
            expect(second.first.round, 2);
            expect(second.first.configuration.durationHours, 6);
            final done = await inbox.respond(
              second.first.itemId,
              VendorResponse.quote(Money.fromCents(300000)),
            );
            expect(done.partyStatus, PartyStatus.quoted);

            // A cliente cancela: o fornecedor vê o pedido fechado.
            await parties.load();
            expect(await parties.cancelParty(partyId), isTrue);
            final cancelled = await inbox.list();
            expect(cancelled.first.partyStatus, PartyStatus.cancelled);
            expect(cancelled.first.canRespond, isFalse);
          },
        );

        test(
          'recusado pela administração: o fornecedor vê o motivo, corrige e '
          'só o anúncio novo é publicado',
          skip: adminSkip,
          () async {
            final (vendorPhone, _) = await signedUpDevice();
            final vendor = vendorPhone.state.vendor;
            final cpf = randomCpf(random);
            final first = hall(document: cpf);
            expect(await vendor.submitHall(first), isTrue);

            final admin = await adminDevice();
            final rejectedListing = (await queued(admin, first.title))!;

            // Recusa sem motivo não passa.
            await expectLater(
              admin.deps.reviews.rejectVendor(
                rejectedListing.vendorId,
                reason: '  ',
              ),
              throwsA(
                isA<ValidationFailure>().having(
                  (f) => f.message,
                  'message',
                  'Explique o motivo da recusa.',
                ),
              ),
            );
            await admin.deps.reviews.rejectVendor(
              rejectedListing.vendorId,
              reason: 'Documento ilegível.',
            );

            // O anúncio que veio com o cadastro sai da fila junto.
            expect(await queued(admin, first.title), isNull);
            await vendor.load();
            expect(vendor.status, VendorStatus.rejected);
            expect(vendor.profile!.rejectionReason, 'Documento ilegível.');
            expect(vendor.listings.single.status, VendorListingStatus.rejected);
            expect(
              vendor.listings.single.rejectionReason,
              'Documento ilegível.',
            );

            // Corrige e reenvia: volta para a fila com um anúncio novo.
            final second = hall(document: cpf);
            expect(await vendor.submitHall(second), isTrue);
            expect(vendor.status, VendorStatus.pendingReview);
            final resubmitted = (await queued(admin, second.title))!;
            await admin.deps.reviews.approveVendor(
              resubmitted.vendorId,
              publishListings: true,
            );

            final catalog = vendorPhone.deps.catalog;
            expect(
              (await catalog.search(ListingQuery(text: second.title))).items,
              hasLength(1),
            );
            // O anúncio recusado com o primeiro envio não é publicado.
            expect(
              (await catalog.search(ListingQuery(text: first.title))).items,
              isEmpty,
            );
          },
        );

        test(
          'anúncios novos de um fornecedor aprovado são publicados ou '
          'recusados um a um',
          skip: adminSkip,
          () async {
            final (vendorPhone, _) = await signedUpDevice();
            final vendor = vendorPhone.state.vendor;
            final cpf = randomCpf(random);
            final first = hall(document: cpf);
            expect(await vendor.submitHall(first), isTrue);

            // Aprova o cadastro sem publicar: o anúncio fica na fila, liberado.
            final admin = await adminDevice();
            final waiting = (await queued(admin, first.title))!;
            await admin.deps.reviews.approveVendor(
              waiting.vendorId,
              publishListings: false,
            );
            final released = (await queued(admin, first.title))!;
            expect(released.canBePublished, isTrue);

            final second = hall(document: cpf);
            expect(await vendor.submitHall(second), isTrue);
            final another = (await queued(admin, second.title))!;

            await admin.deps.reviews.approveListing(released.id);
            await admin.deps.reviews.rejectListing(
              another.id,
              reason: 'Fotos insuficientes.',
            );

            expect(await queued(admin, first.title), isNull);
            expect(await queued(admin, second.title), isNull);
            await vendor.load();
            expect(vendor.isApproved, isTrue);
            expect(
              {for (final l in vendor.listings) l.title: l.status},
              {
                first.title: VendorListingStatus.published,
                second.title: VendorListingStatus.rejected,
              },
            );
            expect(
              vendor.listings
                  .singleWhere((l) => l.title == second.title)
                  .rejectionReason,
              'Fotos insuficientes.',
            );
            final catalog = vendorPhone.deps.catalog;
            expect(
              (await catalog.search(ListingQuery(text: first.title))).items,
              hasLength(1),
            );
            expect(
              (await catalog.search(ListingQuery(text: second.title))).items,
              isEmpty,
            );
          },
        );
      });
    },
  );
}

/// Os dados de um evento daqui a dois meses, para [guests] convidados.
EventDetails event(String title, {int guests = 80}) {
  return EventDetails(
    title: PartyTitle(title),
    eventDate: EventDate(DateTime.now().add(const Duration(days: 60))),
    guestCount: GuestCount(guests),
  );
}

/// O salão [draft] configurado para 4 horas, com os serviços obrigatórios dele
/// e os opcionais de nome em [services].
ConfiguredItem venueSelection(
  PartyItemDraft draft, {
  List<String> services = const [],
}) {
  return ConfiguredItem(
    draft: draft,
    configuration: const {'duration_hours': 4},
    ownServices: [
      for (final service in draft.ownServices)
        if (service.isRequired || services.contains(service.name))
          ConfiguredItem(draft: service),
    ],
  );
}

/// Faixa dos sufixos aleatórios que tornam únicos os e-mails e os títulos.
///
/// Escrito por extenso de propósito: `1 << 32` vale 0 quando o teste roda no
/// navegador (lá os deslocamentos de bits são de 32 bits), e `nextInt(0)`
/// lança um erro.
const int _randomRange = 0xFFFFFFFF;

/// Dados de uma conta de teste.
class Account {
  const Account({
    required this.name,
    required this.email,
    required this.password,
  });

  /// Uma conta que ainda não existe no servidor.
  factory Account.unique(Random random) {
    final suffix =
        '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(_randomRange)}';
    return Account(
      name: 'Teste de Integração',
      email: 'it-$suffix@example.com',
      password: 'senha-de-teste-123',
    );
  }

  final String name;
  final String email;
  final String password;
}

/// Um aparelho com o app instalado, falando com a API.
class Device {
  Device(Uri apiUrl) : this._(apiUrl, InMemoryTokenStorage());

  Device._(Uri apiUrl, this.tokens)
    : deps = AppDependencies.api(
        AppConfig(apiBaseUrl: apiUrl),
        tokenStorage: tokens,
      ) {
    state = AppState(deps);
  }

  /// O que fica guardado no aparelho entre uma abertura e outra do app.
  final InMemoryTokenStorage tokens;
  final AppDependencies deps;
  late AppState state;

  ApiClient get api => deps.apiClient!;

  /// Abre o app: restaura a sessão e carrega os dados da conta.
  Future<void> start() async {
    await state.start();
    await synced();
  }

  /// Fecha e abre o app de novo, mantendo o que está guardado no aparelho.
  Future<void> restart() async {
    state.dispose();
    state = AppState(deps);
    await start();
  }

  Future<void> signUp(Account account) async {
    final created = await state.session.signUp(
      fullName: account.name,
      email: account.email,
      password: account.password,
    );
    expect(created, isTrue, reason: state.session.error);
    await synced();
  }

  Future<void> signIn(Account account) async {
    final signedIn = await state.session.signIn(
      email: account.email,
      password: account.password,
    );
    expect(signedIn, isTrue, reason: state.session.error);
    await synced();
  }

  /// Espera favoritos, festas e cadastro de fornecedor da conta atual
  /// terminarem de carregar (o AppState os dispara quando a sessão muda).
  Future<void> synced() async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!(state.favorites.hasLoaded &&
        state.parties.hasLoaded &&
        state.vendor.hasLoaded)) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Os dados da conta não carregaram em 15 segundos.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  /// Troca o token de acesso por um inválido, como se tivesse vencido.
  Future<void> expireAccessToken() async {
    final current = (await tokens.read())!;
    await tokens.write(
      AuthTokens(accessToken: 'vencido', refreshToken: current.refreshToken),
    );
  }

  /// O anúncio mais procurado de uma categoria.
  Future<Listing> firstListing(String categorySlug) async {
    final page = await deps.catalog.search(
      ListingQuery(categorySlug: categorySlug),
      limit: 1,
    );
    return page.items.single;
  }

  /// O que o catálogo diz de [listing], com os serviços próprios dele, pronto
  /// para ser configurado: o mesmo caminho da tela.
  Future<PartyItemDraft> draftOf(Listing listing) {
    return ListingPartyItemCatalog(deps.catalog).draftFor(listing.id);
  }

  void dispose() {
    state.dispose();
    api.close();
  }
}

/// Um CPF aleatório com dígitos verificadores válidos.
String randomCpf(Random random) {
  int checkDigit(List<int> digits) {
    var sum = 0;
    for (var i = 0; i < digits.length; i++) {
      sum += digits[i] * (digits.length + 1 - i);
    }
    final rest = (sum * 10) % 11;
    return rest == 10 ? 0 : rest;
  }

  while (true) {
    final digits = List.generate(9, (_) => random.nextInt(10));
    digits.add(checkDigit(digits));
    digits.add(checkDigit(digits));
    final cpf = digits.join();
    // Sequências de um dígito só passam na conta, mas não são CPFs.
    if (isValidCpf(cpf)) return cpf;
  }
}
