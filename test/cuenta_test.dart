import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monitor_app/screens/cuenta_screen.dart';
import 'package:monitor_app/services/mensajes.dart';
import 'package:monitor_app/services/sesion.dart';
import 'package:monitor_app/theme/app_theme.dart';

http.Response _json(Map<String, dynamic> d, [int codigo = 200]) =>
    http.Response(jsonEncode(d), codigo, headers: {'content-type': 'application/json; charset=utf-8'});

Future<void> _tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Como en main.dart: la capa de mensajes va por encima del navegador.
Widget _app(Widget inicio) => MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MensajesHost(child: child!),
      home: inicio,
    );

void main() {
  testWidgets('Recuperar la contraseña y después iniciar sesión sale del formulario', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final pedidos = <String>[];
    final servidor = MockClient((p) async {
      pedidos.add(p.url.path);
      return switch (p.url.path) {
        '/api/movil/recuperar/' => _json({'ok': true, 'mensaje': 'Código enviado'}),
        '/api/movil/recuperar/verificar/' => _json({'ok': true, 'permiso': 'abc'}),
        '/api/movil/recuperar/nueva/' => _json({'ok': true, 'mensaje': 'Listo', 'email': 'a@b.co'}),
        '/api/movil/login/' => _json({
            'ok': true,
            'mensaje': 'Hola',
            'token': 't',
            'usuario': {'nombre': 'Ana'},
          }),
        _ => _json({'ok': true, 'usuario': {'nombre': 'Ana'}}),
      };
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(_app(const CuentaTab()));
      await tester.pumpAndSettle();

      await _tocar(tester, find.text('¿Olvidaste tu contraseña?'));
      await tester.enterText(find.byType(TextField).last, 'a@b.co');
      await _tocar(tester, find.text('ENVIAR CÓDIGO'));
      await tester.enterText(find.byType(TextField).last, '123456');
      await _tocar(tester, find.text('VERIFICAR CÓDIGO'));
      await tester.enterText(find.byType(TextField).at(0), 'Clave.Nueva.2026');
      await tester.enterText(find.byType(TextField).at(1), 'Clave.Nueva.2026');
      await _tocar(tester, find.text('GUARDAR CONTRASEÑA'));

      expect(find.text('Inicia sesión'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), 'Clave.Nueva.2026');
      await tester.ensureVisible(find.text('INICIAR SESIÓN'));
      await tester.tap(find.text('INICIAR SESIÓN'));
      // Sin pumpAndSettle: «Mi perfil» puede quedarse cargando
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }, () => servidor);

    expect(pedidos, contains('/api/movil/login/'));
    expect(Sesion.i.activa, isTrue);
    expect(find.text('INICIAR SESIÓN'), findsNothing);
    await tester.pump(const Duration(seconds: 12)); // los mensajes se cierran solos
  });

  testWidgets('Recuperar y nueva contraseña validan como la web antes de enviar', (tester) async {
    final pedidos = <String, Map<String, dynamic>>{};
    final servidor = MockClient((p) async {
      pedidos[p.url.path] = jsonDecode(p.body) as Map<String, dynamic>;
      return switch (p.url.path) {
        '/api/movil/recuperar/' => _json({'ok': true, 'mensaje': 'Código enviado'}),
        '/api/movil/recuperar/verificar/' => _json({'ok': true, 'permiso': 'abc'}),
        '/api/movil/contrasena/' => _json({'ok': true, 'error': 'Esta contraseña es demasiado común.'}),
        _ => _json({'ok': true}),
      };
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(_app(const RecuperarScreen()));
      await tester.enterText(find.byType(TextField), 'correo-sin-arroba');
      await _tocar(tester, find.text('ENVIAR CÓDIGO'));
      expect(find.text('Escribe un correo válido, por ejemplo tu@correo.com.'), findsOneWidget);
      expect(pedidos, isEmpty);

      await tester.enterText(find.byType(TextField), 'a@b.co');
      await _tocar(tester, find.text('ENVIAR CÓDIGO'));
      await tester.enterText(find.byType(TextField).last, '123456');
      await _tocar(tester, find.text('VERIFICAR CÓDIGO'));

      await tester.enterText(find.byType(TextField).at(0), 'corta');
      await tester.enterText(find.byType(TextField).at(1), 'corta');
      await _tocar(tester, find.text('GUARDAR CONTRASEÑA'));
      expect(find.text('La contraseña debe tener al menos 8 caracteres.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'password123');
      await tester.pump(const Duration(seconds: 1)); // revisión de las reglas en el servidor
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await _tocar(tester, find.text('GUARDAR CONTRASEÑA'));
      expect(find.text('Cambia la contraseña: Esta contraseña es demasiado común.'), findsOneWidget);
    }, () => servidor);

    expect(pedidos['/api/movil/contrasena/'], {'password': 'password123', 'permiso': 'abc'});
    expect(pedidos.containsKey('/api/movil/recuperar/nueva/'), isFalse);
    await tester.pump(const Duration(seconds: 12)); // los mensajes se cierran solos
  });

  testWidgets('Registrarse envía los datos y el código de verificación', (tester) async {
    final pedidos = <String, Map<String, dynamic>>{};
    final servidor = MockClient((p) async {
      pedidos[p.url.path] = jsonDecode(p.body) as Map<String, dynamic>;
      return switch (p.url.path) {
        '/api/movil/registro/' => _json({'ok': true, 'pendiente': 'p1', 'email': 'a@b.co'}),
        '/api/movil/registro/verificar/' => _json({'ok': true, 'mensaje': 'Cuenta creada'}),
        _ => _json({'ok': true, 'existe': false}),
      };
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(_app(const RegistroScreen()));
      final textos = ['Ana', 'Pérez', 'a@b.co', 'ana.perez', 'Clave.Nueva.2026', 'Clave.Nueva.2026'];
      for (var i = 0; i < textos.length; i++) {
        final campo = find.byType(TextField, skipOffstage: false).at(i);
        await tester.ensureVisible(campo);
        await tester.pumpAndSettle();
        await tester.enterText(campo, textos[i]);
        await tester.pump(const Duration(seconds: 1));
      }
      await _tocar(tester, find.byType(Checkbox, skipOffstage: false).first);
      await _tocar(tester, find.text('CREAR CUENTA', skipOffstage: false));
      await tester.enterText(find.byType(TextField).last, '123456');
      await _tocar(tester, find.text('VERIFICAR Y CREAR CUENTA'));
    }, () => servidor);

    expect(tester.takeException(), isNull);
    expect(pedidos['/api/movil/registro/']?['username'], 'ana.perez');
    expect(pedidos['/api/movil/registro/verificar/'], {'pendiente': 'p1', 'codigo': '123456'});
    await tester.pump(const Duration(seconds: 12)); // los mensajes se cierran solos
  });
}
