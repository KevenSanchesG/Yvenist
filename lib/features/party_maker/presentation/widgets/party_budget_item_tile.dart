import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/utils/money_formatter.dart';
import 'package:yvenist/core/widgets/app_network_image.dart';
import 'package:yvenist/features/party_maker/presentation/models/party_budget_item_view.dart';

class PartyBudgetItemTile extends StatelessWidget {
  const PartyBudgetItemTile({
    super.key,
    required this.item,
    required this.onRemove,
  });

  final PartyBudgetItemView item;

  /// `null` desabilita a remoção (festa travada ou operação em andamento).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AppNetworkImage(
            url: item.imageUrl,
            width: 60,
            height: 60,
            fallbackIcon: Icons.storefront,
          ),
        ),
        title: Text(
          item.name,
          style: text.cardTitle.copyWith(fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${formatBrl(item.unitPriceCents)}  •  qtd ${item.quantity}',
          style: text.caption.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          color: colors.danger,
          tooltip: 'Remover ${item.name}',
          onPressed: onRemove,
        ),
      ),
    );
  }
}
