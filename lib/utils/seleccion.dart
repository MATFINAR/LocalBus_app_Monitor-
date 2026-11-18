import 'package:flutter/foundation.dart';

/// Ruta elegida para ver en el mapa. La comparten las pestañas: "Ver en el mapa" desde Rutas o
/// Alertas la elige, y el mapa dibuja solo esa ruta, sus paradas, sus buses y sus alertas.
///
/// Avisa aunque se elija la misma ruta otra vez: así el mapa vuelve a encuadrarla.
class SeleccionRuta extends ChangeNotifier {
  int? _rutaId;

  /// null = todas las rutas.
  int? get rutaId => _rutaId;

  void elegir(int? rutaId) {
    _rutaId = rutaId;
    notifyListeners();
  }
}
