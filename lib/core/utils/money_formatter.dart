import 'package:intl/intl.dart';
import 'package:yvenist/core/pricing/pricing_model.dart';

final NumberFormat _withCents = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: r'R$',
  decimalDigits: 2,
);
final NumberFormat _wholeReais = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: r'R$',
  decimalDigits: 0,
);

final RegExp _currencyNoise = RegExp(r'[R$\s]');
final RegExp _dotAsDecimal = RegExp(r'^\d+\.\d{1,2}$');
final RegExp _reaisWithOptionalCents = RegExp(r'^\d+(,\d{1,2})?$');

/// Formata centavos como moeda brasileira: `123456` -> `R$ 1.234,56`.
///
/// Com [hideZeroCents], valores redondos saem sem a parte decimal
/// (`100000` -> `R$ 1.000`), o que cabe melhor nos cards.
String formatBrl(int cents, {bool hideZeroCents = false}) {
  final format = hideZeroCents && cents % 100 == 0 ? _wholeReais : _withCents;
  // O padrão pt_BR usa espaço inseparável entre o símbolo e o número; trocamos
  // por espaço comum para o texto se comportar igual em buscas e testes.
  return format.format(cents / 100).replaceAll(' ', ' ');
}

/// O texto que aparece no lugar de um valor que o fornecedor não publicou.
const String onRequestLabel = 'Sob consulta';

/// Um preço como a pessoa lê: `R$ 60 por pessoa`, `R$ 1.700`, `Sob consulta`.
///
/// Sem valor ([cents] nulo) ou com o modelo sob consulta, nunca sai um número:
/// um preço que não existe não pode aparecer como `R$ 0`.
String describePricing(PricingModel model, int? cents) {
  if (cents == null || model == PricingModel.onRequest) return onRequestLabel;

  final price = formatBrl(cents, hideZeroCents: true);
  return switch (model) {
    PricingModel.fixed => price,
    PricingModel.perPerson => '$price por pessoa',
    PricingModel.perHour => '$price por hora',
    PricingModel.perUnit => '$price por unidade',
    PricingModel.onRequest => onRequestLabel,
  };
}

/// Converte o que o usuário digitou em reais para centavos.
///
/// Aceita `1500`, `1.500`, `1500,5`, `R$ 1.500,50` e também `1500.50` (teclados
/// numéricos que só têm ponto). Devolve `null` se não for um valor válido.
int? parseBrlToCents(String input) {
  var text = input.replaceAll(_currencyNoise, '');
  if (text.isEmpty) return null;

  // Sem vírgula, um único ponto seguido de 1 ou 2 dígitos é separador decimal
  // ("1500.50"); com 3 dígitos é separador de milhar ("1.500").
  if (!text.contains(',') && _dotAsDecimal.hasMatch(text)) {
    text = text.replaceFirst('.', ',');
  }
  text = text.replaceAll('.', '');
  if (!_reaisWithOptionalCents.hasMatch(text)) return null;

  final parts = text.split(',');
  final reais = int.parse(parts[0]);
  final cents = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
  return reais * 100 + cents;
}
