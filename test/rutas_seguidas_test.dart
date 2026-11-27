import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monitor_app/models/alerta.dart';
import 'package:monitor_app/screens/alertas_screen.dart';
import 'package:monitor_app/services/sesion.dart';
import 'package:monitor_app/theme/app_theme.dart';

void main() {
  testWidgets('«Rutas que sigo» se puede buscar sin perder lo elegido', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await Sesion.i.iniciar('t', Usuario.fromJson({'nombre': 'Ana'}), recordar: false);
    List<dynamic>? guardadas;
    final servidor = MockClient((p) async {
      if (p.url.path.endsWith('alertas/seguir/')) {
        guardadas = (jsonDecode(p.body) as Map)['rutas'] as List;
        return http.Response(jsonEncode({'mensaje': 'Listo', 'rutas_seguidas': guardadas}), 200);
      }
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'alertas': [],
            'rutas': [
              {'id': 1, 'codigo': 'ES-06', 'nombre': 'San Antonio de Prado - Itagüí'},
              {'id': 2, 'codigo': 'TN-01', 'nombre': 'Niquía - Centro'},
            ],
            'rutas_seguidas': [2],
          })),
          200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const AlertasScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RUTAS QUE SIGO'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNWidgets(2));

      final campo = find.widgetWithText(TextField, 'Buscar por código o nombre');
      await tester.enterText(campo, 'itagui');
      await tester.pump();
      expect(find.byType(CheckboxListTile), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      await tester.enterText(campo, 'zzz');
      await tester.pump();
      expect(find.textContaining('No encontramos rutas'), findsOneWidget);
      expect(find.text('2 rutas elegidas'), findsOneWidget);

      await tester.ensureVisible(find.text('GUARDAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GUARDAR'));
      await tester.pumpAndSettle();
    }, () => servidor);

    expect(guardadas, unorderedEquals([1, 2]));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 12)); // los mensajes se cierran solos
  });
}
