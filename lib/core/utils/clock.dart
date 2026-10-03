/// De onde vem "agora". As regras que dependem do tempo (uma data que precisa
/// ser no futuro) recebem um relógio em vez de ler o do aparelho: um teste
/// passa um relógio parado.
typedef Clock = DateTime Function();

/// O relógio do aparelho.
DateTime systemClock() => DateTime.now();
