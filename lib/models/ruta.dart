import 'package:flutter/material.dart';

Color colorDesdeHex(String? hex, {Color porDefecto = const Color(0xFF5B646B)}) {
  final limpio = (hex ?? '').replaceFirst('#', '');
  final valor = int.tryParse(limpio, radix: 16);
  if (valor == null || limpio.length != 6) return porDefecto;
  return Color(0xFF000000 | valor);
}

double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

/// Una ruta pública, igual a como la ve el pasajero en la web.
class Ruta {
  final int id;
  final String codigo;
  final String nombre;
  final String empresa;
  final String origen;
  final String destino;
  final double distanciaKm;
  final int duracionMinutos;
  final int frecuenciaMinutos;
  final int numParadas;

  /// Activa, Sin_buses, Fuera_horario o Fuera_servicio.
  final String estado;
  final String estadoNombre;

  /// Explicación para el pasajero cuando la ruta no está activa.
  final String motivo;
  final Color color;

  /// Coordenadas [lng, lat], como las entrega el servidor.
  final List<List<double>> coordenadas;
  final List<({double lat, double lng})> paradas;

  const Ruta({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.empresa,
    required this.origen,
    required this.destino,
    required this.distanciaKm,
    required this.duracionMinutos,
    required this.frecuenciaMinutos,
    required this.numParadas,
    required this.estado,
    required this.estadoNombre,
    required this.motivo,
    required this.color,
    required this.coordenadas,
    required this.paradas,
  });

  bool get activa => estado == 'Activa';

  factory Ruta.fromJson(Map<String, dynamic> j) {
    return Ruta(
      id: _int(j['id']),
      codigo: '${j['codigo'] ?? ''}',
      nombre: '${j['nombre'] ?? ''}',
      empresa: '${j['empresa'] ?? ''}',
      origen: '${j['origen'] ?? ''}',
      destino: '${j['destino'] ?? ''}',
      distanciaKm: _num(j['distancia_km']),
      duracionMinutos: _int(j['duracion_estimada_minutos']),
      frecuenciaMinutos: _int(j['frecuencia_minutos']),
      numParadas: _int(j['num_paradas']),
      estado: '${j['estado'] ?? 'Activa'}',
      estadoNombre: '${j['estado_nombre'] ?? ''}',
      motivo: '${j['motivo'] ?? ''}',
      color: colorDesdeHex(j['color']),
      coordenadas: (j['coordenadas'] as List? ?? [])
          .whereType<List>()
          .where((c) => c.length >= 2)
          .map((c) => [_num(c[0]), _num(c[1])])
          .toList(),
      paradas: (j['paradas'] as List? ?? [])
          .whereType<Map>()
          .map((p) => (lat: _num(p['lat']), lng: _num(p['lng'])))
          .toList(),
    );
  }

  /// Distancia formateada como en la web: un decimal.
  String get distanciaTexto => '${distanciaKm.toStringAsFixed(1)} km';
}

/// Ruta en una lista para elegir (formularios de alertas, "Rutas que sigo").
class RutaOpcion {
  final int id;
  final String codigo;
  final String nombre;
  final Color color;

  const RutaOpcion({required this.id, required this.codigo, required this.nombre, required this.color});

  factory RutaOpcion.fromJson(Map<String, dynamic> j) => RutaOpcion(
        id: _int(j['id']),
        codigo: '${j['codigo'] ?? ''}',
        nombre: '${j['nombre'] ?? ''}',
        color: colorDesdeHex(j['color']),
      );

  String get etiqueta => '$codigo · $nombre';
}

/// Punto donde se reportó una demora publicada, con las rutas a las que puede estar afectando (la de la alerta y
/// las que pasan a 500 m). El punto de un pasajero llega redondeado a unos 110 m.
class DemoraMapa {
  final int alerta;
  final double lat;
  final double lng;
  final String descripcion;

  /// Ruta en la que se reportó.
  final String ruta;
  final String rutaCodigo;
  final String hace;

  /// Rutas a las que puede estar afectando.
  final List<int> rutas;

  /// Rutas de la propia alerta (no solo cercanas).
  final List<int> directas;

  const DemoraMapa({
    required this.alerta,
    required this.lat,
    required this.lng,
    required this.descripcion,
    required this.ruta,
    required this.rutaCodigo,
    required this.hace,
    required this.rutas,
    required this.directas,
  });

  factory DemoraMapa.fromJson(Map<String, dynamic> j) => DemoraMapa(
        alerta: _int(j['alerta']),
        lat: _num(j['lat']),
        lng: _num(j['lng']),
        descripcion: '${j['descripcion'] ?? ''}',
        ruta: '${j['ruta'] ?? ''}',
        rutaCodigo: '${j['ruta_codigo'] ?? ''}',
        hace: '${j['hace'] ?? ''}',
        rutas: [for (final r in j['rutas'] as List? ?? const []) _int(r)],
        directas: [for (final r in j['directas'] as List? ?? const []) _int(r)],
      );

  bool afecta(int rutaId) => rutas.contains(rutaId);

  /// Se reportó en esa ruta (y no solo cerca de ella).
  bool enRuta(int rutaId) => directas.contains(rutaId);
}

/// Aviso del tablero del mapa (alerta publicada y vigente).
class AvisoMapa {
  final int id;
  final String tipo;
  final String descripcion;
  final String ruta;
  final String hace;

  const AvisoMapa({required this.id, required this.tipo, required this.descripcion, required this.ruta, required this.hace});

  factory AvisoMapa.fromJson(Map<String, dynamic> j) => AvisoMapa(
        id: _int(j['id']),
        tipo: '${j['tipo'] ?? 'info'}',
        descripcion: '${j['descripcion'] ?? ''}',
        ruta: '${j['ruta'] ?? ''}',
        hace: '${j['hace'] ?? ''}',
      );
}
