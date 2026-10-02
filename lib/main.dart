import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/navigation/app_tab_controller.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/utils/id_generator.dart';
import 'package:yvenist/features/client/home/presentation/pages/home_client_page.dart';
import 'package:yvenist/features/party_maker/data/repositories/in_memory_party_repository.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/party_maker_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUi);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppTabController()),
        ChangeNotifierProvider(
          create: (_) => PartyMakerController(
            repository: InMemoryPartyRepository(),
            ids: UuidGenerator(),
            ownerId: 'user_1',
          )..load(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yvenist',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeScreen(),
    );
  }
}
