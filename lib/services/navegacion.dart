import 'package:flutter/foundation.dart';

/// Pedido de abrir el formulario de alertas desde otra pantalla (el botón «Reportar» del mapa).
class PedidoReportar {
  PedidoReportar(this.rutaId) : n = _siguiente++;
  static int _siguiente = 0;

  /// Ruta fijada en el mapa (va preseleccionada si pasa cerca), o null.
  final int? rutaId;
  final int n;
}

/// Pestañas de la barra inferior y saltos entre pantallas, como los enlaces del menú de la web.
class Navegacion {
  Navegacion._();

  static const int mapa = 0;
  static const int alertas = 1;
  static const int rutas = 2;
  static const int acerca = 3;
  static const int cuenta = 4;

  static final ValueNotifier<int> pestana = ValueNotifier(mapa);

  /// La pestaña Cuenta muestra el registro en vez del inicio de sesión.
  static final ValueNotifier<int> pedidoRegistro = ValueNotifier(0);

  static final ValueNotifier<PedidoReportar?> pedidoReportar = ValueNotifier(null);

  /// Primer inicio de sesión: el mapa pregunta si seguir ahí o conocer LocalBus (una sola vez).
  static final ValueNotifier<bool> bienvenida = ValueNotifier(false);

  static void ir(int destino) => pestana.value = destino;

  static void reportar(int? rutaId) {
    pedidoReportar.value = PedidoReportar(rutaId);
    ir(alertas);
  }

  static void registrarse() {
    pedidoRegistro.value++;
    ir(cuenta);
  }
}
