class Ruta {
  final int id;
  final String codigo;
  final String nombre;
  final String origen;
  final String destino;
  final double distanciaKm;
  final int duracionEstimadaMinutos;
  final int numParadas;
  final String estado;
  final List<List<double>> coordenadas;
  final List<Map<String, double>> paradas;

  Ruta({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.origen,
    required this.destino,
    required this.distanciaKm,
    required this.duracionEstimadaMinutos,
    required this.numParadas,
    required this.estado,
    required this.coordenadas,
    required this.paradas,
  });

  factory Ruta.fromJson(Map<String, dynamic> json) {
    return Ruta(
      id: json['id'] ?? 0,
      codigo: json['codigo'] ?? '',
      nombre: json['nombre'] ?? '',
      origen: json['origen'] ?? '',
      destino: json['destino'] ?? '',
      distanciaKm: (json['distancia_km'] ?? 0).toDouble(),
      duracionEstimadaMinutos: json['duracion_estimada_minutos'] ?? 0,
      numParadas: json['num_paradas'] ?? 0,
      estado: json['estado'] ?? 'Inactiva',
      coordenadas: (json['coordenadas'] as List? ?? [])
          .map((c) => [(c[0] as num).toDouble(), (c[1] as num).toDouble()])
          .toList(),
      paradas: (json['paradas'] as List? ?? [])
          .map((p) => {
                'lat': (p['lat'] as num).toDouble(),
                'lng': (p['lng'] as num).toDouble(),
              })
          .toList(),
    );
  }
}