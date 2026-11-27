import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monitor_app/models/alerta.dart';
import 'package:monitor_app/screens/acerca_screen.dart';
import 'package:monitor_app/screens/alertas_screen.dart';
import 'package:monitor_app/screens/cuenta_screen.dart';
import 'package:monitor_app/screens/mapa_screen.dart';
import 'package:monitor_app/screens/perfil_screen.dart';
import 'package:monitor_app/screens/rutas_screen.dart';
import 'package:monitor_app/services/navegacion.dart';
import 'package:monitor_app/services/sesion.dart';
import 'package:monitor_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fuentes.dart';

final _mosaico = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

final _servidor = MockClient((p) async {
  if (p.url.host == 'tile.openstreetmap.org') return http.Response.bytes(_mosaico, 200);
  return http.Response.bytes(
      utf8.encode(jsonEncode({
        'rutas': [
          {'id': 1, 'codigo': 'R1', 'nombre': 'Centro', 'coordenadas': [[-75.58, 6.24], [-75.57, 6.25]]},
        ],
        'alertas': [
          {'id': 1, 'tipo': 'delay', 'estado': 'En_proceso', 'descripcion': 'Trancón', 'ruta_id': 1},
        ],
        'usuario': {'nombre': 'Ana'},
      })),
      200);
});

Future<void> _avanzar(WidgetTester tester, [int veces = 10]) async {
  for (var i = 0; i < veces; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Recorre el tour abierto hasta el final y devuelve cuántos pasos tuvo.
Future<int> _recorrer(WidgetTester tester) async {
  final contador = find.textContaining('· Paso 1 de ');
  expect(contador, findsOneWidget, reason: 'el tour debe empezar solo la primera vez');
  final total = int.parse(tester.widget<Text>(contador).data!.split(' de ').last);
  for (var i = 1; i < total; i++) {
    await tester.tap(find.text('SIGUIENTE'));
    await _avanzar(tester, 4);
    expect(find.textContaining('· Paso ${i + 1} de $total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }
  await tester.tap(find.text('TERMINAR'));
  await _avanzar(tester, 4);
  expect(find.textContaining('· Paso '), findsNothing);
  return total;
}

void main() {
  setUpAll(cargarFuentes);

  // vista, pestaña, pantalla, pasos esperados (los de la web que existen sin sesión)
  final vistas = <(String, int, Widget, int)>[
    ('mapa', Navegacion.mapa, const MapaScreen(), 13),
    ('alertas', Navegacion.alertas, const AlertasScreen(), 7),
    ('rutas', Navegacion.rutas, const RutasScreen(), 6),
    ('acerca', Navegacion.acerca, const AcercaScreen(), 7),
    ('ingresar', Navegacion.cuenta, const LoginScreen(), 7),
    ('perfil', Navegacion.cuenta, const PerfilScreen(), 7),
  ];

  for (final (id, pestana, pantalla, pasos) in vistas) {
    testWidgets('Tour de $id: empieza solo la primera vez, se recorre entero y queda el botón', (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      if (id == 'perfil') {
        await Sesion.i.iniciar('t', Usuario.fromJson({'nombre': 'Ana'}), recordar: false);
      }
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      Navegacion.pestana.value = pestana;

      Widget app() => MaterialApp(
            theme: AppTheme.light(),
            builder: (context, hijo) =>
                MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: hijo!),
            home: pantalla,
          );

      await http.runWithClient(() async {
        await tester.pumpWidget(app());
        await _avanzar(tester);
        expect(await _recorrer(tester), pasos);

        // Segunda visita: no sale solo, pero el botón lo abre
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(app());
        await _avanzar(tester);
        expect(find.textContaining('· Paso '), findsNothing);
        await tester.tap(find.text('Guía').first);
        await _avanzar(tester, 5);
        expect(find.textContaining('· Paso 1 de $pasos'), findsOneWidget);
        await tester.tap(find.byTooltip('Salir de la guía'));
        await _avanzar(tester, 4);
        expect(find.textContaining('· Paso '), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await _avanzar(tester);
      }, () => _servidor);

      expect(tester.takeException(), isNull);
      Navegacion.pestana.value = Navegacion.mapa;
      if (id == 'perfil') await Sesion.i.cerrar();
    });
  }
}
