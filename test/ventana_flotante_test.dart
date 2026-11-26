import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monitor_app/screens/mapa_screen.dart';
import 'package:monitor_app/services/ventana_flotante.dart';
import 'package:monitor_app/theme/app_theme.dart';

/// Imagen de 1x1 para los mosaicos del mapa.
final _mosaico = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

void main() {
  testWidgets('Con una ruta fijada se permite la ventana flotante, y en ella solo queda el mapa', (tester) async {
    final permisos = <bool>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(VentanaFlotante.canal, (llamada) async {
      permisos.add(llamada.arguments as bool);
      return null;
    });
    final servidor = MockClient((p) async {
      if (p.url.host == 'tile.openstreetmap.org') return http.Response.bytes(_mosaico, 200);
      return http.Response(
          jsonEncode({
            'rutas': [
              {'id': 1, 'codigo': 'R1', 'nombre': 'Centro', 'coordenadas': [[-75.58, 6.24], [-75.57, 6.25]]},
            ],
            'buses': [],
          }),
          200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const MapaScreen()));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(permisos, isEmpty); // sin ruta fijada no hay ventana flotante

      await tester.tap(find.text('R1').last);
      await tester.pump(const Duration(milliseconds: 500));
      expect(permisos, [true]);

      VentanaFlotante.activa.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Rutas'), findsNothing);

      VentanaFlotante.activa.value = false;
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Rutas'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    }, () => servidor);

    expect(permisos.last, isFalse);
    expect(tester.takeException(), isNull);
  });
}
