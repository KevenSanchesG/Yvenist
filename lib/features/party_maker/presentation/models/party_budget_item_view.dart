class PartyBudgetItemView {
  final String id;
  final String name;
  final int unitPriceCents;
  final int quantity;
  final String? imageUrl;
  final String? category;

  const PartyBudgetItemView({
    required this.id,
    required this.name,
    required this.unitPriceCents,
    required this.quantity,
    this.imageUrl,
    this.category,
  });

  double get unitPrice => unitPriceCents / 100.0;
  double get subtotal => (unitPriceCents * quantity) / 100.0;
}
