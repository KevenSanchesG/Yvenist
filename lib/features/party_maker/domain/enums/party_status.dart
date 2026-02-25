enum PartyStatus {
  draft,
  planning,
  locked,     // congelada para pagamento (snapshot gerado)
  paid,       // pagamento confirmado (stub no MVP)
  cancelled,
}
