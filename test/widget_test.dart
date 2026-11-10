import 'package:flutter_test/flutter_test.dart';

import 'package:saludcerca/main.dart';

void main() {
  testWidgets('Login -> Inicio -> Detalle', (tester) async {
    await tester.pumpWidget(const SaludCercaApp());
    expect(find.text('SaludCerca'), findsOneWidget);

    await tester.tap(find.text('Entrar como invitado'));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Invitado'), findsOneWidget);

    await tester.tap(find.text('Centro de Salud Villa Victoria'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle del centro'), findsOneWidget);
  });
}
