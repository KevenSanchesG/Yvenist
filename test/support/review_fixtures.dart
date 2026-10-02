import 'dart:async';

import 'package:yvenist/app/app_dependencies.dart';
import 'package:yvenist/features/admin/data/in_memory_review_repository.dart';
import 'package:yvenist/features/admin/domain/review_models.dart';
import 'package:yvenist/features/admin/domain/review_repository.dart';
import 'package:yvenist/features/auth/data/in_memory_auth_repository.dart';
import 'package:yvenist/features/auth/domain/entities/app_user.dart';
import 'package:yvenist/features/vendor/domain/vendor_models.dart';

import 'app_harness.dart';

VendorReview buildVendorReview({
  String id = 'vendor-1',
  String legalName = 'Maria Oliveira',
  PersonType personType = PersonType.individual,
  String document = '52998224725',
}) {
  return VendorReview(
    id: id,
    legalName: legalName,
    personType: personType,
    document: document,
    createdAt: DateTime.utc(2026, 10, 1, 15),
  );
}

ListingReview buildListingReview({
  String id = 'listing-1',
  String title = 'Espaço Crystal',
  String vendorId = 'vendor-1',
  String vendorName = 'Maria Oliveira',
  VendorStatus vendorStatus = VendorStatus.pendingReview,
  String categorySlug = 'venue',
}) {
  return ListingReview(
    id: id,
    title: title,
    categorySlug: categorySlug,
    description: 'Salão amplo, climatizado, com cozinha equipada.',
    neighborhood: 'Campo Grande',
    city: 'Rio de Janeiro',
    state: 'RJ',
    priceFromCents: 250000,
    capacity: 150,
    areaM2: 300,
    amenities: const ['kitchen', 'wifi'],
    eventTypes: const ['wedding', 'debutante'],
    cancellationPolicy: CancellationPolicy.moderate,
    createdAt: DateTime.utc(2026, 10, 1, 15),
    vendorId: vendorId,
    vendorName: vendorName,
    vendorStatus: vendorStatus,
  );
}

/// Uma fila com um cadastro em análise e o anúncio que veio com ele, mais um
/// anúncio novo de um fornecedor que já foi aprovado.
InMemoryReviewRepository sampleReviewQueue() {
  return InMemoryReviewRepository(
    vendors: [buildVendorReview()],
    listings: [
      buildListingReview(),
      buildListingReview(
        id: 'listing-2',
        title: 'Buffet da Ana',
        categorySlug: 'buffet',
        vendorId: 'vendor-2',
        vendorName: 'Ana Souza',
        vendorStatus: VendorStatus.approved,
      ),
    ],
  );
}

/// Autenticação em memória cuja conta é de administração.
class AdminAuth extends InMemoryAuthRepository {
  static const AppUser admin = AppUser(
    id: 'admin-1',
    email: 'admin@example.com',
    fullName: 'Ana Administradora',
    isAdmin: true,
  );

  @override
  Future<AppUser?> restoreSession() async => admin;
}

/// O app em modo demonstração com uma conta de administração e a fila dada.
AppDependencies adminDependencies(ReviewRepository reviews) {
  return demoDependencies(auth: AdminAuth(), reviews: reviews);
}

/// Fila de análise que pode ser mandada falhar ou segurar a resposta, para
/// exercitar os estados de erro e de espera.
class ControllableReviews implements ReviewRepository {
  ControllableReviews([InMemoryReviewRepository? inner])
    : _inner = inner ?? InMemoryReviewRepository();

  final InMemoryReviewRepository _inner;

  /// Se definido, a consulta da fila falha com este erro.
  Object? loadFailure;

  /// Se definido, toda decisão falha com este erro.
  Object? decisionFailure;

  /// Enquanto não for completado, as decisões ficam esperando.
  Completer<void>? gate;

  int loads = 0;

  Future<void> _beforeDeciding() async {
    await gate?.future;
    final error = decisionFailure;
    if (error != null) Error.throwWithStackTrace(error, StackTrace.current);
  }

  @override
  Future<ReviewQueue> pending() async {
    loads++;
    final error = loadFailure;
    if (error != null) Error.throwWithStackTrace(error, StackTrace.current);
    return _inner.pending();
  }

  @override
  Future<void> approveVendor(
    String vendorId, {
    required bool publishListings,
  }) async {
    await _beforeDeciding();
    return _inner.approveVendor(vendorId, publishListings: publishListings);
  }

  @override
  Future<void> rejectVendor(String vendorId, {required String reason}) async {
    await _beforeDeciding();
    return _inner.rejectVendor(vendorId, reason: reason);
  }

  @override
  Future<void> approveListing(String listingId) async {
    await _beforeDeciding();
    return _inner.approveListing(listingId);
  }

  @override
  Future<void> rejectListing(String listingId, {required String reason}) async {
    await _beforeDeciding();
    return _inner.rejectListing(listingId, reason: reason);
  }
}
