/// Último punto de un bus con turno en curso, tal como lo devuelve `GET /api/ubicaciones/`.
class BusUbicacion {
  final int busId;
  final String placa;
  final String empresa;
  final String? ruta;
  final int? rutaId;
  final String? rutaCodigo;
  final String? conductor;
  final double latitud;
  final double longitud;
  final double velocidad;
  final DateTime timestamp;

  BusUbicacion({
    required this.busId,
    required this.placa,
    required this.empresa,
    this.ruta,
    this.rutaId,
    this.rutaCodigo,
    this.conductor,
    required this.latitud,
    required this.longitud,
    required this.velocidad,
    required this.timestamp,
  });

  factory BusUbicacion.fromJson(Map<String, dynamic> json) {
    return BusUbicacion(
      busId: json['bus_id'] ?? 0,
      placa: json['placa'] ?? '',
      empresa: json['empresa'] ?? '',
      ruta: json['ruta'],
      rutaId: json['ruta_id'],
      rutaCodigo: json['ruta_codigo'],
      conductor: json['conductor'],
      latitud: (json['latitud'] as num? ?? 0).toDouble(),
      longitud: (json['longitud'] as num? ?? 0).toDouble(),
      velocidad: (json['velocidad'] as num? ?? 0).toDouble(),
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}
