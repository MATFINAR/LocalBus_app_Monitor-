import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ventana flotante del mapa (imagen en imagen de Android, como en Google Maps). El lado de Android está en
/// MainActivity.kt. En otras plataformas no hace nada.
class VentanaFlotante {
  VentanaFlotante._();

  static const MethodChannel canal = MethodChannel('localbus/ventana_flotante');

  /// La app se está viendo en la ventana flotante: solo debe mostrarse el mapa.
  static final ValueNotifier<bool> activa = ValueNotifier(false);

  static bool _permitida = false;

  /// Llamar una vez antes de `runApp`.
  static void iniciar() {
    canal.setMethodCallHandler((llamada) async {
      if (llamada.method == 'cambio') activa.value = llamada.arguments == true;
    });
  }

  /// Si es `true`, al salir de la app el mapa queda en la ventana flotante.
  static Future<void> permitir(bool valor) async {
    if (valor == _permitida) return;
    _permitida = valor;
    try {
      await canal.invokeMethod<void>('permitir', valor);
    } on MissingPluginException {
      // Plataforma sin ventana flotante
    }
  }
}
