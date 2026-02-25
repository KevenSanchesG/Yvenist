import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/repositories/in_memory_party_repository.dart';
import '../domain/use_cases/add_item_to_party_use_case.dart';
import '../domain/use_cases/create_party_use_case.dart';
import '../domain/use_cases/lock_party_for_payment_use_case.dart';
import '../domain/use_cases/remove_item_from_party_use_case.dart';
import '../domain/use_cases/start_planning_use_case.dart';
import '../domain/use_cases/unlock_party_use_case.dart';
import 'controllers/party_maker_controller.dart';

class PartyMakerScope extends StatelessWidget {
  final Widget child;

  const PartyMakerScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ============================================================
        // Data (single instance)
        // ============================================================
        Provider<InMemoryPartyRepository>(
          create: (_) => InMemoryPartyRepository(),
        ),

        // ============================================================
        // UseCases (all depend on the same repo)
        // ============================================================
        ProxyProvider<InMemoryPartyRepository, CreatePartyUseCase>(
          update: (_, repo, __) => CreatePartyUseCase(repo),
        ),
        ProxyProvider<InMemoryPartyRepository, StartPlanningUseCase>(
          update: (_, repo, __) => StartPlanningUseCase(repo),
        ),
        ProxyProvider<InMemoryPartyRepository, AddItemToPartyUseCase>(
          update: (_, repo, __) => AddItemToPartyUseCase(repo),
        ),
        ProxyProvider<InMemoryPartyRepository, RemoveItemFromPartyUseCase>(
          update: (_, repo, __) => RemoveItemFromPartyUseCase(repo),
        ),
        ProxyProvider<InMemoryPartyRepository, LockPartyForPaymentUseCase>(
          update: (_, repo, __) => LockPartyForPaymentUseCase(repo),
        ),
        ProxyProvider<InMemoryPartyRepository, UnlockPartyUseCase>(
          update: (_, repo, __) => UnlockPartyUseCase(repo),
        ),

        // ============================================================
        // Controller
        // ============================================================
        ChangeNotifierProxyProvider6<
            InMemoryPartyRepository,
            CreatePartyUseCase,
            StartPlanningUseCase,
            AddItemToPartyUseCase,
            RemoveItemFromPartyUseCase,
            UnlockPartyUseCase,
            PartyMakerController>(
          create: (_) => PartyMakerController(
            // ⚠️ Placeholders: serão substituídos no update imediatamente.
            repo: InMemoryPartyRepository(),
            createParty: CreatePartyUseCase(InMemoryPartyRepository()),
            startPlanning: StartPlanningUseCase(InMemoryPartyRepository()),
            addItem: AddItemToPartyUseCase(InMemoryPartyRepository()),
            removeItem: RemoveItemFromPartyUseCase(InMemoryPartyRepository()),
            lockForPayment: LockPartyForPaymentUseCase(InMemoryPartyRepository()),
            unlockParty: UnlockPartyUseCase(InMemoryPartyRepository()),
          ),
          update: (
            _,
            repo,
            createUc,
            startPlanningUc,
            addItemUc,
            removeItemUc,
            unlockUc,
            previous,
          ) {
            return PartyMakerController(
              repo: repo,
              createParty: createUc,
              startPlanning: startPlanningUc,
              addItem: addItemUc,
              removeItem: removeItemUc,
              lockForPayment: LockPartyForPaymentUseCase(repo),
              unlockParty: unlockUc,
            );
          },
        ),
      ],
      child: child,
    );
  }
}
