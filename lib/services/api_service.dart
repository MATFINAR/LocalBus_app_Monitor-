import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/ruta.dart';
import '../models/alerta.dart';
import '../models/bus_ubicacion.dart';

/// Error de la API con un mensaje que se puede mostrar tal cual.
class ApiException implements Exception {
  final String mensaje;
  const ApiException(this.mensaje);

  @override
  String toString() => mensaje;
}

class ApiService {
  static String get baseUrl => Config.apiUrl;

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

  Future<http.Response> _pedir(String ruta) async {
    try {
      return await http.get(Uri.parse('$baseUrl$ruta')).timeout(Config.tiempoEspera);
    } on TimeoutException {
      throw const ApiException('El servidor tardó demasiado en responder. Revisa la conexión.');
    } on http.ClientException {
      throw ApiException('No se pudo conectar con el servidor ($baseUrl). '
          'Revisa que esté encendido y en la misma red.');
    }
  }

  Future<Map<String, dynamic>> _getJson(String ruta) async {
    final respuesta = await _pedir(ruta);

    if (respuesta.statusCode == 400) {
      // Lo más común: la IP del servidor no está en DJANGO_ALLOWED_HOSTS
      throw ApiException('El servidor rechazó la petición. '
          'Agrega la dirección de $baseUrl a DJANGO_ALLOWED_HOSTS.');
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
