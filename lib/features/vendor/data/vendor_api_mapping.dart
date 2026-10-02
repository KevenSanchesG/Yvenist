import 'package:yvenist/features/vendor/domain/vendor_models.dart';

/// Como a API escreve os valores dos enums de fornecedor.

const Map<String, VendorStatus> _vendorStatuses = {
  'pending_review': VendorStatus.pendingReview,
  'approved': VendorStatus.approved,
  'rejected': VendorStatus.rejected,
};

/// Um status que o app ainda não conhece é tratado como "em análise": não
/// libera nada indevidamente.
VendorStatus vendorStatusFromApi(Object? value) {
  return _vendorStatuses[value] ?? VendorStatus.pendingReview;
}

const Map<PersonType, String> personTypeToApi = {
  PersonType.individual: 'pf',
  PersonType.company: 'pj',
};

PersonType personTypeFromApi(Object? value) {
  return value == 'pj' ? PersonType.company : PersonType.individual;
}

CancellationPolicy cancellationPolicyFromApi(Object? value) {
  return value == 'moderate'
      ? CancellationPolicy.moderate
      : CancellationPolicy.flexible;
}
