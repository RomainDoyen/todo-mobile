import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_mobile/src/app_model.dart';
import 'package:todo_mobile/src/scope.dart';
import 'package:todo_mobile/theme.dart';
import 'package:todo_mobile/ui/home_screen.dart';

void main() {
  testWidgets('the center tab button creates a task and the side tabs switch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AppScope(
        model: AppModel(),
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    final screen = tester.getSize(find.byType(HomeScreen));
    final create = tester.getRect(find.byTooltip('Créer une tâche'));
    expect(create.center.dx, closeTo(screen.width / 2, 1));
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Calendrier'), findsOneWidget);
    expect(find.text('Bilan'), findsOneWidget);
    expect(find.text('Profil'), findsWidgets);
    expect(find.text('Créer'), findsNothing);

    await tester.tap(find.text('Bilan'));
    await tester.pump();
    expect(find.text('Ouvertes'), findsOneWidget);
    expect(find.text('Urgentes'), findsOneWidget);

    await tester.tap(find.text('Calendrier'));
    await tester.pump();
    expect(find.text('Aucune tâche ce jour'), findsOneWidget);
    expect(find.byTooltip('Mois suivant'), findsOneWidget);

    await tester.tap(find.byTooltip('Créer une tâche'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle tâche'), findsOneWidget);
  });
}
