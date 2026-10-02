import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/theme/app_typography.dart';
import 'package:yvenist/core/utils/money_formatter.dart';
import 'package:yvenist/core/widgets/app_network_image.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/client/shared/listing_card.dart';

/// Anúncio em uma linha, para listas verticais (busca, explorar, favoritos).
class ListingTile extends StatelessWidget {
  const ListingTile({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppNetworkImage(url: listing.coverImageUrl, width: 96, height: 104),
          Expanded(
            child: Semantics(
              label: listingSemanticLabel(listing),
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.title,
                        style: AppTypography.cardTitle.copyWith(fontSize: 15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      LocationRow(listing: listing),
                      const SizedBox(height: 4),
                      RatingRow(listing: listing),
                      const SizedBox(height: 6),
                      Text(
                        'A partir de '
                        '${formatBrl(listing.priceFromCents, hideZeroCents: true)}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primaryStrong,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ListingActionButtons(listing: listing, direction: Axis.vertical),
        ],
      ),
    );
  }
}
