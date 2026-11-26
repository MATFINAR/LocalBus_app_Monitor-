import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'server_config.dart';
import 'sesion.dart';

/// Error de una petición, con el mensaje que se le muestra a la persona.
class ApiError implements Exception {
  ApiError(this.mensaje, this.status, {this.reiniciar = false, this.datos = const {}});

  final String mensaje;

  /// Código HTTP (0 si no hubo conexión).
  final int status;

  /// El paso ya no sirve (código vencido, demasiados intentos): hay que empezar de nuevo.
  final bool reiniciar;
  final Map<String, dynamic> datos;

  bool get sinConexion => status == 0;

  @override
  String toString() => mensaje;
}

/// Cliente del servidor de LocalBus. Las rutas relativas van a /api/movil/; las que empiezan por "/" se usan
/// tal cual (por ejemplo /api/ubicaciones/). Con sesión envía el token en la cabecera Authorization.
class Api {
  Api._();

  static const Duration _espera = Duration(seconds: 15);

  /// Para las peticiones que envían un correo (registro, recuperar la contraseña, cambiar el correo): el
  /// servidor espera al proveedor de correo hasta 10 s antes de responder.
  static const Duration esperaCorreo = Duration(seconds: 35);

  static Uri _uri(String ruta, [Map<String, String>? q]) {
    final camino = ruta.startsWith('/') ? ruta : '/api/movil/$ruta';
    final uri = Uri.parse('${ServerConfig.url}$camino');
    return q == null || q.isEmpty ? uri : uri.replace(queryParameters: q);
  }

  /// Dirección completa de una página de la web (términos, privacidad).
  static Uri web(String ruta) => Uri.parse('${ServerConfig.url}$ruta');

  static Map<String, String> _cabeceras() => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (Sesion.i.token != null) 'Authorization': 'Bearer ${Sesion.i.token}',
      };

  static Future<Map<String, dynamic>> get(String ruta, {Map<String, String>? q}) =>
      _enviar(() => http.get(_uri(ruta, q), headers: _cabeceras()));

  static Future<Map<String, dynamic>> post(String ruta, [Map<String, dynamic> datos = const {}, Duration? espera]) =>
      _enviar(() => http.post(_uri(ruta), headers: _cabeceras(), body: jsonEncode(datos)), espera);

  static Future<Map<String, dynamic>> _enviar(Future<http.Response> Function() pedir, [Duration? espera]) async {
    final http.Response respuesta;
    try {
      respuesta = await pedir().timeout(espera ?? _espera);
    } on TimeoutException {
      throw ApiError('El servidor tarda en responder. Revisa tu conexión e inténtalo de nuevo.', 0);
    } catch (_) {
      throw ApiError('No pudimos conectar con LocalBus. Revisa tu conexión a internet.', 0);
    }

    Map<String, dynamic> datos = {};
    try {
      final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (cuerpo is Map<String, dynamic>) datos = cuerpo;
    } catch (_) {
      // Respuesta que no es JSON (p. ej. una página de error): se explica con el código
    }

    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) return datos;

    final mensaje = datos['error'] is String
        ? datos['error'] as String
        : 'Algo salió mal en el servidor (error ${respuesta.statusCode}). Inténtalo de nuevo.';
    // El token venció o la contraseña cambió en otro dispositivo: se cierra la sesión de la app
    if (respuesta.statusCode == 401 && datos['sesion'] == false && Sesion.i.activa) {
      Sesion.i.expiro(mensaje);
    }
    throw ApiError(mensaje, respuesta.statusCode, reiniciar: datos['reiniciar'] == true, datos: datos);
  }
}
