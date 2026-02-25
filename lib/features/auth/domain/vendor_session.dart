// lib/core/services/vendor_session.dart

import 'package:flutter/material.dart';

enum VendorStatus {
  none,       // Apenas cliente
  review,     // Enviou anúncio, aguardando aprovação
  approved,   // Fornecedor ativo
  rejected    // Recusado
}

class VendorSession extends ChangeNotifier {
  // Singleton
  static final VendorSession _instance = VendorSession._internal();
  factory VendorSession() => _instance;
  VendorSession._internal();

  VendorStatus _status = VendorStatus.none;

  VendorStatus get status => _status;
  bool get isVendor => _status == VendorStatus.approved;
  bool get isUnderReview => _status == VendorStatus.review;

  // Simula o envio do formulário
  void submitAdForReview() {
    _status = VendorStatus.review;
    notifyListeners();
  }

  // Simula a aprovação do admin (para teste)
  void approveVendor() {
    _status = VendorStatus.approved;
    notifyListeners();
  }
}