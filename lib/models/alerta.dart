import 'package:flutter/material.dart';
import 'ruta.dart';

/// Nombre de cada tipo de alerta, como en la web.
String nombreTipoAlerta(String tipo) => switch (tipo.toLowerCase()) {
      'delay' => 'Demora',
      'warning' => 'Advertencia',
      _ => 'Información',
    };

/// Una de las rutas a las que afecta una alerta, con su propio estado: la empresa puede marcar la alerta
/// resuelta en unas rutas y dejarla en proceso en otras.
class RutaDeAlerta {
  final int id;
  final String codigo;
  final String nombre;
  final Color color;

  /// En_proceso o Resuelta (en un reporte sin revisar, el estado de la alerta).
  final String estado;

  const RutaDeAlerta({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.color,
    required this.estado,
  });

  factory RutaDeAlerta.fromJson(Map<String, dynamic> j) => RutaDeAlerta(
        id: (j['id'] as num?)?.toInt() ?? 0,
        codigo: '${j['codigo'] ?? ''}',
        nombre: '${j['nombre'] ?? ''}',
        color: colorDesdeHex(j['color']),
        estado: '${j['estado'] ?? ''}',
      );

  bool get resuelta => estado == 'Resuelta';
}

/// Una alerta del centro de alertas (publicada o de «Mis reportes»).
class Alerta {
  final int id;
  final String tipo;
  final String descripcion;

  /// Pendiente, En_proceso, Resuelta o Cancelada.
  final String estado;
  final int rutaId;
  final String rutaCodigo;
  final String rutaNombre;
  final String rutaOrigen;
  final String rutaDestino;
  final Color color;

  /// "09/11/2026 7:43 p. m."
  final String fecha;

  /// Nombre de la empresa si la publicó ella.
  final String empresa;

  /// Hora hasta la que sigue vigente ("7:43 p. m."), si la empresa le puso duración.
  final String vence;
  final bool dePasajero;

  /// Quien la creó puede editarla o inhabilitarla mientras siga pendiente.
  final bool editable;

  /// Rutas a las que afecta, la principal primero. Vacía si el servidor no las envía (versión anterior).
  final List<RutaDeAlerta> rutas;

  // Solo en «Mis reportes»
  final bool confirmacion;
  final String sumada;
  final String sumadaEmpresa;
  final bool descartada;
  final String motivo;

  const Alerta({
    required this.id,
    required this.tipo,
    required this.descripcion,
    required this.estado,
    required this.rutaId,
    required this.rutaCodigo,
    required this.rutaNombre,
    required this.rutaOrigen,
    required this.rutaDestino,
    required this.color,
    required this.fecha,
    required this.empresa,
    required this.vence,
    required this.dePasajero,
    required this.editable,
    this.rutas = const [],
    this.confirmacion = false,
    this.sumada = '',
    this.sumadaEmpresa = '',
    this.descartada = false,
    this.motivo = '',
  });

  factory Alerta.fromJson(Map<String, dynamic> j) => Alerta(
        id: (j['id'] as num?)?.toInt() ?? 0,
        tipo: '${j['tipo'] ?? 'info'}'.toLowerCase(),
        descripcion: '${j['descripcion'] ?? ''}',
        estado: '${j['estado'] ?? ''}',
        rutaId: (j['ruta_id'] as num?)?.toInt() ?? 0,
        rutaCodigo: '${j['ruta_codigo'] ?? ''}',
        rutaNombre: '${j['ruta_nombre'] ?? ''}',
        rutaOrigen: '${j['ruta_origen'] ?? ''}',
        rutaDestino: '${j['ruta_destino'] ?? ''}',
        color: colorDesdeHex(j['color']),
        fecha: '${j['fecha'] ?? ''}',
        empresa: '${j['empresa'] ?? ''}',
        vence: '${j['vence'] ?? ''}',
        dePasajero: j['de_pasajero'] == true,
        editable: j['editable'] == true,
        rutas: [
          for (final r in j['rutas'] as List? ?? const [])
            if (r is Map<String, dynamic>) RutaDeAlerta.fromJson(r),
        ],
        confirmacion: j['confirmacion'] == true,
        sumada: '${j['sumada'] ?? ''}',
        sumadaEmpresa: '${j['sumada_empresa'] ?? ''}',
        descartada: j['descartada'] == true,
        motivo: '${j['motivo'] ?? ''}',
      );

  String get tipoNombre => nombreTipoAlerta(tipo);

  /// Las demás rutas a las que afecta (sin la principal).
  List<RutaDeAlerta> get otrasRutas => [for (final r in rutas) if (r.id != rutaId) r];

  /// Cuántas de sus rutas ya están resueltas mientras la alerta sigue en proceso en otras.
  int get rutasResueltas => estado == 'En_proceso' ? rutas.where((r) => r.resuelta).length : 0;

  /// La alerta toca esta ruta (como principal o como ruta afectada): para el filtro «Ruta».
  bool afectaRuta(int id) => id == rutaId || rutas.any((r) => r.id == id);

  /// Texto del estado en una alerta publicada.
  String get estadoTexto => estado == 'En_proceso' ? 'En proceso' : estado;

  /// Texto del estado en «Mis reportes».
  String get estadoReporte {
    if (estado == 'En_proceso') return 'En proceso';
    if (descartada) return 'Descartada';
    if (estado == 'Cancelada') return 'Inhabilitada';
    return estado;
  }

  /// Qué pasó con el reporte, en palabras (pie de la tarjeta en «Mis reportes»).
  String get pieReporte {
    if (estado == 'Pendiente') return 'Esperando la revisión de la empresa';
    if (estado == 'En_proceso') return 'Publicada en el mapa';
    if (estado == 'Resuelta') return 'La empresa la marcó resuelta';
    if (descartada) return 'No se publicó';
    return 'La inhabilitaste';
  }
}

/// Datos del pasajero con sesión.
class Usuario {
  final int id;
  final String nombre;
  final String email;
  final String nickName;
  final String telefono;
  final String colorPerfil;
  final String iniciales;

  /// sistema, claro u oscuro.
  final String tema;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.nickName,
    required this.telefono,
    required this.colorPerfil,
    required this.iniciales,
    required this.tema,
  });

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: (j['id'] as num?)?.toInt() ?? 0,
        nombre: '${j['nombre'] ?? ''}',
        email: '${j['email'] ?? ''}',
        nickName: '${j['nickName'] ?? ''}',
        telefono: '${j['telefono'] ?? ''}',
        colorPerfil: '${j['color_perfil'] ?? '#E63946'}',
        iniciales: '${j['iniciales'] ?? 'U'}',
        tema: '${j['tema'] ?? 'sistema'}',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'email': email,
        'nickName': nickName,
        'telefono': telefono,
        'color_perfil': colorPerfil,
        'iniciales': iniciales,
        'tema': tema,
      };

  Color get color => colorDesdeHex(colorPerfil, porDefecto: const Color(0xFFE63946));
}
