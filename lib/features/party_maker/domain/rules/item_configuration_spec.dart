import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_configuration.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';

/// O que cada tipo de item pede para entrar em uma festa.
///
/// Um salão não se configura como um brinquedo: cada categoria tem a sua lista
/// curta de campos, e só eles. Incluir uma categoria é acrescentar uma entrada
/// em [_categorySpecs]; a tela monta o formulário a partir daqui e nada mais
/// muda.
///
/// A API tem a mesma tabela (`backend/app/modules/parties/configuration.py`) e
/// valida tudo de novo. As duas têm de concordar: chave, tipo, obrigatoriedade
/// e limites.

enum ConfigFieldKind { integer, choice, text }

/// Uma opção de um campo de escolha: o valor gravado e o texto que a pessoa lê.
class ConfigOption {
  const ConfigOption(this.value, this.label);

  final String value;
  final String label;
}

class ConfigField {
  const ConfigField.integer(
    this.key,
    this.label, {
    required this.min,
    required this.max,
    this.isRequired = false,
    this.hint,
  }) : kind = ConfigFieldKind.integer,
       options = const [],
       maxLength = 0,
       isMultiline = false;

  const ConfigField.choice(
    this.key,
    this.label,
    this.options, {
    this.isRequired = false,
  }) : kind = ConfigFieldKind.choice,
       min = 0,
       max = 0,
       maxLength = 0,
       hint = null,
       isMultiline = false;

  const ConfigField.text(
    this.key,
    this.label, {
    required this.maxLength,
    this.isRequired = false,
    this.hint,
    this.isMultiline = false,
  }) : kind = ConfigFieldKind.text,
       options = const [],
       min = 0,
       max = 0;

  const ConfigField._({
    required this.key,
    required this.label,
    required this.kind,
    required this.isRequired,
    required this.min,
    required this.max,
    required this.options,
    required this.maxLength,
    required this.hint,
    required this.isMultiline,
  });

  final String key;

  /// O nome do campo na tela.
  final String label;
  final ConfigFieldKind kind;
  final bool isRequired;

  /// O intervalo aceito por um campo inteiro.
  final int min;
  final int max;

  /// Os valores aceitos por um campo de escolha.
  final List<ConfigOption> options;

  /// O tamanho máximo de um campo de texto.
  final int maxLength;

  /// Um exemplo do que escrever.
  final String? hint;
  final bool isMultiline;

  ConfigField asRequired() {
    return ConfigField._(
      key: key,
      label: label,
      kind: kind,
      isRequired: true,
      min: min,
      max: max,
      options: options,
      maxLength: maxLength,
      hint: hint,
      isMultiline: isMultiline,
    );
  }

  /// O texto de uma opção gravada; uma que o app não conhece aparece como veio.
  String optionLabel(String value) {
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return value;
  }

  /// O que há de errado com [value] neste campo, ou `null` se está certo.
  /// [value] já vem limpo: nulo quando a pessoa não preencheu.
  String? problemWith(Object? value) {
    if (value == null) return isRequired ? 'Campo obrigatório.' : null;

    switch (kind) {
      case ConfigFieldKind.integer:
        if (value is! int) return 'Informe um número inteiro.';
        if (value < min || value > max) {
          return 'Informe um valor de $min a $max.';
        }
      case ConfigFieldKind.choice:
        if (!options.any((option) => option.value == value)) {
          return 'Opção inválida.';
        }
      case ConfigFieldKind.text:
        if (value is! String) return 'Informe um texto.';
        if (value.length > maxLength) {
          return 'Use no máximo $maxLength caracteres.';
        }
    }
    return null;
  }
}

class ItemConfigurationSpec {
  const ItemConfigurationSpec({
    required this.fields,
    this.quantityLabel,
    this.requiresEventDetails = false,
  });

  final List<ConfigField> fields;

  /// Como a quantidade se chama para este item. Nulo: o item é contratado uma
  /// vez só, e não faz sentido pedir "2 salões".
  final String? quantityLabel;

  /// O item é o lugar da festa: não entra sem a data e o número de convidados.
  final bool requiresEventDetails;

  bool get allowsQuantity => quantityLabel != null;

  ConfigField? field(String key) {
    for (final field in fields) {
      if (field.key == key) return field;
    }
    return null;
  }

  /// O que um item desta categoria, cobrado deste jeito, pede.
  ///
  /// Um serviço do próprio anunciante ([isOwnService]) é um complemento do
  /// anúncio: os detalhes da categoria são combinados com o mesmo fornecedor,
  /// e só se pede o que o preço usa.
  factory ItemConfigurationSpec.of({
    required PartyItemCategory category,
    required PricingModel pricingModel,
    required bool isOwnService,
  }) {
    final base = isOwnService ? _ownServiceSpec : _categorySpecs[category]!;
    var fields = base.fields;
    var quantityLabel = base.quantityLabel;

    if (pricingModel == PricingModel.perHour) {
      // Cobrado por hora, a duração deixa de ser opcional: sem ela não há
      // estimativa. Entra no formulário mesmo se a categoria não a previa.
      final duration = (base.field(ItemConfiguration.durationKey) ?? _duration)
          .asRequired();
      fields = [
        duration,
        for (final field in fields)
          if (field.key != ItemConfiguration.durationKey) field,
      ];
    }
    if (pricingModel == PricingModel.perUnit) quantityLabel ??= 'Quantidade';

    return ItemConfigurationSpec(
      fields: fields,
      quantityLabel: quantityLabel,
      requiresEventDetails: base.requiresEventDetails,
    );
  }

  /// O erro de cada campo de [raw], pela chave. Vazio quando está tudo certo.
  Map<String, String> errorsIn(Map<String, Object?> raw) {
    return {
      for (final key in raw.keys)
        if (field(key) == null) key: 'Este item não tem esta informação.',
      for (final field in fields)
        field.key: ?field.problemWith(_clean(raw[field.key])),
    };
  }

  /// A configuração limpa, pronta para gravar, ou [InvalidItemConfiguration]
  /// com o erro de cada campo.
  ///
  /// Texto sai sem espaços nas pontas; o que ficou vazio não é gravado. Assim
  /// duas configurações iguais são iguais também na comparação.
  ItemConfiguration validate(Map<String, Object?> raw) {
    final errors = errorsIn(raw);
    if (errors.isNotEmpty) throw InvalidItemConfiguration(errors);

    return ItemConfiguration({
      for (final field in fields) field.key: ?_clean(raw[field.key]),
    });
  }

  /// Lança [InvalidQuantity] se o item não aceita [quantity].
  void checkQuantity(Quantity quantity) {
    if (quantity.value != 1 && !allowsQuantity) {
      throw const InvalidQuantity(
        'Este item não tem quantidade: é contratado uma vez só.',
      );
    }
  }

  static Object? _clean(Object? value) {
    if (value is! String) return value;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

const ConfigField _duration = ConfigField.integer(
  ItemConfiguration.durationKey,
  'Duração (horas)',
  min: 1,
  max: 24,
);

const ConfigField _requiredDuration = ConfigField.integer(
  ItemConfiguration.durationKey,
  'Duração (horas)',
  min: 1,
  max: 24,
  isRequired: true,
);

const ConfigField _notes = ConfigField.text(
  ItemConfiguration.notesKey,
  'Observações',
  maxLength: 500,
  isMultiline: true,
  // Vai para o fornecedor junto com o pedido: não é lugar de dado sensível.
  hint: 'O que o fornecedor precisa saber',
);

const ItemConfigurationSpec _ownServiceSpec = ItemConfigurationSpec(
  fields: [_notes],
);

const Map<PartyItemCategory, ItemConfigurationSpec> _categorySpecs = {
  PartyItemCategory.venue: ItemConfigurationSpec(
    fields: [
      _requiredDuration,
      ConfigField.text(
        'requirements',
        'Necessidades do evento',
        maxLength: 300,
        isMultiline: true,
        hint: 'Ex.: acessibilidade, palco, horário de montagem',
      ),
      _notes,
    ],
    requiresEventDetails: true,
  ),
  PartyItemCategory.buffet: ItemConfigurationSpec(
    fields: [
      ConfigField.choice('service_style', 'Tipo de serviço', [
        ConfigOption('plated', 'Empratado (servido à mesa)'),
        ConfigOption('self_service', 'Self-service'),
        ConfigOption('cocktail', 'Coquetel'),
        ConfigOption('barbecue', 'Churrasco'),
      ], isRequired: true),
      ConfigField.text(
        'menu',
        'Cardápio desejado',
        maxLength: 200,
        hint: 'Ex.: massas, sem frutos do mar',
      ),
      _duration,
      _notes,
    ],
  ),
  PartyItemCategory.kids: ItemConfigurationSpec(
    fields: [
      _requiredDuration,
      ConfigField.choice('age_range', 'Faixa etária', [
        ConfigOption('up_to_3', 'Até 3 anos'),
        ConfigOption('from_4_to_7', 'De 4 a 7 anos'),
        ConfigOption('from_8_to_12', 'De 8 a 12 anos'),
        ConfigOption('all_ages', 'Todas as idades'),
      ]),
      _notes,
    ],
    quantityLabel: 'Quantidade',
  ),
  PartyItemCategory.attraction: ItemConfigurationSpec(
    fields: [_requiredDuration, _notes],
  ),
  PartyItemCategory.decoration: ItemConfigurationSpec(
    fields: [
      ConfigField.text(
        'theme',
        'Tema',
        maxLength: 80,
        isRequired: true,
        hint: 'Ex.: Safari, tons de azul',
      ),
      ConfigField.choice('environment', 'Ambiente', [
        ConfigOption('indoor', 'Interno'),
        ConfigOption('outdoor', 'Externo'),
        ConfigOption('both', 'Interno e externo'),
      ]),
      ConfigField.text(
        'items',
        'Itens desejados',
        maxLength: 300,
        isMultiline: true,
        hint: 'Ex.: painel, arco de balões, centros de mesa',
      ),
      ConfigField.text(
        'customization',
        'Personalização',
        maxLength: 300,
        isMultiline: true,
        hint: 'Ex.: nome e idade no painel',
      ),
      _notes,
    ],
    quantityLabel: 'Quantidade (ambientes ou mesas)',
  ),
  PartyItemCategory.dj: ItemConfigurationSpec(
    fields: [_requiredDuration, _notes],
  ),
  PartyItemCategory.staff: ItemConfigurationSpec(
    fields: [_requiredDuration, _notes],
    quantityLabel: 'Número de profissionais',
  ),
  PartyItemCategory.security: ItemConfigurationSpec(
    fields: [_requiredDuration, _notes],
    quantityLabel: 'Número de seguranças',
  ),
  PartyItemCategory.beauty: ItemConfigurationSpec(
    fields: [_notes],
    quantityLabel: 'Número de pessoas atendidas',
  ),
  PartyItemCategory.other: ItemConfigurationSpec(
    fields: [
      ConfigField.text(
        'variation',
        'Variação',
        maxLength: 80,
        hint: 'Cor, tamanho, sabor...',
      ),
      _notes,
    ],
    quantityLabel: 'Quantidade',
  ),
};
