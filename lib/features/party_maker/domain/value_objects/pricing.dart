import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';

/// Como um item é cobrado, copiado do catálogo quando ele entra na festa.
///
/// A conta da estimativa é a mesma da API (`estimate_cents`, em
/// `backend/app/modules/catalog/pricing.py`): as duas têm de dar o mesmo
/// resultado para a mesma entrada.
class Pricing {
  const Pricing._(this.model, this.amount, this.minimum, this.currency);

  /// Sem valor, ou com o modelo sob consulta, o preço é "não publicado": o
  /// mínimo vai junto, para não sobrar um número sem sentido.
  factory Pricing({
    required PricingModel model,
    Money? amount,
    Money? minimum,
    String currency = 'BRL',
  }) {
    if (model == PricingModel.onRequest || amount == null) {
      return Pricing._(
        PricingModel.onRequest,
        null,
        null,
        amount?.currency ?? currency,
      );
    }
    return Pricing._(model, amount, minimum, amount.currency);
  }

  /// Um valor pelo serviço inteiro.
  factory Pricing.fixed(Money amount) =>
      Pricing(model: PricingModel.fixed, amount: amount);

  /// Sob consulta: o fornecedor não publica preço.
  const Pricing.onRequest({String currency = 'BRL'})
    : this._(PricingModel.onRequest, null, null, currency);

  final PricingModel model;

  /// O valor a que o modelo se refere. Nulo quando é sob consulta.
  final Money? amount;

  /// O menor valor cobrado, qualquer que seja a conta do modelo.
  final Money? minimum;
  final String currency;

  bool get isOnRequest => model == PricingModel.onRequest;

  /// A estimativa, ou `null` quando não dá para estimar: o preço é sob
  /// consulta, ou falta a medida de que o modelo depende ([guests], para "por
  /// pessoa"; [hours], para "por hora"). Nunca se inventa um valor no lugar do
  /// que falta.
  Money? estimate({
    required int? guests,
    required int? hours,
    required int quantity,
  }) {
    final amount = this.amount;
    if (amount == null) return null;

    final Money total;
    switch (model) {
      case PricingModel.fixed:
        total = amount;
      case PricingModel.perUnit:
        total = amount.multiplyInt(quantity);
      case PricingModel.perPerson:
        if (guests == null) return null;
        total = amount.multiplyInt(guests * quantity);
      case PricingModel.perHour:
        if (hours == null) return null;
        total = amount.multiplyInt(hours * quantity);
      case PricingModel.onRequest:
        return null;
    }

    final minimum = this.minimum;
    return minimum != null && total.compareTo(minimum) < 0 ? minimum : total;
  }

  @override
  bool operator ==(Object other) =>
      other is Pricing &&
      other.model == model &&
      other.amount == amount &&
      other.minimum == minimum &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(model, amount, minimum, currency);

  @override
  String toString() => 'Pricing(${model.apiValue}, $amount, mínimo $minimum)';
}
