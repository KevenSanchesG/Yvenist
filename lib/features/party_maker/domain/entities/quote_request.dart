import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/rules/item_configuration_spec.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_configuration.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_relation.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/pricing.dart';

/// Um pedido de orçamento, como o fornecedor o vê: um item de uma festa cujo
/// orçamento foi solicitado.
///
/// Traz o que é preciso para dar o preço (o evento e a configuração do item) e
/// nada sobre quem pediu: nem o nome da festa, nem a conta.
class QuoteRequest {
  const QuoteRequest({
    required this.itemId,
    required this.partyId,
    required this.partyStatus,
    required this.round,
    required this.updatedAt,
    required this.name,
    required this.category,
    required this.pricing,
    required this.quantity,
    required this.configuration,
    required this.quote,
    this.relation = ItemRelationKind.independent,
    this.parentName,
    this.eventType,
    this.eventDate,
    this.guestCount,
    this.estimate,
  });

  final String itemId;

  /// Agrupa os itens do mesmo evento. Não dá acesso à festa.
  final String partyId;
  final PartyStatus partyStatus;
  final int round;
  final DateTime updatedAt;

  final String name;
  final PartyItemCategory category;
  final Pricing pricing;
  final int quantity;
  final ItemConfiguration configuration;
  final ItemRelationKind relation;

  /// O anúncio a que o item pertence, quando é um serviço próprio dele.
  final String? parentName;

  final String? eventType;
  final DateTime? eventDate;
  final int? guestCount;

  /// A estimativa que o cliente viu, calculada com o preço do anúncio.
  final Money? estimate;

  /// O que o fornecedor já respondeu.
  final ItemQuote quote;

  /// Falso quando o cliente já aceitou ou cancelou: a resposta não muda mais.
  bool get canRespond => partyStatus.acceptsVendorAnswers;

  /// Os campos que o cliente preencheu para este item.
  ItemConfigurationSpec get spec => ItemConfigurationSpec.of(
    category: category,
    pricingModel: pricing.model,
    isOwnService:
        relation == ItemRelationKind.linked ||
        relation == ItemRelationKind.required,
  );
}
