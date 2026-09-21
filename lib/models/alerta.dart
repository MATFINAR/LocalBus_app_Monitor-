class Alerta {
  final int id;
  final String tipo;
  final String descripcion;
  final String estado;
  final String ruta;
  final int rutaId;
  final String usuario;
  final DateTime fecha;

  Alerta({
    required this.id,
    required this.tipo,
    required this.descripcion,
    required this.estado,
    required this.ruta,
    required this.rutaId,
    required this.usuario,
    required this.fecha,
  });

  factory Alerta.fromJson(Map<String, dynamic> json) {
    return Alerta(
      id: json['id'] ?? 0,
      tipo: json['tipo'] ?? 'info',
      descripcion: json['descripcion'] ?? '',
      estado: json['estado'] ?? '',
      ruta: json['ruta'] ?? '',
      rutaId: json['ruta_id'] ?? 0,
      usuario: json['usuario'] ?? '',
      fecha: DateTime.tryParse(json['fecha'] ?? '') ?? DateTime.now(),
    );
  }
}