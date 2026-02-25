import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/party_maker_controller.dart';
import 'my_parties_page.dart';
import 'party_builder_page.dart';

class PartyMakerEntryPage extends StatefulWidget {
  const PartyMakerEntryPage({super.key});

  @override
  State<PartyMakerEntryPage> createState() => _PartyMakerEntryPageState();
}

class _PartyMakerEntryPageState extends State<PartyMakerEntryPage> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PartyMakerController>().refreshFromRepo();
      setState(() => _loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Consumer<PartyMakerController>(
      builder: (context, controller, _) {
        final hasParties = controller.parties.isNotEmpty;

        if (!hasParties) {
          return const PartyBuilderPage();
        }

        return const MyPartiesPage();
      },
    );
  }
}