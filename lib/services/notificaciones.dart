import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'api.dart';
import 'mensajes.dart';
import 'navegacion.dart';
import 'server_config.dart';
import 'sesion.dart';

/// Lo que Android ejecuta de vez en cuando con la app cerrada: trae las alertas que no han llegado y las pone
/// en la barra de notificaciones. Corre aparte de la app, por eso vuelve a cargar el servidor y la sesión.
@pragma('vm:entry-point')
void tareaDeAlertas() {
  Workmanager().executeTask((tarea, datos) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await ServerConfig.cargar();
    await Sesion.i.cargar();
    await Notificaciones.i.revisarCerrada();
    return true;
  });
}

/// Avisos de alertas nuevas, como notificaciones.js de la web: pregunta por las alertas publicadas desde la
/// última vista (con la app abierta cada 20 s; cerrada, cada 15 min o cuando Android lo permita). Toda alerta
/// nueva va a la barra de notificaciones; si todavía no hay permiso queda pendiente y llega al darlo. Con la
/// app abierta se muestra además abajo. Con sesión, el servidor solo entrega las de las rutas que sigue.
class Notificaciones with WidgetsBindingObserver {
  Notificaciones._();
  static final Notificaciones i = Notificaciones._();

  static const _intervalo = Duration(seconds: 20);
  static const _claveCursor = 'alertas_cursor';
  static const _claveAvisadas = 'alertas_avisadas';
  static const _clavePendientes = 'alertas_pendientes';
  static const _clavePreguntado = 'notificaciones_preguntado';
  static const _iconos = {'delay': '⏰', 'warning': '⚠️', 'info': 'ℹ️'};

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// Aumenta cada vez que llegan alertas nuevas con la app abierta (el mapa pone al día su tablero).
  final ValueNotifier<int> llegaron = ValueNotifier(0);

  /// granted (activadas), denied (bloqueadas) o default (sin preguntar).
  final ValueNotifier<String> permiso = ValueNotifier('default');

  Timer? _temporizador;
  bool _preguntado = false;
  bool _listo = false;
  Future<void>? _enCurso;

  /// Pone una notificación en la barra del celular. Las pruebas lo reemplazan.
  @visibleForTesting
  Future<void> Function(int id, String titulo, String texto)? enBarra;

  Future<void> iniciar() async {
    await _prepararPlugin();
    WidgetsBinding.instance.addObserver(this);
    try {
      final prefs = await SharedPreferences.getInstance();
      _preguntado = prefs.getBool(_clavePreguntado) ?? false;
    } catch (_) {}
    await _actualizarPermiso();
    ServerConfig.cambios.addListener(_alCambiarServidor);
    revisar();
    _temporizador = Timer.periodic(_intervalo, (_) => revisar());
    await _programarEnSegundoPlano();
    // La app se abrió tocando una notificación
    try {
      final origen = _listo ? await _plugin.getNotificationAppLaunchDetails() : null;
      if (origen?.didNotificationLaunchApp ?? false) Navegacion.ir(Navegacion.alertas);
    } catch (_) {}
  }

  Future<void> _prepararPlugin() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_notificacion')),
        onDidReceiveNotificationResponse: (_) => Navegacion.ir(Navegacion.alertas),
      );
      _listo = true;
    } catch (e) {
      debugPrint('Sin notificaciones del sistema: $e');
    }
  }

  Future<void> _programarEnSegundoPlano() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Workmanager().initialize(tareaDeAlertas);
      await Workmanager().registerPeriodicTask(
        'localbus_alertas',
        'alertas',
        frequency: const Duration(minutes: 15), // el mínimo que permite Android
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint('Sin avisos con la app cerrada: $e');
    }
  }

  /// Una sola revisión, sin pantalla (ver [tareaDeAlertas]).
  Future<void> revisarCerrada() async {
    await _prepararPlugin();
    await _actualizarPermiso();
    await revisar(enPantalla: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // Al volver se trae enseguida lo que no haya llegado
    if (estado == AppLifecycleState.resumed) _actualizarPermiso().then((_) => revisar());
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> _actualizarPermiso() async {
    if (!_listo) return;
    try {
      final activas = await _android?.areNotificationsEnabled() ?? false;
      permiso.value = activas ? 'granted' : (_preguntado ? 'denied' : 'default');
    } catch (_) {}
  }

  /// «Activar notificaciones»: pide el permiso del celular.
  Future<void> activar() async {
    if (!_listo) return;
    try {
      await _android?.requestNotificationsPermission();
    } catch (_) {}
    _preguntado = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_clavePreguntado, true);
    } catch (_) {}
    await _actualizarPermiso();
    await revisar(); // entrega las que estaban esperando el permiso
  }

  Future<void> _alCambiarServidor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final clave in [_claveCursor, _claveAvisadas, _clavePendientes]) {
        await prefs.remove(clave);
      }
    } catch (_) {}
    await revisar();
  }

  /// Busca alertas nuevas y entrega a la barra las que falten. Nunca hay dos revisiones a la vez.
  Future<void> revisar({bool enPantalla = true}) =>
      _enCurso ??= _revisar(enPantalla).whenComplete(() => _enCurso = null);

  Future<void> _revisar(bool enPantalla) async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // la tarea con la app cerrada pudo avanzar
    } catch (_) {
      return;
    }

    try {
      var cursor = prefs.getString(_claveCursor);
      final d = await Api.get('notificaciones/', q: cursor == null ? null : {'publicadas_desde': cursor});
      final inicial = cursor == null; // la primera vez solo se marca el punto de partida
      final avisadas = (prefs.getStringList(_claveAvisadas) ?? []).toList();
      final nuevas = inicial
          ? <Map>[]
          : (d['alertas'] as List? ?? [])
              .whereType<Map>()
              .where((a) => !avisadas.contains('${a['id']}'))
              .toList()
              .reversed // las más antiguas primero
              .toList();
      final recibido = d['cursor'] as String?;
      if (recibido != null && (cursor == null || recibido.compareTo(cursor) > 0)) cursor = recibido;

      if (nuevas.isNotEmpty) {
        await prefs.setStringList(_clavePendientes,
            _ultimas([...prefs.getStringList(_clavePendientes) ?? [], ...nuevas.map(jsonEncode)], 50));
        await prefs.setStringList(_claveAvisadas, _ultimas([...avisadas, ...nuevas.map((a) => '${a['id']}')], 100));
      }
      if (cursor != null) await prefs.setString(_claveCursor, cursor);

      // Abajo en la app, como mucho 3 a la vez; a la barra van todas
      if (enPantalla && nuevas.isNotEmpty) llegaron.value++;
      if (enPantalla) {
        for (final a in nuevas.sublist(nuevas.length > 3 ? nuevas.length - 3 : 0)) {
          Mensajes.alerta('${_iconos[a['tipo']] ?? '🚨'} Nueva alerta · ${a['ruta']}', '${a['descripcion'] ?? ''}',
              () => Navegacion.ir(Navegacion.alertas));
        }
      }
    } catch (_) {
      // Sin conexión: se reintenta en la próxima vuelta
    }

    await _entregar(prefs);
  }

  static List<String> _ultimas(List<String> lista, int maximo) =>
      lista.length > maximo ? lista.sublist(lista.length - maximo) : lista;

  /// Pasa a la barra de notificaciones las alertas que aún no han llegado allí.
  Future<void> _entregar(SharedPreferences prefs) async {
    final mostrar = enBarra ?? (_listo ? _mostrarEnBarra : null);
    if (mostrar == null || permiso.value != 'granted') return;
    final pendientes = (prefs.getStringList(_clavePendientes) ?? []).toList();
    final entregadas = <String>[];
    while (pendientes.isNotEmpty) {
      try {
        final a = jsonDecode(pendientes.first) as Map<String, dynamic>;
        await mostrar((a['id'] as num?)?.toInt() ?? 0, '🚨 Nueva alerta · ${a['ruta']}', '${a['descripcion'] ?? ''}');
      } catch (e) {
        debugPrint('No se pudo notificar: $e');
        return; // se intenta de nuevo en la próxima vuelta
      }
      entregadas.add(pendientes.removeAt(0));
      await prefs.setStringList(_clavePendientes, pendientes);
    }
    if (entregadas.isNotEmpty && enBarra == null) await _resumen(entregadas);
  }

  static const _grupo = 'localbus_alertas';
  static const _idResumen = 2147483000;

  /// Las alertas van en un grupo y solo el resumen avisa con sonido: si llegan muchas juntas (por ejemplo, después
  /// de estar sin conexión) el celular suena una vez y no una por alerta.
  Future<void> _resumen(List<String> entregadas) async {
    final titulos = <String>[];
    for (final t in entregadas) {
      try {
        titulos.add('${(jsonDecode(t) as Map)['ruta']}');
      } catch (_) {}
    }
    final texto = entregadas.length == 1 ? 'Nueva alerta · ${titulos.first}' : '${entregadas.length} alertas nuevas';
    try {
      await _plugin.show(
        id: _idResumen,
        title: '🚨 $texto',
        body: titulos.join(' · '),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'alertas',
            'Alertas de las rutas',
            channelDescription: 'Avisos cuando se publica una alerta nueva',
            importance: Importance.high,
            priority: Priority.high,
            groupKey: _grupo,
            setAsGroupSummary: true,
            groupAlertBehavior: GroupAlertBehavior.summary,
            styleInformation: InboxStyleInformation(titulos, summaryText: texto),
          ),
        ),
      );
    } catch (e) {
      debugPrint('No se pudo agrupar las notificaciones: $e');
    }
  }

  Future<void> _mostrarEnBarra(int id, String titulo, String texto) => _plugin.show(
        id: id,
        title: titulo,
        body: texto,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'alertas',
            'Alertas de las rutas',
            channelDescription: 'Avisos cuando se publica una alerta nueva',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(texto), // el texto completo al desplegarla
            groupKey: _grupo,
            groupAlertBehavior: GroupAlertBehavior.summary, // suena el resumen, no cada una
          ),
        ),
      );

  void detener() => _temporizador?.cancel();
}
