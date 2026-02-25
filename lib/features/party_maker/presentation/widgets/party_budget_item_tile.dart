import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../models/party_budget_item_view.dart';

class PartyBudgetItemTile extends StatelessWidget {
  final PartyBudgetItemView item;
  final VoidCallback onRemove;
  final bool isBusy;

  const PartyBudgetItemTile({
    super.key,
    required this.item,
    required this.onRemove,
    required this.isBusy,
  });

  bool _isNetworkImage(String path) {
    final p = path.trim();
    return p.startsWith('http://') || p.startsWith('https://');
  }

  Widget _fallbackBox({IconData icon = Icons.storefront}) {
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey.shade100,
      child: Icon(
        icon,
        color: Colors.grey.shade500,
      ),
    );
  }

  Widget _buildImage(String? path) {
    if (path == null || path.trim().isEmpty) {
      return _fallbackBox(icon: Icons.storefront);
    }

    final normalized = path.trim();

    if (_isNetworkImage(normalized)) {
      return Image.network(
        normalized,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackBox(icon: Icons.broken_image),
      );
    }

    // Se não for URL, tratamos como assetPath
    return Image.asset(
      normalized,
      width: 60,
      height: 60,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallbackBox(icon: Icons.broken_image),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildImage(item.imageUrl),
        ),
        title: Text(
          item.name,
          style: AppTypography.cardTitle.copyWith(fontSize: 14),
        ),
        subtitle: Text(
          "R\$ ${item.unitPrice.toStringAsFixed(2)}  •  qtd ${item.quantity}",
          style: AppTypography.cardPrice.copyWith(
            color: AppColors.primary,
            fontSize: 12,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
          onPressed: isBusy ? null : onRemove,
        ),
      ),
    );
  }
}
