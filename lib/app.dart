import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/app_model.dart';
import 'src/models.dart';
import 'src/scope.dart';
import 'theme.dart';
import 'ui/home_screen.dart';
import 'ui/login_screen.dart';

class MesTachesApp extends StatefulWidget {
  const MesTachesApp({super.key, required this.model});

  final AppModel model;

  @override
  State<MesTachesApp> createState() => _MesTachesAppState();
}

class _MesTachesAppState extends State<MesTachesApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.model.phase == SessionPhase.ready) {
      widget.model.syncNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      model: widget.model,
      child: const _AppShell(),
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    return MaterialApp(
      key: ValueKey(model.phase),
      title: 'Mes Tâches',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: model.theme == AppTheme.dark ? ThemeMode.dark : ThemeMode.light,
      home: switch (model.phase) {
        SessionPhase.booting => const _BootScreen(),
        SessionPhase.signedOut => const LoginScreen(key: ValueKey('login')),
        SessionPhase.ready => const HomeScreen(key: ValueKey('home')),
        SessionPhase.failed => _BootScreen(message: model.bootError, onRetry: model.start),
      },
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen({this.message, this.onRetry});

  final String? message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    if (message == null) {
      return const AppShell(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(
                  image: AssetImage('assets/icon/app_icon_rounded.png'),
                  width: 96,
                  height: 96,
                ),
                SizedBox(height: 16),
                Text('Ouverture de vos tâches…'),
              ],
            ),
          ),
        ),
      );
    }

    return AppShell(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: danger),
                const SizedBox(height: 16),
                Text(message!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
