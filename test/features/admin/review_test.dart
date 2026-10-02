import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/state/load_state.dart';
import 'package:yvenist/features/admin/data/api_review_repository.dart';
import 'package:yvenist/features/admin/data/in_memory_review_repository.dart';
import 'package:yvenist/features/admin/domain/review_models.dart';
import 'package:yvenist/features/admin/presentation/controllers/review_queue_controller.dart';
import 'package:yvenist/features/vendor/domain/vendor_models.dart';

import '../../support/catalog_fixtures.dart';
import '../../support/fake_api.dart';
import '../../support/review_fixtures.dart';

void main() {
  group('ReviewQueue', () {
    test('sabe quais anúncios esperam com cada cadastro', () {
      final queue = ReviewQueue(
        vendors: [buildVendorReview()],
        listings: [
          buildListingReview(),
          buildListingReview(id: 'listing-2', vendorId: 'vendor-2'),
        ],
      );

      expect(queue.listingsOf('vendor-1').map((l) => l.id), ['listing-1']);
      expect(queue.listingsOf('vendor-9'), isEmpty);
    });

    test('anúncio só pode ser publicado se o fornecedor foi aprovado', () {
      expect(buildListingReview().canBePublished, isFalse);
      expect(
        buildListingReview(vendorStatus: VendorStatus.rejected).canBePublished,
        isFalse,
      );
      expect(
        buildListingReview(vendorStatus: VendorStatus.approved).canBePublished,
        isTrue,
      );
    });

    test('o local junta bairro, cidade e UF', () {
      expect(buildListingReview().location, 'Campo Grande, Rio de Janeiro, RJ');
    });
  });

  group('InMemoryReviewRepository', () {
    late InMemoryReviewRepository repository;

    setUp(() {
      repository = InMemoryReviewRepository(
        vendors: [buildVendorReview()],
        listings: [
          buildListingReview(),
          buildListingReview(
            id: 'listing-2',
            title: 'Buffet da Ana',
            vendorId: 'vendor-2',
            vendorName: 'Ana Souza',
            vendorStatus: VendorStatus.approved,
          ),
        ],
      );
    });

    Future<List<String>> pendingListings() async {
      return [for (final l in (await repository.pending()).listings) l.id];
    }

    test('aprovar o cadastro publica junto os anúncios dele', () async {
      await repository.approveVendor('vendor-1', publishListings: true);

      expect((await repository.pending()).vendors, isEmpty);
      expect(await pendingListings(), ['listing-2']);
    });

    test('aprovar sem publicar deixa os anúncios na fila, liberados', () async {
      await repository.approveVendor('vendor-1', publishListings: false);

      final queue = await repository.pending();
      expect(queue.vendors, isEmpty);
      expect(queue.listings.first.id, 'listing-1');
      expect(queue.listings.first.canBePublished, isTrue);
    });

    test('recusar o cadastro recusa os anúncios que vieram com ele', () async {
      await repository.rejectVendor('vendor-1', reason: 'Documento ilegível.');

      expect((await repository.pending()).vendors, isEmpty);
      expect(await pendingListings(), ['listing-2']);
    });

    test('anúncio de fornecedor não aprovado não pode ser publicado', () async {
      await expectLater(
        repository.approveListing('listing-1'),
        throwsA(
          isA<ConflictFailure>().having(
            (f) => f.code,
            'code',
            'vendor_not_approved',
          ),
        ),
      );
      expect(await pendingListings(), contains('listing-1'));
    });

    test('publicar e recusar anúncios tira cada um da fila', () async {
      await repository.approveListing('listing-2');
      await repository.rejectListing('listing-1', reason: 'Fotos ruins.');

      expect(await pendingListings(), isEmpty);
    });

    test('a recusa exige um motivo', () async {
      await expectLater(
        repository.rejectVendor('vendor-1', reason: '  ok '),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        repository.rejectListing('listing-1', reason: ''),
        throwsA(isA<ValidationFailure>()),
      );
      expect((await repository.pending()).vendors, hasLength(1));
    });

    test('o que já saiu da fila não pode ser decidido de novo', () async {
      await repository.approveVendor('vendor-1', publishListings: true);

      for (final again in [
        () => repository.approveVendor('vendor-1', publishListings: true),
        () => repository.rejectVendor('vendor-1', reason: 'Mudei de ideia.'),
        () => repository.approveListing('listing-1'),
        () => repository.rejectListing('listing-1', reason: 'Mudei de ideia.'),
      ]) {
        await expectLater(
          again(),
          throwsA(
            isA<ConflictFailure>().having(
              (f) => f.code,
              'code',
              'already_reviewed',
            ),
          ),
        );
      }
    });
  });

  group('ApiReviewRepository', () {
    late FakeApi api;
    late ApiReviewRepository repository;

    const vendorJson = {
      'id': 'v1',
      'user_id': 'u1',
      'person_type': 'pj',
      'document': '11222333000181',
      'document_masked': '11.***.***/****-81',
      'legal_name': 'Festas & Cia Ltda',
      'status': 'pending_review',
      'rejection_reason': null,
      'created_at': '2026-10-01T12:30:00Z',
    };

    const listingJson = {
      'id': 'l1',
      'title': 'Espaço Crystal',
      'category': 'venue',
      'neighborhood': null,
      'city': 'Rio de Janeiro',
      'state': 'RJ',
      'price_from_cents': 250000,
      'currency': 'BRL',
      'cover_image_url': null,
      'rating_average': 0.0,
      'rating_count': 0,
      'description': 'Salão amplo, climatizado, com cozinha equipada.',
      'capacity': 150,
      'area_m2': null,
      'amenities': ['kitchen', 'wifi'],
      'cancellation_policy': 'moderate',
      'event_types': ['wedding'],
      'status': 'pending_review',
      'rejection_reason': null,
      'created_at': '2026-10-01T12:31:00Z',
      'vendor_id': 'v1',
      'vendor_legal_name': 'Festas & Cia Ltda',
      'vendor_status': 'approved',
    };

    setUp(() {
      api = FakeApi();
      repository = ApiReviewRepository(api.client);
    });

    test('busca as duas filas, só o que está em análise', () async {
      api
        ..reply('GET', '/admin/vendors', {
          'items': [vendorJson],
        })
        ..reply('GET', '/admin/listings', {
          'items': [listingJson],
        });

      final queue = await repository.pending();

      expect(
        api.calls,
        unorderedEquals(['GET /admin/vendors', 'GET /admin/listings']),
      );
      for (final request in api.requests) {
        expect(request.url.queryParameters, {'status': 'pending_review'});
        expect(request.headers['Authorization'], 'Bearer acesso');
      }

      final vendor = queue.vendors.single;
      expect(vendor.id, 'v1');
      expect(vendor.legalName, 'Festas & Cia Ltda');
      expect(vendor.personType, PersonType.company);
      expect(vendor.document, '11222333000181');
      expect(vendor.createdAt, DateTime.utc(2026, 10, 1, 12, 30));

      final listing = queue.listings.single;
      expect(listing.id, 'l1');
      expect(listing.title, 'Espaço Crystal');
      expect(listing.categorySlug, 'venue');
      expect(listing.neighborhood, isNull);
      expect(listing.location, 'Rio de Janeiro, RJ');
      expect(listing.priceFromCents, 250000);
      expect(listing.capacity, 150);
      expect(listing.areaM2, isNull);
      expect(listing.amenities, ['kitchen', 'wifi']);
      expect(listing.eventTypes, ['wedding']);
      expect(listing.cancellationPolicy, CancellationPolicy.moderate);
      expect(listing.vendorId, 'v1');
      expect(listing.vendorName, 'Festas & Cia Ltda');
      expect(listing.canBePublished, isTrue);
    });

    test(
      'situação de fornecedor desconhecida não libera a publicação',
      () async {
        api
          ..reply('GET', '/admin/vendors', {'items': <Object>[]})
          ..reply('GET', '/admin/listings', {
            'items': [
              {...listingJson, 'vendor_status': 'suspended'},
            ],
          });

        final queue = await repository.pending();

        expect(queue.listings.single.canBePublished, isFalse);
      },
    );

    test('aprovar o cadastro diz se publica os anúncios junto', () async {
      api.reply('POST', '/admin/vendors/v1/approve', vendorJson);

      await repository.approveVendor('v1', publishListings: false);

      expect(api.calls, ['POST /admin/vendors/v1/approve']);
      expect(api.lastBody, {'publish_pending_listings': false});
    });

    test('recusas mandam o motivo', () async {
      api
        ..reply('POST', '/admin/vendors/v1/reject', vendorJson)
        ..reply('POST', '/admin/listings/l1/reject', listingJson);

      await repository.rejectVendor('v1', reason: 'Documento ilegível.');
      expect(api.lastBody, {'reason': 'Documento ilegível.'});

      await repository.rejectListing('l1', reason: 'Fotos insuficientes.');
      expect(api.lastBody, {'reason': 'Fotos insuficientes.'});
      expect(api.calls.last, 'POST /admin/listings/l1/reject');
    });

    test('publicar um anúncio não manda corpo', () async {
      api.reply('POST', '/admin/listings/l1/approve', listingJson);

      await repository.approveListing('l1');

      expect(api.calls, ['POST /admin/listings/l1/approve']);
      expect(api.lastRequest.body, isEmpty);
    });

    test('as recusas do servidor chegam como falhas com o código', () async {
      api
        ..fail(
          'POST',
          '/admin/vendors/v1/approve',
          409,
          'already_reviewed',
          'Este item já foi analisado.',
        )
        ..fail('GET', '/admin/vendors', 403, 'forbidden', 'Sem permissão.')
        ..reply('GET', '/admin/listings', {'items': <Object>[]});

      await expectLater(
        repository.approveVendor('v1', publishListings: true),
        throwsA(
          isA<ConflictFailure>()
              .having((f) => f.code, 'code', 'already_reviewed')
              .having(
                (f) => f.message,
                'message',
                'Este item já foi analisado.',
              ),
        ),
      );
      // Conta que não é de administração.
      await expectLater(repository.pending(), throwsA(isA<ForbiddenFailure>()));
    });
  });

  group('ReviewQueueController', () {
    late ControllableReviews reviews;
    late ControllableCatalog catalog;
    late ReviewQueueController controller;

    setUp(() {
      reviews = ControllableReviews(
        InMemoryReviewRepository(
          vendors: [buildVendorReview()],
          listings: [buildListingReview()],
        ),
      );
      catalog = ControllableCatalog();
      controller = ReviewQueueController(reviews: reviews, catalog: catalog);
    });

    tearDown(() => controller.dispose());

    ReviewQueue loaded() => controller.state.valueOrNull!;

    test('começa carregando e depois mostra a fila', () async {
      expect(controller.state, isA<LoadInProgress<ReviewQueue>>());

      await controller.load();

      expect(loaded().vendors.single.legalName, 'Maria Oliveira');
      expect(loaded().listings.single.title, 'Espaço Crystal');
    });

    test(
      'traduz categoria e tipos de evento pelos nomes do catálogo',
      () async {
        await controller.load();

        expect(controller.categoryName('venue'), 'Salões');
        expect(controller.eventTypeName('wedding'), 'Casamentos');
        expect(controller.categoryName('nova_categoria'), 'nova_categoria');
      },
    );

    test(
      'sem o catálogo a fila carrega do mesmo jeito, com as chaves',
      () async {
        catalog.failure = http.ClientException('offline');

        await controller.load();

        expect(loaded().vendors, hasLength(1));
        expect(controller.categoryName('venue'), 'venue');
      },
    );

    test(
      'falha ao carregar vira estado de erro; tentar de novo resolve',
      () async {
        reviews.loadFailure = const ForbiddenFailure();

        await controller.load();
        expect(
          controller.state,
          isA<LoadFailure<ReviewQueue>>().having(
            (state) => state.failure,
            'failure',
            isA<ForbiddenFailure>(),
          ),
        );

        reviews.loadFailure = null;
        await controller.load();
        expect(loaded().vendors, hasLength(1));
      },
    );

    test('atualização que falha mantém o que já estava na tela', () async {
      await controller.load();

      reviews.loadFailure = http.ClientException('offline');
      await controller.load();

      expect(loaded().vendors, hasLength(1));
    });

    test('decisão que dá certo devolve null e recarrega a fila', () async {
      await controller.load();
      final vendor = loaded().vendors.single;

      final failure = await controller.approveVendor(
        vendor,
        publishListings: true,
      );

      expect(failure, isNull);
      expect(loaded().vendors, isEmpty);
      expect(loaded().listings, isEmpty);
      expect(reviews.loads, 2);
    });

    test('recusar o cadastro tira da fila os anúncios dele', () async {
      await controller.load();

      final failure = await controller.rejectVendor(
        loaded().vendors.single,
        'Documento ilegível.',
      );

      expect(failure, isNull);
      expect(loaded().vendors, isEmpty);
      expect(loaded().listings, isEmpty);
    });

    test('publicar e recusar anúncios', () async {
      reviews = ControllableReviews(
        InMemoryReviewRepository(
          listings: [
            buildListingReview(vendorStatus: VendorStatus.approved),
            buildListingReview(
              id: 'listing-2',
              vendorStatus: VendorStatus.approved,
            ),
          ],
        ),
      );
      controller.dispose();
      controller = ReviewQueueController(reviews: reviews, catalog: catalog);
      await controller.load();

      expect(await controller.approveListing(loaded().listings.first), isNull);
      expect(
        await controller.rejectListing(
          loaded().listings.single,
          'Fotos ruins.',
        ),
        isNull,
      );

      expect(loaded().listings, isEmpty);
    });

    test('decisão recusada devolve a falha e recarrega mesmo assim', () async {
      await controller.load();
      final listing = loaded().listings.single;

      // O fornecedor ainda está em análise.
      final failure = await controller.approveListing(listing);

      expect(failure, isA<ConflictFailure>());
      expect(failure!.code, 'vendor_not_approved');
      expect(loaded().listings, hasLength(1));
      expect(reviews.loads, 2);
    });

    test('se outra pessoa já decidiu, o item some ao recarregar', () async {
      await controller.load();
      final vendor = loaded().vendors.single;
      // Outro administrador aprova enquanto esta tela está aberta.
      await reviews.approveVendor(vendor.id, publishListings: true);

      final failure = await controller.approveVendor(
        vendor,
        publishListings: true,
      );

      expect(failure!.code, 'already_reviewed');
      expect(loaded().vendors, isEmpty);
    });

    test('erro inesperado vira uma falha apresentável', () async {
      await controller.load();
      reviews.decisionFailure = StateError('bug');

      final failure = await controller.rejectListing(
        loaded().listings.single,
        'Fotos ruins.',
      );

      expect(failure, isA<UnexpectedFailure>());
    });

    test('marca o item enquanto a decisão está em andamento', () async {
      await controller.load();
      final vendor = loaded().vendors.single;
      reviews.gate = Completer<void>();

      final decision = controller.approveVendor(vendor, publishListings: true);
      await Future<void>.delayed(Duration.zero);

      expect(controller.isDeciding(vendor.id), isTrue);
      expect(controller.isDeciding('outro'), isFalse);

      // Um segundo toque enquanto a primeira decisão não terminou não manda
      // de novo.
      final loadsBefore = reviews.loads;
      expect(
        await controller.approveVendor(vendor, publishListings: true),
        isNull,
      );
      expect(reviews.loads, loadsBefore);

      reviews.gate!.complete();
      expect(await decision, isNull);
      expect(controller.isDeciding(vendor.id), isFalse);
    });

    test('descartado no meio de uma carga, não avisa mais ninguém', () async {
      // Sair da tela antes de a resposta chegar não pode quebrar o app.
      final discarded = ReviewQueueController(
        reviews: reviews,
        catalog: catalog,
      );
      var notifications = 0;
      discarded.addListener(() => notifications++);
      final loading = discarded.load();
      discarded.dispose();
      notifications = 0;

      await loading;

      expect(notifications, 0);
    });
  });
}
