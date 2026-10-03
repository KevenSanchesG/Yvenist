import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_date.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/guest_count.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_configuration.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_relation.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/pricing.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/vendor_response.dart';

import '../party_fixtures.dart';

Matcher throwsDomainCode(String code) =>
    throwsA(isA<PartyDomainException>().having((e) => e.code, 'code', code));

void main() {
  group('Money', () {
    test('usa BRL como moeda padrão', () {
      final money = Money.fromCents(1500);

      expect(money.cents, 1500);
      expect(money.currency, 'BRL');
      expect(Money.zero().cents, 0);
    });

    test('soma, subtrai e multiplica sem perder precisão', () {
      final a = Money.fromCents(1999);
      final b = Money.fromCents(1);

      expect(a + b, Money.fromCents(2000));
      expect(a - b, Money.fromCents(1998));
      expect(a.multiplyInt(3), Money.fromCents(5997));
    });

    test('permite resultado negativo e o sinaliza', () {
      final result = Money.fromCents(100) - Money.fromCents(250);

      expect(result.cents, -150);
      expect(result.isNegative, isTrue);
      expect(Money.zero().isNegative, isFalse);
    });

    test('rejeita operações entre moedas diferentes', () {
      final brl = Money.fromCents(100);
      final usd = Money.fromCents(100, currency: 'USD');

      expect(() => brl + usd, throwsDomainCode('currency_mismatch'));
      expect(() => brl - usd, throwsDomainCode('currency_mismatch'));
      expect(() => brl.compareTo(usd), throwsDomainCode('currency_mismatch'));
    });

    test('compara por valor e moeda', () {
      expect(Money.fromCents(100), Money.fromCents(100));
      expect(Money.fromCents(100).hashCode, Money.fromCents(100).hashCode);
      expect(
        Money.fromCents(100),
        isNot(Money.fromCents(100, currency: 'USD')),
      );
      expect(Money.fromCents(100).compareTo(Money.fromCents(200)), lessThan(0));
    });
  });

  // A mesma tabela de `backend/tests/test_pricing.py`: as duas contas têm de
  // dar o mesmo resultado para a mesma entrada.
  group('Pricing: a estimativa', () {
    Money? estimate(
      PricingModel model, {
      int? cents = 10000,
      int? minimum,
      int? guests,
      int? hours,
      int quantity = 1,
    }) {
      return buildPricing(
        model: model,
        cents: cents,
        minimumCents: minimum,
      ).estimate(guests: guests, hours: hours, quantity: quantity);
    }

    test('valor fixo não muda com convidados, horas ou quantidade', () {
      expect(
        estimate(PricingModel.fixed, guests: 80, hours: 5, quantity: 3),
        Money.fromCents(10000),
      );
    });

    test('por unidade multiplica pela quantidade', () {
      expect(
        estimate(PricingModel.perUnit, quantity: 3),
        Money.fromCents(30000),
      );
    });

    test('por pessoa multiplica pelos convidados e pela quantidade', () {
      expect(
        estimate(PricingModel.perPerson, guests: 80),
        Money.fromCents(800000),
      );
      expect(
        estimate(PricingModel.perPerson, guests: 80, quantity: 2),
        Money.fromCents(1600000),
      );
    });

    test('por hora multiplica pelas horas e pela quantidade', () {
      expect(estimate(PricingModel.perHour, hours: 4), Money.fromCents(40000));
      expect(
        estimate(PricingModel.perHour, hours: 4, quantity: 2),
        Money.fromCents(80000),
      );
    });

    test('o valor mínimo vale quando a conta dá menos', () {
      expect(
        estimate(PricingModel.perPerson, guests: 10, minimum: 250000),
        Money.fromCents(250000),
      );
      expect(
        estimate(PricingModel.perPerson, guests: 80, minimum: 250000),
        Money.fromCents(800000),
      );
    });

    test('sem a medida de que o preço depende, não há estimativa', () {
      expect(estimate(PricingModel.perPerson), isNull);
      expect(estimate(PricingModel.perHour), isNull);
    });

    test('sob consulta nunca vira um número', () {
      expect(
        estimate(
          PricingModel.onRequest,
          cents: null,
          guests: 80,
          hours: 4,
          quantity: 2,
        ),
        isNull,
      );
      expect(
        const Pricing.onRequest().estimate(guests: 80, hours: 4, quantity: 1),
        isNull,
      );
    });

    test('um preço sem valor é tratado como sob consulta', () {
      // Falhar fechado: o app nunca estima em cima de um valor que não veio.
      final pricing = buildPricing(model: PricingModel.perPerson, cents: null);

      expect(pricing.model, PricingModel.onRequest);
      expect(pricing.isOnRequest, isTrue);
      expect(pricing.amount, isNull);
    });

    test('sob consulta descarta o valor e o mínimo que vierem junto', () {
      final pricing = buildPricing(
        model: PricingModel.onRequest,
        cents: 5000,
        minimumCents: 1000,
      );

      expect(pricing.amount, isNull);
      expect(pricing.minimum, isNull);
    });

    test('modelo de preço que o app não conhece vira sob consulta', () {
      expect(PricingModel.fromApi('per_galaxy'), PricingModel.onRequest);
      expect(PricingModel.fromApi(null), PricingModel.onRequest);
      for (final model in PricingModel.values) {
        expect(PricingModel.fromApi(model.apiValue), model);
      }
    });
  });

  group('Quantity', () {
    test('aceita de 1 até o teto', () {
      expect(Quantity(1).value, 1);
      expect(Quantity(Quantity.max).value, 999);
      expect(Quantity(5), Quantity(5));
    });

    test('rejeita zero, negativos e acima do teto', () {
      expect(() => Quantity(0), throwsDomainCode('invalid_quantity'));
      expect(() => Quantity(-1), throwsDomainCode('invalid_quantity'));
      expect(() => Quantity(1000), throwsDomainCode('invalid_quantity'));
    });
  });

  group('GuestCount', () {
    test('aceita de 1 até o teto', () {
      expect(GuestCount(1).value, 1);
      expect(GuestCount(50), GuestCount(50));
      expect(GuestCount(GuestCount.max).value, 100000);
    });

    test('rejeita zero e acima do teto', () {
      expect(() => GuestCount(0), throwsDomainCode('invalid_guest_count'));
      expect(() => GuestCount(100001), throwsDomainCode('invalid_guest_count'));
    });
  });

  group('PartyTitle', () {
    test('remove espaços nas pontas e repetidos no meio', () {
      expect(PartyTitle('  15 anos   da Maria  ').value, '15 anos da Maria');
    });

    test('rejeita título vazio ou só com espaços', () {
      expect(() => PartyTitle(''), throwsDomainCode('invalid_party_title'));
      expect(() => PartyTitle('   '), throwsDomainCode('invalid_party_title'));
    });

    test('rejeita título acima do limite', () {
      expect(PartyTitle('a' * 80).value, hasLength(80));
      expect(
        () => PartyTitle('a' * 81),
        throwsDomainCode('invalid_party_title'),
      );
    });
  });

  group('ItemConfiguration', () {
    test('duas configurações com os mesmos valores são iguais', () {
      final a = ItemConfiguration(const {'duration_hours': 4, 'notes': 'x'});
      final b = ItemConfiguration(const {'notes': 'x', 'duration_hours': 4});

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(ItemConfiguration(const {'duration_hours': 5})));
      expect(ItemConfiguration(const {}), ItemConfiguration.empty);
    });

    test('lê a duração só quando é um número', () {
      expect(ItemConfiguration(const {'duration_hours': 4}).durationHours, 4);
      expect(
        ItemConfiguration(const {'duration_hours': 'quatro'}).durationHours,
        isNull,
      );
      expect(ItemConfiguration.empty.durationHours, isNull);
    });

    test('não pode ser alterada depois de criada', () {
      final configuration = ItemConfiguration({'notes': 'x'});

      expect(() => configuration.values['notes'] = 'y', throwsUnsupportedError);
    });
  });

  group('ItemRelation', () {
    const parent = PartyItemId('venue-1');

    test('serviço próprio é o ligado e o obrigatório', () {
      expect(const ItemRelation.linkedTo(parent).isOwnService, isTrue);
      expect(const ItemRelation.requiredBy(parent).isOwnService, isTrue);
      expect(const ItemRelation.requiredBy(parent).isRequired, isTrue);
      expect(const ItemRelation.recommendedBy(parent).isOwnService, isFalse);
      expect(const ItemRelation.independent().isOwnService, isFalse);
      expect(const ItemRelation.independent().parentId, isNull);
    });

    test('sem o item a que se liga, só pode ser independente', () {
      // Falhar fechado: uma relação gravada sem o pai não dá privilégio.
      expect(
        ItemRelation.restore(ItemRelationKind.required, null),
        const ItemRelation.independent(),
      );
      expect(
        ItemRelation.restore(ItemRelationKind.linked, parent),
        const ItemRelation.linkedTo(parent),
      );
    });

    test('relação que o app não conhece vira independente', () {
      expect(ItemRelationKind.fromApi('bundled'), ItemRelationKind.independent);
      for (final kind in ItemRelationKind.values) {
        expect(ItemRelationKind.fromApi(kind.apiValue), kind);
      }
    });
  });

  group('ItemQuote', () {
    test('só é um orçamento quando o fornecedor deu o valor', () {
      expect(const ItemQuote.none().isQuoted, isFalse);
      expect(const ItemQuote.pending().isQuoted, isFalse);
      expect(
        ItemQuote(
          status: QuoteStatus.quoted,
          amount: Money.fromCents(100),
        ).isQuoted,
        isTrue,
      );
    });

    test('pedido de alteração e recusa voltam para a pessoa', () {
      expect(
        const ItemQuote(status: QuoteStatus.changesRequested).needsTheClient,
        isTrue,
      );
      expect(
        const ItemQuote(status: QuoteStatus.declined).needsTheClient,
        isTrue,
      );
      expect(const ItemQuote.pending().needsTheClient, isFalse);
    });

    test('resposta que o app não conhece fica como aguardando', () {
      // Falhar fechado: nada é tratado como respondido sem o app saber ler.
      expect(QuoteStatus.fromApi('counter_offer'), QuoteStatus.pending);
      for (final status in QuoteStatus.values) {
        expect(QuoteStatus.fromApi(status.apiValue), status);
      }
    });
  });

  group('VendorResponse', () {
    test('cada resposta carrega o status que representa', () {
      final quote = VendorResponse.quote(Money.fromCents(100), message: 'ok');

      expect(quote.status, QuoteStatus.quoted);
      expect(quote.amount, Money.fromCents(100));
      expect(
        const VendorResponse.requestChanges('Mude a data').status,
        QuoteStatus.changesRequested,
      );
      expect(
        const VendorResponse.decline('Sem agenda').status,
        QuoteStatus.declined,
      );
      expect(const VendorResponse.decline('Sem agenda').amount, isNull);
    });
  });

  group('identidade dos value objects', () {
    test('ids são comparados por valor', () {
      expect(const PartyId('a'), const PartyId('a'));
      expect(const PartyId('a'), isNot(const PartyId('b')));
      expect(const PartyItemId('a'), const PartyItemId('a'));
      expect(const PartyItemId('a').hashCode, const PartyItemId('a').hashCode);
    });

    test('ExternalRef considera a origem e o id', () {
      const listing = ExternalRef.listing('42');

      expect(listing, const ExternalRef.listing('42'));
      expect(listing, isNot(const ExternalRef.offer('42')));
      expect(listing, isNot(const ExternalRef.listing('43')));
      expect(listing.isListing, isTrue);
      expect(const ExternalRef.offer('42').isOffer, isTrue);
    });

    test('a origem que saiu do catálogo não aponta para nada', () {
      const gone = ExternalRef.unavailable('item-1');

      expect(gone.isAvailable, isFalse);
      expect(gone.isListing, isFalse);
      expect(gone.isOffer, isFalse);
      expect(const ExternalRef.listing('1').isAvailable, isTrue);
    });

    test('EventDate é comparada pelo instante', () {
      final local = DateTime(2026, 12, 25, 19);

      expect(EventDate(local), EventDate(DateTime(2026, 12, 25, 19)));
      expect(EventDate(local), EventDate(local.toUtc()));
      expect(EventDate(local), isNot(EventDate(DateTime(2026, 12, 25, 20))));
    });
  });
}
