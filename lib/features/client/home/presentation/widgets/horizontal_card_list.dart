import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import 'content_card.dart';

class HorizontalCardList extends StatelessWidget {
  final List<ContentCard> cards;
  const HorizontalCardList({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280, 
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sectionHorizontalPadding),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              right: index == cards.length - 1 ? 0 : AppSpacing.cardSpacing,
              bottom: 16, 
            ),
            child: cards[index],
          );
        },
      ),
    );
  }
}