import 'package:flutter/material.dart';
import '../models/alerta.dart';
import '../models/ruta.dart';
import '../tema.dart';

/// Texto, tono e icono con que se muestra un estado o un tipo.
/// El color sale del tema (claro u oscuro) con `context.colores.de(etiqueta.tono)`.
class Etiqueta {
  final String texto;
  final Tono tono;
  final IconData icono;
  const Etiqueta(this.texto, this.tono, this.icono);
}

/// Estado de una ruta, con los colores de la web: activa verde, sin buses amarillo,
/// fuera de horario gris, fuera de servicio rojo.
Etiqueta etiquetaRuta(Ruta ruta) {
  switch (ruta.estado) {
    case Ruta.activa:
      return Etiqueta(ruta.estadoNombre, Tono.exito, Icons.check_circle_outline);
    case Ruta.sinBuses:
      return Etiqueta(ruta.estadoNombre, Tono.advertencia, Icons.portable_wifi_off);
    case Ruta.fueraServicio:
      return Etiqueta(ruta.estadoNombre, Tono.peligro, Icons.block);
    default:
      return Etiqueta(ruta.estadoNombre, Tono.neutro, Icons.schedule);
  }
}

/// Tipo de alerta: demora roja, advertencia amarilla, información azul.
Etiqueta etiquetaTipoAlerta(String tipo) {
  switch (tipo) {
    case Alerta.demora:
      return const Etiqueta('Demora', Tono.peligro, Icons.access_time);
    case Alerta.advertencia:
      return const Etiqueta('Advertencia', Tono.advertencia, Icons.warning_amber);
    default:
      return const Etiqueta('Información', Tono.accion, Icons.info_outline);
  }
}

/// Estado de una alerta publicada.
Etiqueta etiquetaEstadoAlerta(Alerta alerta) {
  if (alerta.estaResuelta) {
    return const Etiqueta('Resuelta', Tono.neutro, Icons.task_alt);
  }
  return const Etiqueta('En proceso', Tono.exito, Icons.radio_button_checked);
}
