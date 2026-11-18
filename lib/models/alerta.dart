/// Alerta publicada, tal como la devuelve `GET /api/alertas/`.
/// El backend solo envía las que ya revisó la empresa: En_proceso o Resuelta.
class Alerta {
  /// Tipos que se pueden crear (TIPOS_ALERTA en Django).
  static const demora = 'delay';
  static const advertencia = 'warning';
  static const informacion = 'info';

  static const enProceso = 'En_proceso';
  static const resuelta = 'Resuelta';

  final int id;
  final String tipo;
  final String descripcion;
  final String estado;
  final String ruta;
  final int rutaId;

  /// Nickname del pasajero o nombre de la empresa que la creó.
  final String usuario;
  final DateTime fecha;

  /// Cuándo la publicó la empresa.
  final DateTime? publicada;

  /// Si la empresa le puso duración: a esta hora pasa sola a Resuelta.
  final DateTime? vence;

  Alerta({
    required this.id,
    required this.tipo,
    required this.descripcion,
    required this.estado,
    required this.ruta,
    required this.rutaId,
    required this.usuario,
    required this.fecha,
    this.publicada,
    this.vence,
  });

  bool get estaVigente => estado == enProceso;
  bool get estaResuelta => estado == resuelta;

  /// La fecha que le importa a quien consulta: desde cuándo es pública.
  DateTime get fechaVisible => publicada ?? fecha;

  factory Alerta.fromJson(Map<String, dynamic> json) {
    return Alerta(
      id: json['id'] ?? 0,
      tipo: json['tipo'] ?? informacion,
      descripcion: json['descripcion'] ?? '',
      estado: json['estado'] ?? '',
      ruta: json['ruta'] ?? '',
      rutaId: json['ruta_id'] ?? 0,
      usuario: json['usuario'] ?? '',
      fecha: _fecha(json['fecha']) ?? DateTime.now(),
      publicada: _fecha(json['publicada']),
      vence: _fecha(json['vence']),
    );
  }

  static DateTime? _fecha(dynamic valor) => valor is String ? DateTime.tryParse(valor) : null;
}
