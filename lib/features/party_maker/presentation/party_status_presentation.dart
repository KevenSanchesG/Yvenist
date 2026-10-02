import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';

/// Como cada status da festa aparece para o usuário.
extension PartyStatusPresentation on PartyStatus {
  String get label => switch (this) {
        PartyStatus.draft => 'Rascunho',
        PartyStatus.planning => 'Em planejamento',
        PartyStatus.locked => 'Orçamento solicitado',
        PartyStatus.paid => 'Pago',
        PartyStatus.cancelled => 'Cancelado',
      };

  Color get color => switch (this) {
        PartyStatus.draft || PartyStatus.planning => AppColors.textSecondary,
        PartyStatus.locked => AppColors.primaryStrong,
        PartyStatus.paid => AppColors.success,
        PartyStatus.cancelled => AppColors.danger,
      };
}
