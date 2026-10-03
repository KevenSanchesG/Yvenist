import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/rules/item_configuration_spec.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_configuration.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';

ItemConfigurationSpec specFor(
  PartyItemCategory category, {
  PricingModel model = PricingModel.fixed,
  bool isOwnService = false,
}) {
  return ItemConfigurationSpec.of(
    category: category,
    pricingModel: model,
    isOwnService: isOwnService,
  );
}

List<String> keys(
  PartyItemCategory category, {
  PricingModel model = PricingModel.fixed,
  bool isOwnService = false,
}) {
  final spec = specFor(category, model: model, isOwnService: isOwnService);
  return [for (final field in spec.fields) field.key];
}

List<String> required(
  PartyItemCategory category, {
  PricingModel model = PricingModel.fixed,
}) {
  return [
    for (final field in specFor(category, model: model).fields)
      if (field.isRequired) field.key,
  ];
}

/// Um campo em uma linha: chave, tipo, obrigatoriedade e limite. O teste da
/// API (`backend/tests/test_party_configuration.py`) descreve os campos dela do
/// mesmo jeito e compara com a mesma tabela.
String describe(ConfigField field) {
  final need = field.isRequired ? 'required' : 'optional';
  final limit = switch (field.kind) {
    ConfigFieldKind.integer => '${field.min}-${field.max}',
    ConfigFieldKind.choice => field.options.map((o) => o.value).join('|'),
    ConfigFieldKind.text => '${field.maxLength}',
  };
  return '${field.key}:${field.kind.name}:$need:$limit';
}

Matcher throwsFieldErrors(Map<String, String> errors) {
  return throwsA(
    isA<InvalidItemConfiguration>().having(
      (e) => e.fieldErrors,
      'fieldErrors',
      errors,
    ),
  );
}

void main() {
  group('o que cada categoria pede', () {
    test('a tabela inteira é a mesma da API', () {
      // A mesma tabela, literal, está no teste da API. Mudou um campo de um
      // lado, o teste daquele lado falha até a tabela mudar; e a tabela só
      // muda nos dois testes juntos.
      const expected = {
        'venue': (
          fields: [
            'duration_hours:integer:required:1-24',
            'requirements:text:optional:300',
            'notes:text:optional:500',
          ],
          quantity: false,
          event: true,
        ),
        'buffet': (
          fields: [
            'service_style:choice:required:plated|self_service|cocktail|barbecue',
            'menu:text:optional:200',
            'duration_hours:integer:optional:1-24',
            'notes:text:optional:500',
          ],
          quantity: false,
          event: false,
        ),
        'kids': (
          fields: [
            'duration_hours:integer:required:1-24',
            'age_range:choice:optional:up_to_3|from_4_to_7|from_8_to_12|all_ages',
            'notes:text:optional:500',
          ],
          quantity: true,
          event: false,
        ),
        'attraction': (
          fields: [
            'duration_hours:integer:required:1-24',
            'notes:text:optional:500',
          ],
          quantity: false,
          event: false,
        ),
        'decoration': (
          fields: [
            'theme:text:required:80',
            'environment:choice:optional:indoor|outdoor|both',
            'items:text:optional:300',
            'customization:text:optional:300',
            'notes:text:optional:500',
          ],
          quantity: true,
          event: false,
        ),
        'dj': (
          fields: [
            'duration_hours:integer:required:1-24',
            'notes:text:optional:500',
          ],
          quantity: false,
          event: false,
        ),
        'staff': (
          fields: [
            'duration_hours:integer:required:1-24',
            'notes:text:optional:500',
          ],
          quantity: true,
          event: false,
        ),
        'security': (
          fields: [
            'duration_hours:integer:required:1-24',
            'notes:text:optional:500',
          ],
          quantity: true,
          event: false,
        ),
        'beauty': (
          fields: ['notes:text:optional:500'],
          quantity: true,
          event: false,
        ),
        'other': (
          fields: ['variation:text:optional:80', 'notes:text:optional:500'],
          quantity: true,
          event: false,
        ),
      };

      expect({
        for (final category in PartyItemCategory.values) category.name,
      }, expected.keys.toSet());
      for (final category in PartyItemCategory.values) {
        final spec = specFor(category);
        final row = expected[category.name]!;

        expect(
          spec.fields.map(describe).toList(),
          row.fields,
          reason: category.name,
        );
        expect(spec.allowsQuantity, row.quantity, reason: category.name);
        expect(spec.requiresEventDetails, row.event, reason: category.name);
      }
    });

    test('toda categoria tem um formulário curto, que termina nas '
        'observações', () {
      for (final category in PartyItemCategory.values) {
        final spec = specFor(category);

        expect(spec.fields, isNotEmpty, reason: category.name);
        expect(spec.fields.last.key, ItemConfiguration.notesKey);
        expect(spec.fields.length, lessThanOrEqualTo(5));
      }
    });

    test('um salão pede o que um salão precisa', () {
      final spec = specFor(PartyItemCategory.venue);

      expect(keys(PartyItemCategory.venue), [
        'duration_hours',
        'requirements',
        'notes',
      ]);
      expect(required(PartyItemCategory.venue), ['duration_hours']);
      expect(spec.requiresEventDetails, isTrue);
      expect(spec.allowsQuantity, isFalse);
    });

    test('cada categoria é diferente da outra', () {
      expect(keys(PartyItemCategory.buffet), [
        'service_style',
        'menu',
        'duration_hours',
        'notes',
      ]);
      expect(keys(PartyItemCategory.kids), [
        'duration_hours',
        'age_range',
        'notes',
      ]);
      expect(required(PartyItemCategory.decoration), ['theme']);
      expect(required(PartyItemCategory.other), isEmpty);
    });

    test('a quantidade tem o nome do que se conta', () {
      expect(
        specFor(PartyItemCategory.staff).quantityLabel,
        'Número de profissionais',
      );
      expect(specFor(PartyItemCategory.other).quantityLabel, 'Quantidade');
      expect(specFor(PartyItemCategory.venue).quantityLabel, isNull);
    });

    test('cobrado por hora, a duração passa a ser obrigatória em qualquer '
        'categoria', () {
      // Na categoria que já tinha o campo, ele deixa de ser opcional...
      expect(
        required(PartyItemCategory.buffet),
        isNot(contains('duration_hours')),
      );
      expect(
        required(PartyItemCategory.buffet, model: PricingModel.perHour),
        contains('duration_hours'),
      );
      // ...e na que não tinha, ele entra, em primeiro lugar.
      expect(keys(PartyItemCategory.other, model: PricingModel.perHour), [
        'duration_hours',
        'variation',
        'notes',
      ]);
    });

    test('cobrado por unidade, a quantidade aparece', () {
      expect(specFor(PartyItemCategory.dj).allowsQuantity, isFalse);
      expect(
        specFor(
          PartyItemCategory.dj,
          model: PricingModel.perUnit,
        ).allowsQuantity,
        isTrue,
      );
    });

    test('um serviço do próprio anúncio pede só o que o preço dele usa', () {
      // Os detalhes da categoria são combinados com o mesmo fornecedor.
      expect(keys(PartyItemCategory.buffet, isOwnService: true), ['notes']);
      expect(
        keys(
          PartyItemCategory.attraction,
          model: PricingModel.perHour,
          isOwnService: true,
        ),
        ['duration_hours', 'notes'],
      );
      expect(
        specFor(
          PartyItemCategory.other,
          model: PricingModel.perUnit,
          isOwnService: true,
        ).allowsQuantity,
        isTrue,
      );
      expect(
        specFor(
          PartyItemCategory.venue,
          isOwnService: true,
        ).requiresEventDetails,
        isFalse,
      );
    });

    test('o rótulo de uma opção é o texto que a pessoa lê', () {
      final style = specFor(PartyItemCategory.buffet).field('service_style')!;

      expect(style.optionLabel('self_service'), 'Self-service');
      // Uma opção que o app ainda não conhece aparece como veio.
      expect(style.optionLabel('rodizio'), 'rodizio');
    });
  });

  group('validação da configuração', () {
    test('devolve a configuração limpa', () {
      final cleaned = specFor(PartyItemCategory.decoration).validate({
        'theme': '  Safari  ',
        'environment': 'outdoor',
        'items': '   ',
        'notes': null,
      });

      // Sem espaços nas pontas; o que ficou vazio não é gravado.
      expect(
        cleaned,
        ItemConfiguration(const {'theme': 'Safari', 'environment': 'outdoor'}),
      );
    });

    test('aponta todos os problemas de uma vez', () {
      final spec = specFor(
        PartyItemCategory.buffet,
        model: PricingModel.perHour,
      );

      expect(
        () => spec.validate({
          'service_style': 'rodizio',
          'menu': 'x' * 201,
          'cor': 'azul',
        }),
        throwsFieldErrors({
          'cor': 'Este item não tem esta informação.',
          'duration_hours': 'Campo obrigatório.',
          'service_style': 'Opção inválida.',
          'menu': 'Use no máximo 200 caracteres.',
        }),
      );
    });

    for (final (value, message) in <(Object, String)>[
      (0, 'Informe um valor de 1 a 24.'),
      (25, 'Informe um valor de 1 a 24.'),
      ('4', 'Informe um número inteiro.'),
      (4.5, 'Informe um número inteiro.'),
      (true, 'Informe um número inteiro.'),
    ]) {
      test('a duração é um número inteiro de horas, de 1 a 24: $value', () {
        expect(
          () =>
              specFor(PartyItemCategory.dj).validate({'duration_hours': value}),
          throwsFieldErrors({'duration_hours': message}),
        );
      });
    }

    test('um campo de texto não aceita um número', () {
      expect(
        () => specFor(PartyItemCategory.other).validate({'variation': 42}),
        throwsFieldErrors({'variation': 'Informe um texto.'}),
      );
    });

    test('campo obrigatório só com espaços conta como vazio', () {
      expect(
        () => specFor(PartyItemCategory.decoration).validate({'theme': '   '}),
        throwsFieldErrors({'theme': 'Campo obrigatório.'}),
      );
    });

    test('errorsIn devolve o mesmo que validate lançaria, sem lançar', () {
      final spec = specFor(PartyItemCategory.venue);

      expect(spec.errorsIn({'duration_hours': 4}), isEmpty);
      expect(spec.errorsIn(const {}), {'duration_hours': 'Campo obrigatório.'});
    });

    test('quantidade acima de um só onde faz sentido', () {
      final dj = specFor(PartyItemCategory.dj);

      expect(() => dj.checkQuantity(Quantity(1)), returnsNormally);
      expect(
        () => dj.checkQuantity(Quantity(2)),
        throwsA(
          isA<InvalidQuantity>().having(
            (e) => e.message,
            'message',
            contains('uma vez só'),
          ),
        ),
      );
      expect(
        () => specFor(PartyItemCategory.other).checkQuantity(Quantity(999)),
        returnsNormally,
      );
    });
  });
}
