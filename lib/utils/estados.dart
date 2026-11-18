import 'package:flutter/material.dart';
import '../models/alerta.dart';
import '../models/ruta.dart';

/// Texto, color e icono con que se muestra un estado o un tipo.
class Etiqueta {
  final String texto;
  final Color color;
  final IconData icono;
  const Etiqueta(this.texto, this.color, this.icono);
}

/// Estado de una ruta. El color nunca va solo: siempre acompaña al texto.
Etiqueta etiquetaRuta(Ruta ruta) {
  switch (ruta.estado) {
    case Ruta.activa:
      return Etiqueta(ruta.estadoNombre, Colors.green.shade700, Icons.check_circle_outline);
    case Ruta.sinBuses:
      return Etiqueta(ruta.estadoNombre, Colors.amber.shade800, Icons.portable_wifi_off);
    case Ruta.fueraServicio:
      return Etiqueta(ruta.estadoNombre, Colors.red.shade700, Icons.block);
    default:
      return Etiqueta(ruta.estadoNombre, Colors.blueGrey, Icons.schedule);
  }
}

/// Tipo de alerta: demora, advertencia o información.
Etiqueta etiquetaTipoAlerta(String tipo) {
  switch (tipo) {
    case Alerta.demora:
      return Etiqueta('Demora', Colors.red.shade700, Icons.access_time);
    case Alerta.advertencia:
      return Etiqueta('Advertencia', Colors.amber.shade800, Icons.warning_amber);
    default:
      return Etiqueta('Información', Colors.blue.shade700, Icons.info_outline);
  }
}

/// Estado de una alerta publicada.
Etiqueta etiquetaEstadoAlerta(Alerta alerta) {
  if (alerta.estaResuelta) {
    return const Etiqueta('Resuelta', Colors.blueGrey, Icons.task_alt);
  }
  return Etiqueta('En proceso', Colors.green.shade700, Icons.radio_button_checked);
}
