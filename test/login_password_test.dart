import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_mobile/app.dart';
import 'package:todo_mobile/src/app_model.dart';
import 'package:todo_mobile/src/scope.dart';
import 'package:todo_mobile/theme.dart';
import 'package:todo_mobile/ui/login_screen.dart';

void main() {
  const secureChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      secureChannel,
      (call) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      secureChannel,
      null,
    );
  });

  testWidgets('password can be shown and hidden on both auth tabs', (tester) async {
    await tester.pumpWidget(
      AppScope(
        model: AppModel(),
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();

    TextField passwordField() {
      return tester.widget<TextField>(
        find.byWidgetPredicate(
          (widget) => widget is TextField && widget.decoration?.hintText == '••••••••',
        ),
      );
    }

    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.byTooltip('Afficher le mot de passe'));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);

    await tester.tap(find.text('Créer un compte'));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);

    await tester.tap(find.byTooltip('Masquer le mot de passe'));
    await tester.pump();
    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.text('Connexion'));
    await tester.pump();
    expect(find.byTooltip('Afficher le mot de passe'), findsOneWidget);
    expect(passwordField().obscureText, isTrue);
  });

  testWidgets('logout opens the login and register tabs', (tester) async {
    final model = AppModel();
    model.phase = SessionPhase.ready;
    await tester.pumpWidget(MesTachesApp(model: model));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Réglages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Déconnexion'));
    await tester.pumpAndSettle();

    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('MOT DE PASSE'), findsOneWidget);
    expect(find.byTooltip('Afficher le mot de passe'), findsOneWidget);
    expect(find.text('Paramètres'), findsNothing);
  });
}
