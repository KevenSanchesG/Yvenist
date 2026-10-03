/// A que um preço se refere.
///
/// É o mesmo vocabulário no catálogo (como um anúncio cobra) e no Party Maker
/// (como um item da festa é estimado), por isso fica aqui, e não em uma das
/// duas funcionalidades. Na API os valores são os de [apiValue].
enum PricingModel {
  /// Um valor pelo serviço inteiro: não muda com convidados, horas ou
  /// quantidade.
  fixed('fixed'),
  perPerson('per_person'),
  perHour('per_hour'),
  perUnit('per_unit'),

  /// Sob consulta: o fornecedor não publica preço. Não há o que estimar.
  onRequest('on_request');

  const PricingModel(this.apiValue);

  final String apiValue;

  /// O modelo que a API escreve como [value].
  ///
  /// Um valor que o app ainda não conhece vira [onRequest]: sem saber como o
  /// preço é cobrado, mostrar "sob consulta" é melhor do que estimar errado.
  static PricingModel fromApi(Object? value) {
    for (final model in values) {
      if (model.apiValue == value) return model;
    }
    return onRequest;
  }
}
