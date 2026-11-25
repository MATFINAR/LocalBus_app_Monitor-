import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'mensajes.dart';
import 'navegacion.dart';
import 'server_config.dart';

/// Avisos de alertas nuevas, como notificaciones.js de la web: cada 20 s pregunta por las alertas publicadas
/// desde la última vista. Con la app abierta las muestra abajo; con la app en segundo plano, y si la persona
/// lo permitió («Activar notificaciones»), como notificación del celular. Con sesión, solo las de las rutas
/// que sigue.
class Notificaciones with WidgetsBindingObserver {
  Notificaciones._();
  static final Notificaciones i = Notificaciones._();

  static const _intervalo = Duration(seconds: 20);
  static const _claveCursor = 'alertas_cursor';
  static const _claveAvisadas = 'alertas_avisadas';
  static const _clavePreguntado = 'notificaciones_preguntado';
  static const _iconos = {'delay': '⏰', 'warning': '⚠️', 'info': 'ℹ️'};

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// granted (activadas), denied (bloqueadas) o default (sin preguntar).
  final ValueNotifier<String> permiso = ValueNotifier('default');

  Timer? _temporizador;
  bool _enFrente = true;
  bool _preguntado = false;
  String? _cursor;
  List<int> _avisadas = [];
  bool _listo = false;

  Future<void> iniciar() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (_) => Navegacion.ir(Navegacion.alertas),
      );
      _listo = true;
    } catch (e) {
      debugPrint('Sin notificaciones del sistema: $e');
    }
    WidgetsBinding.instance.addObserver(this);
    try {
      final prefs = await SharedPreferences.getInstance();
      _cursor = prefs.getString(_claveCursor);
      _avisadas = (prefs.getStringList(_claveAvisadas) ?? []).map(int.tryParse).whereType<int>().toList();
      _preguntado = prefs.getBool(_clavePreguntado) ?? false;
    } catch (_) {}
    await _actualizarPermiso();
    ServerConfig.cambios.addListener(_alCambiarServidor);
    _revisar();
    _temporizador = Timer.periodic(_intervalo, (_) => _revisar());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    _enFrente = estado == AppLifecycleState.resumed;
    if (_enFrente) _actualizarPermiso();
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
  }

  void _alCambiarServidor() {
    _cursor = null;
    _avisadas = [];
    _revisar();
  }

  Future<void> _revisar() async {
    try {
      final d = await Api.get('notificaciones/', q: _cursor == null ? null : {'publicadas_desde': _cursor!});
      final inicial = _cursor == null;
      final lista = (d['alertas'] as List? ?? []).whereType<Map>().toList();
      final nuevas = inicial ? <Map>[] : lista.where((a) => !_avisadas.contains(a['id'])).toList();
      final cursor = d['cursor'] as String?;
      if (cursor != null && (_cursor == null || cursor.compareTo(_cursor!) > 0)) _cursor = cursor;
      _avisadas = [..._avisadas, ...nuevas.map((a) => a['id']).whereType<int>()];
      if (_avisadas.length > 100) _avisadas = _avisadas.sublist(_avisadas.length - 100);
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_cursor != null) await prefs.setString(_claveCursor, _cursor!);
        await prefs.setStringList(_claveAvisadas, _avisadas.map((e) => '$e').toList());
      } catch (_) {}

      // Las más antiguas primero; como mucho 3 avisos a la vez
      final mostrar = nuevas.reversed.toList();
      for (final a in mostrar.sublist(mostrar.length > 3 ? mostrar.length - 3 : 0)) {
        final titulo = '${_iconos[a['tipo']] ?? '🚨'} Nueva alerta · ${a['ruta']}';
        final texto = '${a['descripcion'] ?? ''}';
        Mensajes.alerta(titulo, texto, () => Navegacion.ir(Navegacion.alertas));
        if (!_enFrente && permiso.value == 'granted' && _listo) {
          await _plugin.show(
            id: (a['id'] as int?) ?? 0,
            title: '🚨 Nueva alerta · ${a['ruta']}',
            body: texto,
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'alertas',
                'Alertas de las rutas',
                channelDescription: 'Avisos cuando se publica una alerta nueva',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );
        }
      }
    } catch (_) {
      // Sin conexión: se reintenta en la próxima vuelta
    }
  }

  void detener() => _temporizador?.cancel();
}
