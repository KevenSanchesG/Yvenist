import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';

class CancellationResult {
  final Money totalAtCancellation;
  final Money refundAmount; // MVP: 0
  final Money penaltyAmount; // MVP: 0

  const CancellationResult({
    required this.totalAtCancellation,
    required this.refundAmount,
    required this.penaltyAmount,
  });

  bool get hasRefund => refundAmount.cents > 0;

  @override
  String toString() =>
      'CancellationResult(total=$totalAtCancellation, refund=$refundAmount, penalty=$penaltyAmount)';
}
