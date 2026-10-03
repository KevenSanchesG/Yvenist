import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';

/// Solicita o orçamento da festa: congela o conteúdo e manda cada item para o
/// fornecedor dele. Pedir de novo, depois de editar, é uma nova rodada.
class RequestQuoteUseCase {
  RequestQuoteUseCase(this.repository);

  final PartyRepository repository;

  Future<Party> call(PartyId partyId) async {
    var party = await repository.getById(partyId);
    if (party == null) throw const PartyNotFound();

    // O orçamento é pedido a partir do planejamento, e a API só aceita um
    // passo por gravação: um rascunho (festa criada por uma versão antiga do
    // app) passa primeiro para o planejamento.
    if (party.status == PartyStatus.draft) {
      party.startPlanning();
      party = await repository.save(party);
    }

    party.requestQuote();
    return repository.save(party);
  }
}
