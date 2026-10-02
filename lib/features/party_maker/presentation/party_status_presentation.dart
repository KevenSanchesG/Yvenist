import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_palette.dart';
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

  /// A cor do status no tema em uso.
  Color colorIn(AppPalette colors) => switch (this) {
    PartyStatus.draft || PartyStatus.planning => colors.textSecondary,
    PartyStatus.locked => colors.primary,
    PartyStatus.paid => colors.success,
    PartyStatus.cancelled => colors.danger,
  };
}
