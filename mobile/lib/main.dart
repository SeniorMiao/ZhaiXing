import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/auth_controller.dart';
import 'providers/locale_controller.dart';
import 'screens/login_screen.dart';
import 'screens/app_shell.dart';
import 'services/auth_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeController = LocaleController();
  await localeController.load();
  runApp(ZxMeetingApp(localeController: localeController));
}

class ZxMeetingApp extends StatelessWidget {
  const ZxMeetingApp({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: localeController,
      child: ChangeNotifierProvider(
        create: (_) {
          final c = AuthController(AuthStorage());
          c.bootstrap();
          return c;
        },
        child: ListenableBuilder(
          listenable: localeController,
          builder: (context, _) {
            return MaterialApp(
              title: '智能会议纪要',
              locale: localeController.locale,
              supportedLocales: const [
                Locale('zh', 'CN'),
                Locale('en', 'US'),
              ],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              localeResolutionCallback: (deviceLocale, supported) {
                if (localeController.locale != null) {
                  return localeController.locale!;
                }
                if (deviceLocale != null) {
                  for (final s in supported) {
                    if (s.languageCode == deviceLocale.languageCode) {
                      return s;
                    }
                  }
                }
                return const Locale('zh', 'CN');
              },
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
                useMaterial3: true,
              ),
              home: const _RootGate(),
            );
          },
        ),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (!auth.bootstrapped) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (auth.isLoggedIn) {
      return const AppShell();
    }
    return const LoginScreen();
  }
}
