import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monitor_app/screens/acerca_screen.dart';
import 'package:monitor_app/theme/app_theme.dart';

void main() {
  testWidgets('En «Acerca de», presionar el servidor 15 segundos abre la ventana para cambiarlo', (tester) async {
    final servidor = MockClient((_) async => http.Response('{"ok": true}', 200));

    await http.runWithClient(() async {
      // Sin animaciones, para que la presentación no avance sola durante la prueba
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: const AcercaScreen(),
      ));
      await tester.pumpAndSettle();
      final texto = find.textContaining('Servidor: ');
      await tester.scrollUntilVisible(texto, 500, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      final dedo = await tester.startGesture(tester.getCenter(texto));
      await tester.pump(const Duration(seconds: 14));
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await dedo.up();
      await tester.pumpAndSettle();
    }, () => servidor);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Dirección del servidor'), findsOneWidget);
  });
}
