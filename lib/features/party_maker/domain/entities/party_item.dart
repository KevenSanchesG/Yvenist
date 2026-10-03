import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/rules/item_configuration_spec.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_configuration.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_relation.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/pricing.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';

/// Um elemento da festa: um anúncio, ou um serviço próprio de um anúncio, do
/// jeito que a pessoa o configurou.
///
/// Tem três partes que não se misturam:
/// - a cópia do catálogo no momento em que entrou (nome, categoria, preço,
///   capacidade): não muda depois;
/// - o que a pessoa informou ([quantity], [configuration]);
/// - o que o fornecedor respondeu ([quote]).
class PartyItem {
  const PartyItem({
    required this.id,
    required this.externalRef,
    required this.category,
    required this.nameSnapshot,
    required this.pricing,
    required this.quantity,
    this.configuration = ItemConfiguration.empty,
    this.relation = const ItemRelation.independent(),
    this.quote = const ItemQuote.none(),
    this.imageUrlSnapshot,
    this.capacity,
    this.vendorId,
  });

  final PartyItemId id; // interno (do agregado)
  final ExternalRef externalRef; // de onde o item veio
  final PartyItemCategory category;
  final String nameSnapshot;

  /// Como o item é cobrado, copiado do catálogo quando ele entrou.
  final Pricing pricing;
  final Quantity quantity;

  /// O que a pessoa informou ao configurar o item.
  final ItemConfiguration configuration;

  /// O que este item é em relação a outro da mesma festa.
  final ItemRelation relation;

  /// A resposta do fornecedor. Não se confunde com a [estimate]: uma é o valor
  /// que ele informou, a outra é a conta que o app fez com o preço do anúncio.
  final ItemQuote quote;

  /// Capa do anúncio no momento em que o item entrou, como o nome: serve para
  /// a pessoa reconhecer o item mesmo que o anúncio mude ou saia do catálogo.
  final String? imageUrlSnapshot;

  /// Quantas pessoas o espaço comporta, quando o anúncio informa.
  final int? capacity;

  /// Itens do mesmo fornecedor têm o mesmo valor aqui. Não identifica ninguém.
  final String? vendorId;

  /// O que este item pede, pela categoria e pela forma de cobrança.
  ItemConfigurationSpec get spec => ItemConfigurationSpec.of(
    category: category,
    pricingModel: pricing.model,
    isOwnService: relation.isOwnService,
  );

  /// A estimativa deste item para uma festa com [guests] convidados, ou `null`
  /// quando não dá para estimar (sob consulta, ou falta uma medida).
  Money? estimate({required int? guests}) {
    return pricing.estimate(
      guests: guests,
      hours: configuration.durationHours,
      quantity: quantity.value,
    );
  }

  PartyItem copyWith({
    Quantity? quantity,
    ItemConfiguration? configuration,
    ItemRelation? relation,
    ItemQuote? quote,
  }) {
    return PartyItem(
      id: id,
      externalRef: externalRef,
      category: category,
      nameSnapshot: nameSnapshot,
      pricing: pricing,
      quantity: quantity ?? this.quantity,
      configuration: configuration ?? this.configuration,
      relation: relation ?? this.relation,
      quote: quote ?? this.quote,
      imageUrlSnapshot: imageUrlSnapshot,
      capacity: capacity,
      vendorId: vendorId,
    );
  }
}
