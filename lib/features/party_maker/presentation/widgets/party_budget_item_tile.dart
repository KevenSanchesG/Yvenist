import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/theme/app_typography.dart';
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
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
          style: AppTypography.cardTitle.copyWith(fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${formatBrl(item.unitPriceCents)}  •  qtd ${item.quantity}',
          style: AppTypography.caption.copyWith(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          color: AppColors.danger,
          tooltip: 'Remover ${item.name}',
          onPressed: onRemove,
        ),
      ),
    );
  }
}
