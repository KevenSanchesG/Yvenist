import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/core/theme/app_palette.dart';
import 'package:yvenist/core/utils/money_formatter.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_budget.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_history_entry.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_item.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/rules/item_configuration_spec.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_configuration.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_relation.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/pricing.dart';

/// Como os conceitos do Party Maker aparecem para a pessoa: textos, ícones e
/// cores. Nenhuma regra mora aqui: tudo o que se decide vem do domínio.

final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
final DateFormat _timeFormat = DateFormat('HH:mm');

/// O dia como a pessoa lê: `25/12/2026`.
String formatDay(DateTime date) => _dateFormat.format(date.toLocal());

/// A hora como a pessoa lê: `19:00`.
String formatTime(DateTime date) => _timeFormat.format(date.toLocal());

/// O dia e a hora da festa: `25/12/2026 às 19:00`.
String formatEventDate(DateTime date) {
  return '${formatDay(date)} às ${formatTime(date)}';
}

/// "1 convidado", "80 convidados".
String guestsLabel(int guests) {
  return guests == 1 ? '1 convidado' : '$guests convidados';
}

/// "1 item", "3 itens".
String itemsLabel(int count) => count == 1 ? '1 item' : '$count itens';

// ---------------------------------------------------------------
// Status
// ---------------------------------------------------------------

extension PartyStatusPresentation on PartyStatus {
  String get label => switch (this) {
    PartyStatus.draft => 'Rascunho',
    PartyStatus.planning => 'Em planejamento',
    PartyStatus.locked => 'Orçamento solicitado',
    PartyStatus.quoted => 'Orçamento recebido',
    PartyStatus.editRequested => 'Edição solicitada',
    PartyStatus.confirmed => 'Orçamento aceito',
    PartyStatus.paid => 'Pago',
    PartyStatus.cancelled => 'Cancelado',
  };

  IconData get icon => switch (this) {
    PartyStatus.draft || PartyStatus.planning => Icons.edit_note,
    PartyStatus.locked => Icons.hourglass_top,
    PartyStatus.quoted => Icons.request_quote_outlined,
    PartyStatus.editRequested => Icons.feedback_outlined,
    PartyStatus.confirmed || PartyStatus.paid => Icons.check_circle_outline,
    PartyStatus.cancelled => Icons.cancel_outlined,
  };

  /// A cor do status no tema em uso.
  Color colorIn(AppPalette colors) => switch (this) {
    PartyStatus.draft || PartyStatus.planning => colors.textSecondary,
    PartyStatus.locked => colors.primary,
    PartyStatus.editRequested => colors.warning,
    PartyStatus.quoted ||
    PartyStatus.confirmed ||
    PartyStatus.paid => colors.success,
    PartyStatus.cancelled => colors.danger,
  };
}

/// O que está acontecendo com a festa e o que vem a seguir, em uma frase.
/// É o que responde "onde estou e qual é o próximo passo".
String nextStepFor(Party party) {
  final items = party.budget.items;
  switch (party.status) {
    case PartyStatus.draft || PartyStatus.planning:
      if (items.isEmpty) {
        return 'Escolha os espaços e serviços da festa para ver quanto ela '
            'custa.';
      }
      if (party.itemsNeedingAttention.isNotEmpty) {
        return 'Ajuste os itens marcados e solicite o orçamento de novo.';
      }
      if (party.quoteBlockers.isNotEmpty) {
        return 'Falta pouco para pedir o orçamento. Veja o que falta abaixo.';
      }
      return 'Tudo pronto. Ao solicitar, cada fornecedor recebe o pedido do '
          'item dele e responde com o valor.';
    case PartyStatus.locked:
      final answered = items.where((item) => item.quote.isQuoted).length;
      return answered == 0
          ? 'Os fornecedores receberam o pedido. Você acompanha as respostas '
                'aqui.'
          : '$answered de ${items.length} itens já têm o valor do fornecedor.';
    case PartyStatus.quoted:
      return 'Todos os fornecedores responderam. Confira os valores e aceite, '
          'ou edite a festa para pedir de novo.';
    case PartyStatus.editRequested:
      return 'Um fornecedor devolveu um item. Veja o recado, toque em "Editar '
          'festa", ajuste e solicite de novo.';
    case PartyStatus.confirmed:
      return 'Você aceitou este orçamento. O pagamento é combinado direto com '
          'cada fornecedor.';
    case PartyStatus.paid:
      return 'Esta festa está paga.';
    case PartyStatus.cancelled:
      return 'Esta festa foi cancelada e não pode mais ser alterada.';
  }
}

// ---------------------------------------------------------------
// Categorias
// ---------------------------------------------------------------

extension PartyItemCategoryPresentation on PartyItemCategory {
  /// O nome do grupo em que os itens da categoria aparecem na festa.
  String get groupLabel => switch (this) {
    PartyItemCategory.venue => 'Espaço',
    PartyItemCategory.buffet => 'Buffet e bar',
    PartyItemCategory.attraction => 'Atrações',
    PartyItemCategory.kids => 'Brinquedos',
    PartyItemCategory.decoration => 'Decoração',
    PartyItemCategory.dj => 'DJ e som',
    PartyItemCategory.staff => 'Equipe',
    PartyItemCategory.security => 'Segurança',
    PartyItemCategory.beauty => 'Beleza',
    PartyItemCategory.other => 'Produtos e outros',
  };

  IconData get icon => switch (this) {
    PartyItemCategory.venue => Icons.table_restaurant,
    PartyItemCategory.buffet => Icons.flatware,
    PartyItemCategory.attraction => Icons.music_note,
    PartyItemCategory.kids => Icons.castle,
    PartyItemCategory.decoration => Icons.local_florist,
    PartyItemCategory.dj => Icons.headphones,
    PartyItemCategory.staff => Icons.groups,
    PartyItemCategory.security => Icons.shield_outlined,
    PartyItemCategory.beauty => Icons.brush,
    PartyItemCategory.other => Icons.shopping_bag_outlined,
  };
}

/// A ordem em que os grupos aparecem na festa: primeiro o lugar, depois o que
/// acontece nele.
const List<PartyItemCategory> partyCategoryOrder = [
  PartyItemCategory.venue,
  PartyItemCategory.buffet,
  PartyItemCategory.attraction,
  PartyItemCategory.kids,
  PartyItemCategory.decoration,
  PartyItemCategory.dj,
  PartyItemCategory.staff,
  PartyItemCategory.security,
  PartyItemCategory.beauty,
  PartyItemCategory.other,
];

// ---------------------------------------------------------------
// Valores
// ---------------------------------------------------------------

/// Como um item cobra: `R$ 55 por pessoa`, `R$ 1.700`, `Sob consulta`.
String pricingLabel(Pricing pricing) {
  return describePricing(pricing.model, pricing.amount?.cents);
}

/// A conta por trás de uma estimativa (`R$ 55 por pessoa`), para aparecer ao
/// lado dela. Nulo quando não acrescenta nada: o valor fixo já é a própria
/// estimativa, e sob consulta não há conta.
String? pricingBasis(Pricing pricing) {
  return switch (pricing.model) {
    PricingModel.fixed || PricingModel.onRequest => null,
    PricingModel.perPerson ||
    PricingModel.perHour ||
    PricingModel.perUnit => pricingLabel(pricing),
  };
}

/// Um valor em dinheiro, ou "Sob consulta" quando ele não existe. Nunca um
/// número no lugar do que não se sabe.
String amountLabel(Money? amount) {
  return amount == null ? onRequestLabel : formatBrl(amount.cents);
}

/// A estimativa da festa em uma linha: `R$ 2.850,00`, `R$ 2.850,00 + 1 sob
/// consulta`, ou só `Sob consulta` quando nada tem preço.
String estimateSummary(BudgetEstimate estimate, {required int itemCount}) {
  if (itemCount == 0) return formatBrl(0);
  final unpriced = estimate.unpricedItems;
  if (unpriced == 0) return formatBrl(estimate.total.cents);
  if (unpriced == itemCount) return onRequestLabel;
  return '${formatBrl(estimate.total.cents)} + $unpriced sob consulta';
}

// ---------------------------------------------------------------
// Itens
// ---------------------------------------------------------------

/// O que o item é em relação a outro item da festa, ou `null` se ele foi
/// escolhido por conta própria.
String? relationCaption(PartyItem item, PartyBudget budget) {
  final parentId = item.relation.parentId;
  final parent = parentId == null ? null : budget.findById(parentId);
  if (parent == null) return null;

  final name = parent.nameSnapshot;
  return switch (item.relation.kind) {
    ItemRelationKind.independent => null,
    ItemRelationKind.linked => 'Serviço de $name',
    ItemRelationKind.required => 'Obrigatório com $name',
    ItemRelationKind.recommended => 'Recomendado por $name',
  };
}

/// A configuração de um item em pedaços curtos: "4 horas", "Tema: Safari".
/// As observações ficam de fora: são texto livre, e têm lugar próprio.
List<String> configurationSummary({
  required ItemConfigurationSpec spec,
  required ItemConfiguration configuration,
  required int quantity,
}) {
  return [
    if (spec.allowsQuantity && quantity > 1) 'Quantidade: $quantity',
    for (final field in spec.fields)
      if (field.key != ItemConfiguration.notesKey)
        if (configuration[field.key] case final value?)
          _describeField(field, value),
  ];
}

String _describeField(ConfigField field, Object value) {
  if (field.key == ItemConfiguration.durationKey) {
    return value == 1 ? '1 hora' : '$value horas';
  }
  return switch (field.kind) {
    ConfigFieldKind.choice => field.optionLabel('$value'),
    ConfigFieldKind.integer || ConfigFieldKind.text => '${field.label}: $value',
  };
}

// ---------------------------------------------------------------
// Orçamento
// ---------------------------------------------------------------

extension QuoteStatusPresentation on QuoteStatus {
  /// Em que pé está a resposta do fornecedor, ou `null` enquanto o orçamento
  /// do item não foi pedido.
  String? get label => switch (this) {
    QuoteStatus.none => null,
    QuoteStatus.pending => 'Aguardando o fornecedor',
    QuoteStatus.quoted => 'Orçamento recebido',
    QuoteStatus.changesRequested => 'O fornecedor pediu uma alteração',
    QuoteStatus.declined => 'O fornecedor não pode atender',
  };

  Color colorIn(AppPalette colors) => switch (this) {
    QuoteStatus.none || QuoteStatus.pending => colors.textSecondary,
    QuoteStatus.quoted => colors.success,
    QuoteStatus.changesRequested => colors.warning,
    QuoteStatus.declined => colors.danger,
  };
}

// ---------------------------------------------------------------
// Histórico
// ---------------------------------------------------------------

/// Um acontecimento do histórico em uma frase.
String describeHistoryEntry(PartyHistoryEntry entry) {
  final item = entry.itemName ?? 'Um item';
  final amount = entry.amount;
  return switch (entry.kind) {
    PartyHistoryKind.quoteRequested =>
      entry.round > 1
          ? 'Você reenviou a festa com as alterações (${entry.round}ª rodada)'
          : 'Você solicitou o orçamento',
    PartyHistoryKind.reopened => 'Você voltou a editar a festa',
    PartyHistoryKind.vendorQuoted =>
      '$item: o fornecedor informou ${amountLabel(amount)}',
    PartyHistoryKind.vendorRequestedChanges =>
      '$item: o fornecedor pediu uma alteração',
    PartyHistoryKind.vendorDeclined => '$item: o fornecedor não pode atender',
    PartyHistoryKind.confirmed => 'Você aceitou o orçamento',
    PartyHistoryKind.cancelled => 'Você cancelou a festa',
  };
}

/// O valor que acompanha um acontecimento, quando ele diz algo além da frase:
/// a estimativa do pedido, ou o total aceito.
String? historyAmountCaption(PartyHistoryEntry entry) {
  final amount = entry.amount;
  if (amount == null) return null;
  return switch (entry.kind) {
    PartyHistoryKind.quoteRequested => 'Estimativa: ${formatBrl(amount.cents)}',
    PartyHistoryKind.confirmed => 'Total: ${formatBrl(amount.cents)}',
    _ => null,
  };
}

extension PartyHistoryKindPresentation on PartyHistoryKind {
  IconData get icon => switch (this) {
    PartyHistoryKind.quoteRequested => Icons.send_outlined,
    PartyHistoryKind.reopened => Icons.edit_outlined,
    PartyHistoryKind.vendorQuoted => Icons.request_quote_outlined,
    PartyHistoryKind.vendorRequestedChanges => Icons.feedback_outlined,
    PartyHistoryKind.vendorDeclined => Icons.block,
    PartyHistoryKind.confirmed => Icons.check_circle_outline,
    PartyHistoryKind.cancelled => Icons.cancel_outlined,
  };
}
