import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_date.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/guest_count.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';

Matcher throwsDomainCode(String code) => throwsA(
      isA<PartyDomainException>().having((e) => e.code, 'code', code),
    );

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
      expect(Money.fromCents(100), isNot(Money.fromCents(100, currency: 'USD')));
      expect(Money.fromCents(100).compareTo(Money.fromCents(200)), lessThan(0));
    });
  });

  group('Quantity', () {
    test('aceita valores a partir de 1', () {
      expect(Quantity(1).value, 1);
      expect(Quantity(2).add(Quantity(3)), Quantity(5));
    });

    test('rejeita zero e negativos', () {
      expect(() => Quantity(0), throwsDomainCode('invalid_quantity'));
      expect(() => Quantity(-1), throwsDomainCode('invalid_quantity'));
    });
  });

  group('GuestCount', () {
    test('aceita valores a partir de 1', () {
      expect(GuestCount(1).value, 1);
      expect(GuestCount(50), GuestCount(50));
    });

    test('rejeita zero e negativos', () {
      expect(() => GuestCount(0), throwsDomainCode('invalid_guest_count'));
    });
  });

  group('PartyTitle', () {
    test('remove espaços nas pontas', () {
      expect(PartyTitle('  15 anos da Maria  ').value, '15 anos da Maria');
    });

    test('rejeita título vazio ou só com espaços', () {
      expect(() => PartyTitle(''), throwsDomainCode('invalid_party_title'));
      expect(() => PartyTitle('   '), throwsDomainCode('invalid_party_title'));
    });
  });

  group('identidade dos value objects', () {
    test('ids são comparados por valor', () {
      expect(const PartyId('a'), const PartyId('a'));
      expect(const PartyId('a'), isNot(const PartyId('b')));
      expect(const PartyItemId('a'), const PartyItemId('a'));
      expect(const PartyItemId('a').hashCode, const PartyItemId('a').hashCode);
    });

    test('ExternalRef considera origem e id', () {
      const ref = ExternalRef(source: 'vendor_catalog', id: '42');

      expect(ref, const ExternalRef(source: 'vendor_catalog', id: '42'));
      expect(ref, isNot(const ExternalRef(source: 'outra_origem', id: '42')));
      expect(ref, isNot(const ExternalRef(source: 'vendor_catalog', id: '43')));
    });

    test('EventDate é comparada pela data', () {
      final date = DateTime(2026, 12, 25, 19);

      expect(EventDate(date), EventDate(DateTime(2026, 12, 25, 19)));
    });
  });
}
