import '../enums/party_item_category.dart';
import '../value_objects/external_ref.dart';
import '../value_objects/money.dart';
import '../value_objects/party_id.dart';
import '../value_objects/quantity.dart';

class SnapshotLineItem {
  final ExternalRef externalRef;
  final PartyItemCategory category;
  final String nameSnapshot;
  final Money unitPriceSnapshot;
  final Quantity quantity;
  final Money subtotal;

  const SnapshotLineItem({
    required this.externalRef,
    required this.category,
    required this.nameSnapshot,
    required this.unitPriceSnapshot,
    required this.quantity,
    required this.subtotal,
  });
}

class PartyPaymentSnapshot {
  final PartyId partyId;
  final DateTime generatedAt;
  final DateTime? expiresAt;
  final Money totalAmount;
  final List<SnapshotLineItem> breakdown;

  PartyPaymentSnapshot({
    required this.partyId,
    required this.generatedAt,
    required this.totalAmount,
    required List<SnapshotLineItem> breakdown,
    this.expiresAt,
  }) : breakdown = List.unmodifiable(breakdown);
}
