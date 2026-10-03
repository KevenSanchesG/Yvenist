/// Em que ponto do caminho a festa está. Na API os valores são os de
/// [apiValue] (`PartyStatus`, em `backend/app/modules/parties/domain.py`).
enum PartyStatus {
  draft('draft'),
  planning('planning'),

  /// Orçamento solicitado: esperando os fornecedores.
  locked('locked'),

  /// Orçamento recebido: todos os itens têm o valor do fornecedor.
  quoted('quoted'),

  /// Edição solicitada: um fornecedor pediu uma alteração ou não pode atender.
  editRequested('edit_requested'),

  /// A pessoa aceitou o orçamento recebido.
  confirmed('confirmed'),

  /// Só o servidor chega aqui, e ainda não há fluxo de pagamento.
  paid('paid'),
  cancelled('cancelled');

  const PartyStatus(this.apiValue);

  final String apiValue;

  /// A pessoa ainda está montando: título, evento e itens podem mudar.
  bool get isEditable => this == draft || this == planning;

  /// O orçamento foi pedido: o conteúdo fica congelado, e é esse conteúdo que
  /// os fornecedores veem.
  bool get isSubmitted =>
      this == locked ||
      this == quoted ||
      this == editRequested ||
      this == confirmed;

  /// Enquanto a pessoa não aceita, o fornecedor pode responder ou corrigir a
  /// resposta.
  bool get acceptsVendorAnswers =>
      this == locked || this == quoted || this == editRequested;

  static PartyStatus fromApi(Object? value) {
    for (final status in values) {
      if (status.apiValue == value) return status;
    }
    throw FormatException('Status de festa desconhecido: $value');
  }
}
