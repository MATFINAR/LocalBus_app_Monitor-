import 'package:latlong2/latlong.dart';

/// Ruta tal como la devuelve `GET /api/rutas/`.
class Ruta {
  /// Estados que calcula el backend (Ruta.ESTADOS_VISIBLES en Django).
  static const activa = 'Activa';
  static const sinBuses = 'Sin_buses';
  static const fueraHorario = 'Fuera_horario';
  static const fueraServicio = 'Fuera_servicio';

  final int id;
  final String codigo;
  final String nombre;
  final String empresa;
  final int empresaId;
  final String origen;
  final String destino;
  final double distanciaKm;
  final int duracionEstimadaMinutos;
  final int numParadas;

  /// Activa, Sin_buses, Fuera_horario o Fuera_servicio.
  final String estado;

  /// Texto para mostrar: "Sin buses activos", "Fuera de horario"...
  final String estadoNombre;

  /// Explicación del estado para quien consulta (vacía si está activa).
  final String motivo;

  /// Recorrido en orden. El backend lo envía como [longitud, latitud].
  final List<LatLng> recorrido;
  final List<LatLng> paradas;

  Ruta({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.empresa,
    required this.empresaId,
    required this.origen,
    required this.destino,
    required this.distanciaKm,
    required this.duracionEstimadaMinutos,
    required this.numParadas,
    required this.estado,
    required this.estadoNombre,
    required this.motivo,
    required this.recorrido,
    required this.paradas,
  });

  bool get estaActiva => estado == activa;
  bool get estaFueraDeServicio => estado == fueraServicio;
  bool get tieneRecorrido => recorrido.length >= 2;

  factory Ruta.fromJson(Map<String, dynamic> json) {
    final estado = json['estado'] as String? ?? fueraHorario;
    return Ruta(
      id: json['id'] ?? 0,
      codigo: json['codigo'] ?? '',
      nombre: json['nombre'] ?? '',
      empresa: json['empresa'] ?? '',
      empresaId: json['empresa_id'] ?? 0,
      origen: json['origen'] ?? '',
      destino: json['destino'] ?? '',
      distanciaKm: (json['distancia_km'] as num? ?? 0).toDouble(),
      duracionEstimadaMinutos: json['duracion_estimada_minutos'] ?? 0,
      numParadas: json['num_paradas'] ?? 0,
      estado: estado,
      estadoNombre: json['estado_nombre'] as String? ?? estado.replaceAll('_', ' '),
      motivo: json['motivo'] as String? ?? '',
      recorrido: _leerRecorrido(json['coordenadas']),
      paradas: _leerParadas(json['paradas']),
    );
  }

  static List<LatLng> _leerRecorrido(dynamic datos) {
    final puntos = <LatLng>[];
    for (final c in (datos as List? ?? const [])) {
      if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
        puntos.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
      }
    }
    return puntos;
  }

  static List<LatLng> _leerParadas(dynamic datos) {
    final puntos = <LatLng>[];
    for (final p in (datos as List? ?? const [])) {
      if (p is Map && p['lat'] is num && p['lng'] is num) {
        puntos.add(LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()));
      }
    }
    return puntos;
  }
}
