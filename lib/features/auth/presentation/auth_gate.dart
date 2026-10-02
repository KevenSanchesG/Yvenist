import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/features/auth/presentation/controllers/session_controller.dart';
import 'package:yvenist/features/auth/presentation/pages/login_page.dart';

/// Garante que há alguém autenticado antes de uma ação que exige conta.
///
/// Se já houver sessão, devolve `true` na hora. Senão, abre o login explicando
/// o motivo ([reason]) e devolve se a pessoa entrou. Navegar pelo catálogo não
/// exige conta; favoritar, montar festa e anunciar exigem.
Future<bool> ensureSignedIn(BuildContext context, {String? reason}) async {
  if (context.read<SessionController>().isSignedIn) return true;

  final signedIn = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LoginPage(reason: reason),
    ),
  );
  return signedIn ?? false;
}
