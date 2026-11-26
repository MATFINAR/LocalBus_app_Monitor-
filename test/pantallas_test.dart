import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monitor_app/screens/alertas_screen.dart';
import 'package:monitor_app/screens/cuenta_screen.dart';
import 'package:monitor_app/theme/app_theme.dart';

/// Estas pantallas quedaban en blanco por un error al pintar los bordes de sus tarjetas.
void main() {
  for (final (nombre, tema) in [('claro', AppTheme.light()), ('oscuro', AppTheme.dark())]) {
    testWidgets('La vista de ingresar se dibuja sin errores (tema $nombre)', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: tema, home: const LoginScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Inicia sesión'), findsOneWidget);
    });

    testWidgets('El listado de alertas se dibuja sin errores (tema $nombre)', (tester) async {
      final servidor = MockClient((_) async => http.Response(
            jsonEncode({
              'alertas': [
                {'id': 1, 'tipo': 'warning', 'estado': 'En_proceso', 'descripcion': 'Árbol caído', 'ruta_id': 2},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));

      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(theme: tema, home: const AlertasScreen()));
        await tester.pumpAndSettle();
      }, () => servidor);

      expect(tester.takeException(), isNull);
      expect(find.text('Árbol caído', skipOffstage: false), findsOneWidget);
    });
  }
}
