import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/ruta.dart';
import '../models/alerta.dart';
import '../models/bus_ubicacion.dart';
import '../servidor.dart';

/// Error de la API con un mensaje que se puede mostrar tal cual.
class ApiException implements Exception {
  final String mensaje;
  const ApiException(this.mensaje);

  @override
  String toString() => mensaje;
}

class ApiService {
  /// La que está guardada en Ajustes (o la de compilación si nunca se cambió).
  static String get baseUrl => Servidor.instancia.url;

  /// Prueba otra dirección sin guardarla. Devuelve cuántas rutas tiene ese servidor.
  Future<int> probarServidor(String url) async {
    final data = await _getJson('/api/rutas/', base: url);
    final List rutas = data['rutas'] ?? [];
    return rutas.length;
  }

  /// Todas las rutas habilitadas, con su estado calculado.
  Future<List<Ruta>> obtenerRutas() async {
    final data = await _getJson('/api/rutas/');
    final List rutas = data['rutas'] ?? [];
    return rutas.map((r) => Ruta.fromJson(r)).toList();
  }

  /// Alertas publicadas (en proceso o resueltas). El backend devuelve 50 como máximo.
  Future<List<Alerta>> obtenerAlertas() async {
    final data = await _getJson('/api/alertas/');
    final List alertas = data['alertas'] ?? [];
    return alertas.map((a) => Alerta.fromJson(a)).toList();
  }

  /// Último punto de cada bus con turno en curso.
  Future<List<BusUbicacion>> obtenerUbicaciones() async {
    final data = await _getJson('/api/ubicaciones/');
    final List buses = data['buses'] ?? [];
    return buses.map((b) => BusUbicacion.fromJson(b)).toList();
  }

  Future<http.Response> _pedir(String base, String ruta) async {
    try {
      return await http.get(Uri.parse('$base$ruta')).timeout(Config.tiempoEspera);
    } on TimeoutException {
      throw ApiException('El servidor ($base) tardó demasiado en responder. '
          'Revisa que el celular y el computador estén en la misma red Wi-Fi.');
    } on http.ClientException {
      throw ApiException('No se pudo conectar con el servidor ($base). '
          'Revisa que Django esté encendido y que la dirección en Ajustes sea la correcta.');
    } on FormatException {
      throw ApiException('La dirección del servidor ($base) no es válida. Corrígela en Ajustes.');
    }
  }

  Future<Map<String, dynamic>> _getJson(String ruta, {String? base}) async {
    final servidor = base ?? baseUrl;
    final respuesta = await _pedir(servidor, ruta);

    if (respuesta.statusCode == 400) {
      // Lo más común: la IP del servidor no está en DJANGO_ALLOWED_HOSTS
      final host = Uri.tryParse(servidor)?.host ?? servidor;
      throw ApiException('El servidor rechazó la petición. '
          'Agrega $host a DJANGO_ALLOWED_HOSTS en el .env de Django y reinícialo.');
    }
    if (respuesta.statusCode != 200) {
      throw ApiException('El servidor respondió con un error (${respuesta.statusCode}).');
    }

    try {
      final data = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (data is Map<String, dynamic>) return data;
    } on FormatException {
      // Se trata abajo
    }
    throw const ApiException('El servidor envió una respuesta que la app no entiende.');
  }
}
