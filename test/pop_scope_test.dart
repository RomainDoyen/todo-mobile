import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_mobile/src/app_model.dart';
import 'package:todo_mobile/src/scope.dart';
import 'package:todo_mobile/theme.dart';
import 'package:todo_mobile/ui/home_screen.dart';
import 'package:todo_mobile/ui/task_page.dart';

void main() {
  testWidgets('the task sheet stays above the system bar and fields contrast', (
    tester,
  ) async {
    _systemBar(tester);
    final model = AppModel();
    await tester.pumpWidget(
      AppScope(
        model: model,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showTaskEditor(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final button = tester.getRect(find.text('Créer la tâche'));
    expect(button.bottom, lessThanOrEqualTo(screen.height - 48));

    final description = tester
        .widgetList<TextField>(find.byType(TextField))
        .firstWhere(
          (field) => field.decoration?.hintText == 'Description (optionnel)',
        );
    expect(description.decoration?.fillColor, const Color(0xFFEDF1F6));

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('the home action stays above the system bar', (tester) async {
    _systemBar(tester);
    await tester.pumpWidget(
      AppScope(
        model: AppModel(),
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final create = tester.getRect(find.byTooltip('Créer une tâche'));
    expect(create.bottom, lessThanOrEqualTo(screen.height - 48));
  });

  testWidgets('canceling a text dialog does not assert', (tester) async {
    final model = AppModel();
    await tester.pumpWidget(
      AppScope(
        model: model,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showTaskEditor(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouvelle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle tâche'), findsOneWidget);
  });
}

void _systemBar(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(bottom: 48, top: 24);
  tester.view.viewPadding = const FakeViewPadding(bottom: 48, top: 24);
  addTearDown(tester.view.reset);
}
