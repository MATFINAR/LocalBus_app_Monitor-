/// Último punto de un bus en vivo (GET /api/ubicaciones/).
class BusUbicacion {
  final int busId;
  final String placa;
  final String empresa;
  final String ruta;
  final int rutaId;
  final String rutaCodigo;
  final double latitud;
  final double longitud;
  final double velocidad;
  final DateTime timestamp;

  const BusUbicacion({
    required this.busId,
    required this.placa,
    required this.empresa,
    required this.ruta,
    required this.rutaId,
    required this.rutaCodigo,
    required this.latitud,
    required this.longitud,
    required this.velocidad,
    required this.timestamp,
  });

  factory BusUbicacion.fromJson(Map<String, dynamic> json) {
    double numero(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return BusUbicacion(
      busId: (json['bus_id'] as num?)?.toInt() ?? 0,
      placa: '${json['placa'] ?? ''}',
      empresa: '${json['empresa'] ?? ''}',
      ruta: '${json['ruta'] ?? ''}',
      rutaId: (json['ruta_id'] as num?)?.toInt() ?? 0,
      rutaCodigo: '${json['ruta_codigo'] ?? ''}',
      latitud: numero(json['latitud']),
      longitud: numero(json['longitud']),
      velocidad: numero(json['velocidad']),
      timestamp: DateTime.tryParse('${json['timestamp']}') ?? DateTime.now(),
    );
  }
}
