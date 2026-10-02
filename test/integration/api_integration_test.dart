@Tags(['integration'])
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/app/app_dependencies.dart';
import 'package:yvenist/app/app_state.dart';
import 'package:yvenist/core/config/app_config.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/network/api_client.dart';
import 'package:yvenist/core/storage/token_storage.dart';
import 'package:yvenist/core/utils/brazilian_documents.dart';
import 'package:yvenist/core/utils/id_generator.dart';
import 'package:yvenist/features/auth/presentation/controllers/session_controller.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/client/shared/listing_actions.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_draft.dart';
import 'package:yvenist/features/vendor/domain/vendor_models.dart';

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
/// O teste de aprovação pela administração só roda se `YVENIST_ADMIN_EMAIL` e
/// `YVENIST_ADMIN_PASSWORD` apontarem para uma conta criada com
/// `python -m app.cli create-admin`.
void main() {
  final apiUrl = AppConfig.parseBaseUrl(
    Platform.environment['YVENIST_API_URL'] ?? '',
  );
  final adminEmail = Platform.environment['YVENIST_ADMIN_EMAIL'];
  final adminPassword = Platform.environment['YVENIST_ADMIN_PASSWORD'];

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
        test('nome e preço do item vêm do catálogo, não do app', () async {
          final (phone, _) = await signedUpDevice();
          final salao = await phone.firstListing('venue');
          // Um app adulterado tentando gravar outro nome e outro preço.
          final tampered = PartyItemDraft(
            externalRef: ExternalRef.listing(salao.id),
            category: PartyItemCategory.other,
            name: 'Nome inventado',
            unitPrice: Money.fromCents(1),
          );

          final added = await phone.state.parties.addItemToNewParty(
            'Casamento',
            tampered,
          );

          expect(added, isTrue, reason: phone.state.parties.error);
          final party = phone.state.parties.activeParty!;
          final item = party.budget.items.single;
          expect(party.status, PartyStatus.planning);
          expect(party.ownerId, phone.state.session.user!.id);
          expect(item.nameSnapshot, salao.title);
          expect(item.unitPriceSnapshot.cents, salao.priceFromCents);
          expect(item.category, PartyItemCategory.venue);
          expect(item.imageUrlSnapshot, salao.coverImageUrl);
          expect(
            phone.state.parties.activePartyTotalCents,
            salao.priceFromCents,
          );
        });

        test('montar, pedir orçamento, liberar e desmontar a festa', () async {
          final (phone, account) = await signedUpDevice();
          final parties = phone.state.parties;
          final salao = await phone.firstListing('venue');
          final atracao = await phone.firstListing('attraction');
          final total = salao.priceFromCents + atracao.priceFromCents;

          await parties.addItemToNewParty('15 anos', salao.toPartyItemDraft());
          final partyId = parties.activePartyId!;
          expect(
            await parties.addItemToParty(partyId, atracao.toPartyItemDraft()),
            isTrue,
            reason: parties.error,
          );
          expect(parties.isInAnyParty(atracao.id), isTrue);

          expect(await parties.lockActivePartyForPayment(), isTrue);
          expect(parties.isActivePartyLocked, isTrue);
          expect(
            parties.activeParty!.paymentSnapshot!.totalAmount.cents,
            total,
          );

          // Outro aparelho da mesma conta vê a festa como ficou no servidor.
          final tablet = await device();
          await tablet.signIn(account);
          final seen = tablet.state.parties.parties.single;
          expect(seen.title.value, '15 anos');
          expect(seen.status, PartyStatus.locked);
          expect(seen.budget.total.cents, total);
          expect(seen.paymentSnapshot!.breakdown, hasLength(2));

          expect(await parties.unlockActiveParty(), isTrue);
          expect(parties.activeParty!.paymentSnapshot, isNull);

          for (final item in parties.budgetItemViews) {
            expect(await parties.removeItemFromActiveParty(item.id), isTrue);
          }
          // Sem itens, a festa deixa de existir.
          expect(parties.parties, isEmpty);
          await tablet.state.parties.load();
          expect(tablet.state.parties.parties, isEmpty);
        });

        test('o servidor recusa o segundo salão e o preço adulterado', () async {
          final (phone, _) = await signedUpDevice();
          final venues = await phone.deps.catalog.search(
            const ListingQuery(categorySlug: 'venue'),
            limit: 2,
          );
          final ids = UuidGenerator();
          final partyId = ids.newId();

          // Direto na API, pulando as regras que o app aplica antes de enviar.
          await expectLater(
            phone.api.put(
              '/parties/$partyId',
              authenticated: true,
              body: {
                'title': 'Dois salões',
                'status': 'planning',
                'items': [
                  for (final venue in venues.items)
                    {'id': ids.newId(), 'listing_id': venue.id, 'quantity': 1},
                ],
              },
            ),
            throwsA(
              isA<ConflictFailure>().having(
                (f) => f.code,
                'code',
                'venue_already_selected',
              ),
            ),
          );

          // Marcar como paga também não é algo que o cliente possa pedir.
          await expectLater(
            phone.api.put(
              '/parties/$partyId',
              authenticated: true,
              body: {
                'title': 'Festa "paga"',
                'status': 'paid',
                'items': [
                  {
                    'id': ids.newId(),
                    'listing_id': venues.items.first.id,
                    'quantity': 1,
                  },
                ],
              },
            ),
            throwsA(isA<AppFailure>()),
          );
          await phone.state.parties.load();
          expect(phone.state.parties.parties, isEmpty);
        });

        test('edição em dois aparelhos: o atrasado recebe o conflito', () async {
          final (phone, account) = await signedUpDevice();
          final salao = await phone.firstListing('venue');
          final atracao = await phone.firstListing('attraction');
          final decoracao = await phone.firstListing('decoration');
          await phone.state.parties.addItemToNewParty(
            'Formatura',
            salao.toPartyItemDraft(),
          );
          final partyId = phone.state.parties.activePartyId!;

          final tablet = await device();
          await tablet.signIn(account);
          expect(
            tablet.state.parties.parties.single.budget.items,
            hasLength(1),
          );

          // O celular altera primeiro; o tablet ainda tem a versão anterior.
          expect(
            await phone.state.parties.addItemToParty(
              partyId,
              atracao.toPartyItemDraft(),
            ),
            isTrue,
          );
          final stale = await tablet.state.parties.addItemToParty(
            partyId,
            decoracao.toPartyItemDraft(),
          );

          expect(stale, isFalse);
          expect(
            tablet.state.parties.error,
            'A festa foi alterada em outro dispositivo. '
            'Atualize e tente novamente.',
          );
          // O tablet já recarregou: vê o que o celular gravou, sem ter perdido
          // nem sobrescrito nada.
          final refreshed = tablet.state.parties.parties.single;
          expect(refreshed.budget.items, hasLength(2));

          // Tentar de novo, agora sobre a versão atual, funciona.
          expect(
            await tablet.state.parties.addItemToParty(
              partyId,
              decoracao.toPartyItemDraft(),
            ),
            isTrue,
            reason: tablet.state.parties.error,
          );
          await phone.state.parties.load();
          expect(phone.state.parties.parties.single.budget.items, hasLength(3));
        });

        test('uma conta não lê nem altera a festa de outra', () async {
          final (ana, _) = await signedUpDevice();
          final (bruno, _) = await signedUpDevice();
          final salao = await ana.firstListing('venue');
          await ana.state.parties.addItemToNewParty(
            'Festa da Ana',
            salao.toPartyItemDraft(),
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
          expect(party.budget.items, hasLength(1));
          await bruno.state.parties.load();
          expect(bruno.state.parties.parties, isEmpty);
        });
      });

      group('fornecedor', () {
        HallListingDraft hall({required String document, String? title}) {
          return HallListingDraft(
            personType: PersonType.individual,
            document: document,
            legalName: 'Maria Oliveira',
            title: title ?? 'Espaço Crystal ${random.nextInt(1 << 32)}',
            description: 'Salão amplo, climatizado, com cozinha equipada.',
            neighborhood: 'Pituba',
            city: 'Salvador',
            state: 'BA',
            priceFromCents: 250000,
            areaM2: 300,
            capacity: 150,
            eventTypes: const {'wedding', 'debutante'},
            amenities: const {'wifi', 'kitchen'},
            cancellationPolicy: CancellationPolicy.moderate,
          );
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
            phone.api.get('/admin/vendors', authenticated: true),
            throwsA(isA<ForbiddenFailure>()),
          );
        });

        test(
          'aprovado pela administração, o anúncio chega até a festa',
          skip: adminEmail == null || adminPassword == null
              ? 'Defina YVENIST_ADMIN_EMAIL e YVENIST_ADMIN_PASSWORD.'
              : null,
          () async {
            final (vendorPhone, _) = await signedUpDevice();
            final draft = hall(document: randomCpf(random));
            expect(await vendorPhone.state.vendor.submitHall(draft), isTrue);

            // A administração encontra o cadastro na fila e aprova.
            final admin = await device();
            await admin.signIn(
              Account(
                name: 'Administração',
                email: adminEmail!,
                password: adminPassword!,
              ),
            );
            expect(admin.state.session.user!.isAdmin, isTrue);
            final queue =
                await admin.api.get('/admin/vendors', authenticated: true)
                    as Json;
            final pending = (queue['items'] as List).cast<Json>().firstWhere(
              (item) => item['user_id'] == vendorPhone.state.session.user!.id,
            );
            await admin.api.post(
              '/admin/vendors/${pending['id']}/approve',
              authenticated: true,
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

            expect(
              await client.state.parties.addItemToNewParty(
                'Casamento',
                listing.toPartyItemDraft(),
              ),
              isTrue,
              reason: client.state.parties.error,
            );
            expect(client.state.parties.activePartyTotalCents, 250000);
          },
        );
      });
    },
  );
}

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
        '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 32)}';
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
