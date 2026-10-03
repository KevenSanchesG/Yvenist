import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/features/vendor/data/api_vendor_repository.dart';
import 'package:yvenist/features/vendor/data/in_memory_vendor_repository.dart';
import 'package:yvenist/features/vendor/domain/vendor_models.dart';
import 'package:yvenist/features/vendor/domain/vendor_repository.dart';
import 'package:yvenist/features/vendor/presentation/controllers/vendor_controller.dart';

import '../../support/fake_api.dart';

const String validCpf = '52998224725';
const String validCnpj = '11222333000181';

HallListingDraft draft({
  PersonType personType = PersonType.individual,
  String document = validCpf,
  String title = 'Espaço Crystal',
}) {
  return HallListingDraft(
    personType: personType,
    document: document,
    legalName: 'Maria Oliveira',
    title: title,
    description: 'Salão amplo, climatizado, com cozinha equipada.',
    neighborhood: 'Campo Grande',
    city: 'Rio de Janeiro',
    state: 'RJ',
    priceFromCents: 250000,
    areaM2: 300,
    capacity: 150,
    eventTypes: const {'wedding', 'debutante'},
    amenities: const {'wifi', 'kitchen'},
    cancellationPolicy: CancellationPolicy.moderate,
  );
}

/// Repositório sem a capacidade de aprovação do modo demonstração, que falha
/// quando mandado.
class StrictVendorRepository implements VendorRepository {
  StrictVendorRepository(this._inner);

  final InMemoryVendorRepository _inner;
  Object? failure;

  void _failIfAsked() {
    final error = failure;
    if (error != null) Error.throwWithStackTrace(error, StackTrace.current);
  }

  @override
  Future<VendorProfile?> myProfile() async {
    _failIfAsked();
    return _inner.myProfile();
  }

  @override
  Future<List<VendorListing>> myListings() async {
    _failIfAsked();
    return _inner.myListings();
  }

  @override
  Future<VendorProfile> submitHall(HallListingDraft draft) async {
    _failIfAsked();
    return _inner.submitHall(draft);
  }
}

void main() {
  group('InMemoryVendorRepository', () {
    String? currentUser;
    late InMemoryVendorRepository repository;

    setUp(() {
      currentUser = 'ana';
      repository = InMemoryVendorRepository(currentUserId: () => currentUser);
    });

    test('conta sem cadastro não é fornecedora', () async {
      expect(await repository.myProfile(), isNull);
      expect(await repository.myListings(), isEmpty);
    });

    test('enviar o salão cria o cadastro e o anúncio em análise', () async {
      final profile = await repository.submitHall(draft());

      expect(profile.status, VendorStatus.pendingReview);
      expect(profile.legalName, 'Maria Oliveira');
      // O documento nunca fica legível.
      expect(profile.documentMasked, '529.***.***-25');
      final listing = (await repository.myListings()).single;
      expect(listing.title, 'Espaço Crystal');
      expect(listing.status, VendorListingStatus.pendingReview);
    });

    test('mascara CNPJ', () async {
      final profile = await repository.submitHall(
        draft(personType: PersonType.company, document: '11.222.333/0001-81'),
      );

      expect(profile.documentMasked, '11.***.***/****-81');
    });

    test('recusa documento inválido ou do tipo errado', () async {
      await expectLater(
        repository.submitHall(draft(document: '12345678900')),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        repository.submitHall(draft(document: validCnpj)),
        throwsA(isA<ValidationFailure>()),
      );
      expect(await repository.myProfile(), isNull);
    });

    test('um segundo anúncio reaproveita o cadastro', () async {
      await repository.submitHall(draft());
      await repository.submitHall(draft(title: 'Segundo espaço'));

      final listings = await repository.myListings();
      expect(listings.map((l) => l.title), [
        'Segundo espaço',
        'Espaço Crystal',
      ]);
    });

    test('aprovar publica os anúncios que estavam em análise', () async {
      await repository.submitHall(draft());

      final approved = await repository.approveMyProfile();

      expect(approved.status, VendorStatus.approved);
      expect(
        (await repository.myListings()).single.status,
        VendorListingStatus.published,
      );
    });

    test('os cadastros são separados por conta', () async {
      await repository.submitHall(draft());

      currentUser = 'bruno';

      expect(await repository.myProfile(), isNull);
    });

    test('sem conta autenticada, falha como não autenticado', () async {
      currentUser = null;

      await expectLater(
        repository.myProfile(),
        throwsA(isA<UnauthorizedFailure>()),
      );
    });
  });

  group('ApiVendorRepository', () {
    late FakeApi api;
    late ApiVendorRepository repository;

    Map<String, dynamic> vendorJson({String status = 'pending_review'}) {
      return {
        'id': 'v1',
        'person_type': 'pf',
        'document_masked': '529.***.***-25',
        'legal_name': 'Maria Oliveira',
        'status': status,
        'rejection_reason': status == 'rejected' ? 'Documento ilegível.' : null,
        'created_at': '2026-10-01T12:00:00Z',
      };
    }

    setUp(() {
      api = FakeApi();
      repository = ApiVendorRepository(api.client);
    });

    test('conta sem cadastro (404) devolve null', () async {
      api.fail(
        'GET',
        '/vendors/me',
        404,
        'vendor_profile_not_found',
        'Sem cadastro.',
      );

      expect(await repository.myProfile(), isNull);
    });

    test('converte o cadastro e todos os status', () async {
      for (final (apiStatus, status) in [
        ('pending_review', VendorStatus.pendingReview),
        ('approved', VendorStatus.approved),
        ('rejected', VendorStatus.rejected),
      ]) {
        api.reply('GET', '/vendors/me', vendorJson(status: apiStatus));

        final profile = await repository.myProfile();

        expect(profile!.status, status);
        expect(profile.legalName, 'Maria Oliveira');
        expect(profile.documentMasked, '529.***.***-25');
      }
    });

    test('traz o motivo da recusa', () async {
      api.reply('GET', '/vendors/me', vendorJson(status: 'rejected'));

      expect(
        (await repository.myProfile())!.rejectionReason,
        'Documento ilegível.',
      );
    });

    test('status desconhecido é tratado como "em análise"', () async {
      // Um status novo no servidor não pode liberar o modo fornecedor.
      api.reply('GET', '/vendors/me', vendorJson(status: 'suspended'));

      expect(
        (await repository.myProfile())!.status,
        VendorStatus.pendingReview,
      );
    });

    test('lista os anúncios próprios; sem cadastro, a lista é vazia', () async {
      api.reply('GET', '/vendors/me/listings', {
        'items': [
          {
            'id': 'l1',
            'title': 'Espaço Crystal',
            'status': 'published',
            'rejection_reason': null,
          },
          {
            'id': 'l2',
            'title': 'Segundo espaço',
            'status': 'rejected',
            'rejection_reason': 'Fotos insuficientes.',
          },
        ],
      });
      final listings = await repository.myListings();
      expect(listings.map((l) => l.status), [
        VendorListingStatus.published,
        VendorListingStatus.rejected,
      ]);
      expect(listings.last.rejectionReason, 'Fotos insuficientes.');

      api.fail(
        'GET',
        '/vendors/me/listings',
        404,
        'vendor_profile_not_found',
        'x',
      );
      expect(await repository.myListings(), isEmpty);
    });

    test('envia o cadastro e o anúncio no formato da API', () async {
      api.reply('POST', '/vendors/onboarding', {
        'vendor': vendorJson(),
        'listing': {'id': 'l1'},
      }, status: 201);

      final profile = await repository.submitHall(draft());

      expect(profile.status, VendorStatus.pendingReview);
      final body = api.lastBody;
      expect(body['vendor'], {
        'person_type': 'pf',
        'document': validCpf,
        'legal_name': 'Maria Oliveira',
      });
      final listing = body['listing'] as Map<String, dynamic>;
      expect(listing['category'], 'venue');
      expect(listing['title'], 'Espaço Crystal');
      expect(listing['neighborhood'], 'Campo Grande');
      expect(listing['city'], 'Rio de Janeiro');
      expect(listing['state'], 'RJ');
      expect(listing['pricing_model'], 'fixed');
      expect(listing['price_from_cents'], 250000);
      expect(listing['minimum_price_cents'], isNull);
      expect(listing['offers'], isEmpty);
      expect(listing['capacity'], 150);
      expect(listing['area_m2'], 300);
      expect(listing['amenities'], unorderedEquals(['wifi', 'kitchen']));
      expect(listing['event_types'], unorderedEquals(['wedding', 'debutante']));
      expect(listing['cancellation_policy'], 'moderate');
      // O cliente não escolhe status nem avaliações.
      expect(listing.containsKey('status'), isFalse);
      expect(api.lastRequest.headers['Authorization'], 'Bearer acesso');
    });

    test('envia como o salão cobra e os serviços que ele oferece', () async {
      api.reply('POST', '/vendors/onboarding', {
        'vendor': vendorJson(),
        'listing': {'id': 'l1'},
      }, status: 201);

      await repository.submitHall(
        const HallListingDraft(
          personType: PersonType.individual,
          document: validCpf,
          legalName: 'Maria Oliveira',
          title: 'Espaço Crystal',
          description: 'Salão amplo, climatizado, com cozinha equipada.',
          city: 'Rio de Janeiro',
          state: 'RJ',
          pricingModel: PricingModel.perPerson,
          priceFromCents: 9000,
          minimumPriceCents: 450000,
          offers: [
            OfferDraft(
              categorySlug: 'other',
              name: 'Taxa de limpeza',
              priceCents: 15000,
              isRequired: true,
            ),
            OfferDraft(
              categorySlug: 'decoration',
              name: 'Decoração',
              pricingModel: PricingModel.onRequest,
              priceCents: null,
            ),
          ],
        ),
      );

      final listing = api.lastBody['listing'] as Map<String, dynamic>;
      expect(listing['pricing_model'], 'per_person');
      expect(listing['price_from_cents'], 9000);
      expect(listing['minimum_price_cents'], 450000);
      expect(listing['offers'], [
        {
          'category': 'other',
          'name': 'Taxa de limpeza',
          'pricing_model': 'fixed',
          'price_cents': 15000,
          'required': true,
        },
        // Sob consulta não tem preço: a API espera zero.
        {
          'category': 'decoration',
          'name': 'Decoração',
          'pricing_model': 'on_request',
          'price_cents': 0,
          'required': false,
        },
      ]);
    });

    test('pessoa jurídica vai como "pj"', () async {
      api.reply('POST', '/vendors/onboarding', {
        'vendor': vendorJson(),
        'listing': <String, dynamic>{},
      }, status: 201);

      await repository.submitHall(
        draft(personType: PersonType.company, document: validCnpj),
      );

      expect((api.lastBody['vendor'] as Map)['person_type'], 'pj');
    });

    test('documento já usado por outra conta chega como conflito', () async {
      api.fail(
        'POST',
        '/vendors/onboarding',
        409,
        'document_already_registered',
        'Este CPF/CNPJ já está vinculado a outro cadastro.',
      );

      await expectLater(
        repository.submitHall(draft()),
        throwsA(
          isA<ConflictFailure>().having(
            (f) => f.code,
            'code',
            'document_already_registered',
          ),
        ),
      );
    });
  });

  group('VendorController', () {
    String? currentUser;
    late InMemoryVendorRepository repository;
    late VendorController controller;

    setUp(() {
      currentUser = 'ana';
      repository = InMemoryVendorRepository(currentUserId: () => currentUser);
      controller = VendorController(repository);
    });

    tearDown(() => controller.dispose());

    test('começa sem cadastro e não carregado', () {
      expect(controller.status, VendorStatus.none);
      expect(controller.isApproved, isFalse);
      expect(controller.hasLoaded, isFalse);
      expect(controller.listings, isEmpty);
    });

    test('ao entrar, carrega o cadastro e os anúncios da conta', () async {
      await repository.submitHall(draft());

      await controller.setUser('ana');

      expect(controller.hasLoaded, isTrue);
      expect(controller.status, VendorStatus.pendingReview);
      expect(controller.listings, hasLength(1));
      expect(controller.countListings(VendorListingStatus.pendingReview), 1);
      expect(controller.countListings(VendorListingStatus.published), 0);
    });

    test('visitante não é fornecedor', () async {
      await controller.setUser(null);

      expect(controller.hasLoaded, isTrue);
      expect(controller.status, VendorStatus.none);
    });

    test('ao trocar de conta, esquece o cadastro anterior', () async {
      await repository.submitHall(draft());
      await controller.setUser('ana');

      currentUser = 'bruno';
      await controller.setUser('bruno');

      expect(controller.status, VendorStatus.none);
      expect(controller.listings, isEmpty);
    });

    test('enviar o salão atualiza o status e a lista', () async {
      await controller.setUser('ana');

      final sent = await controller.submitHall(draft());

      expect(sent, isTrue);
      expect(controller.status, VendorStatus.pendingReview);
      expect(controller.listings.single.title, 'Espaço Crystal');
      expect(controller.failure, isNull);
      expect(controller.isBusy, isFalse);
    });

    test(
      'falha no envio fica disponível para a tela e não muda o status',
      () async {
        await controller.setUser('ana');

        final sent = await controller.submitHall(
          draft(document: '12345678900'),
        );

        expect(sent, isFalse);
        expect(controller.failure, isA<ValidationFailure>());
        expect(controller.status, VendorStatus.none);

        controller.clearError();
        expect(controller.failure, isNull);
      },
    );

    test('simular aprovação só existe no modo demonstração', () async {
      await controller.setUser('ana');
      await controller.submitHall(draft());
      expect(controller.canSimulateApproval, isTrue);

      expect(await controller.simulateApproval(), isTrue);
      expect(controller.isApproved, isTrue);
      expect(controller.countListings(VendorListingStatus.published), 1);

      final strict = VendorController(StrictVendorRepository(repository));
      addTearDown(strict.dispose);
      expect(strict.canSimulateApproval, isFalse);
      expect(await strict.simulateApproval(), isFalse);
    });

    test(
      'se não der para consultar, a conta é tratada como não fornecedora',
      () async {
        // Falhar "fechado": sem confirmação do servidor, o modo fornecedor não
        // é liberado.
        await repository.submitHall(draft());
        await repository.approveMyProfile();
        final flaky = StrictVendorRepository(repository)
          ..failure = http.ClientException('offline');
        final offline = VendorController(flaky);
        addTearDown(offline.dispose);

        await offline.setUser('ana');

        expect(offline.hasLoaded, isTrue);
        expect(offline.isApproved, isFalse);

        flaky.failure = null;
        await offline.load();
        expect(offline.isApproved, isTrue);
      },
    );

    test('fica ocupado durante o envio e avisa os ouvintes', () async {
      await controller.setUser('ana');
      final busyStates = <bool>[];
      controller.addListener(() => busyStates.add(controller.isBusy));

      await controller.submitHall(draft());

      expect(busyStates.first, isTrue);
      expect(busyStates.last, isFalse);
    });
  });
}
