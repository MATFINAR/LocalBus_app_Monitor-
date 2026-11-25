import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/alerta.dart';
import '../theme/app_theme.dart';
import 'api.dart';
import 'mensajes.dart';

/// Sesión del pasajero en la app. Sin sesión, la app es la del invitado (como la web sin iniciar sesión).
///
/// El token se guarda cifrado en el celular solo si se marcó «Recordarme»; si no, dura mientras la app
/// esté abierta.
class Sesion extends ChangeNotifier {
  Sesion._();
  static final Sesion i = Sesion._();

  static const _almacen = FlutterSecureStorage();
  static const _claveToken = 'sesion_token';
  static const _claveUsuario = 'sesion_usuario';

  String? token;
  Usuario? usuario;
  bool _recordar = true;

  bool get activa => token != null && usuario != null;

  /// Lee la sesión guardada. Llamar una vez antes de `runApp`.
  Future<void> cargar() async {
    try {
      token = await _almacen.read(key: _claveToken);
      final guardado = await _almacen.read(key: _claveUsuario);
      if (token != null && guardado != null) {
        usuario = Usuario.fromJson(jsonDecode(guardado) as Map<String, dynamic>);
      } else {
        token = null;
      }
    } catch (e) {
      debugPrint('No se pudo leer la sesión guardada: $e');
      token = null;
      usuario = null;
    }
    _aplicarTema();
  }

  /// Confirma con el servidor que la sesión sigue valiendo y trae los datos al día.
  Future<void> refrescar() async {
    if (!activa) return;
    try {
      final d = await Api.get('yo/');
      await actualizarUsuario(Usuario.fromJson(d['usuario'] as Map<String, dynamic>));
    } on ApiError {
      // Sin conexión se sigue con lo guardado; un token vencido ya cerró la sesión (ver Api)
    }
  }

  Future<void> iniciar(String nuevoToken, Usuario nuevoUsuario, {required bool recordar}) async {
    token = nuevoToken;
    usuario = nuevoUsuario;
    _recordar = recordar;
    await _guardar();
    _aplicarTema();
    notifyListeners();
  }

  Future<void> actualizarUsuario(Usuario nuevo) async {
    usuario = nuevo;
    await _guardar();
    _aplicarTema();
    notifyListeners();
  }

  Future<void> actualizarToken(String nuevo) async {
    token = nuevo;
    await _guardar();
  }

  Future<void> cerrar() async {
    token = null;
    usuario = null;
    try {
      await _almacen.delete(key: _claveToken);
      await _almacen.delete(key: _claveUsuario);
    } catch (_) {}
    _aplicarTema();
    notifyListeners();
  }

  /// El servidor dijo que el token ya no sirve.
  void expiro(String mensaje) {
    if (!activa) return;
    cerrar();
    Mensajes.mostrar(mensaje, nivel: Nivel.error);
  }

  Future<void> _guardar() async {
    try {
      if (_recordar && token != null && usuario != null) {
        await _almacen.write(key: _claveToken, value: token);
        await _almacen.write(key: _claveUsuario, value: jsonEncode(usuario!.toJson()));
      } else {
        await _almacen.delete(key: _claveToken);
        await _almacen.delete(key: _claveUsuario);
      }
    } catch (e) {
      debugPrint('No se pudo guardar la sesión: $e');
    }
  }

  /// Tema elegido en «Mi perfil > Ajustes». Sin sesión, o con «Igual que el dispositivo», se sigue al celular.
  void _aplicarTema() {
    AppTheme.mode.value = switch (usuario?.tema) {
      'claro' => ThemeMode.light,
      'oscuro' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
