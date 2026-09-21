class BusUbicacion {
  final int busId;
  final String placa;
  final String? ruta;
  final double latitud;
  final double longitud;
  final double velocidad;
  final DateTime timestamp;

  BusUbicacion({
    required this.busId,
    required this.placa,
    this.ruta,
    required this.latitud,
    required this.longitud,
    required this.velocidad,
    required this.timestamp,
  });

  factory BusUbicacion.fromJson(Map<String, dynamic> json) {
    return BusUbicacion(
      busId: json['bus_id'] ?? 0,
      placa: json['placa'] ?? '',
      ruta: json['ruta'],
      latitud: (json['latitud'] ?? 0).toDouble(),
      longitud: (json['longitud'] ?? 0).toDouble(),
      velocidad: (json['velocidad'] ?? 0).toDouble(),
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}