import 'package:flutter/material.dart';

import 'screens/acerca_screen.dart';
import 'screens/alertas_screen.dart';
import 'screens/cuenta_screen.dart';
import 'screens/mapa_screen.dart';
import 'screens/rutas_screen.dart';
import 'services/mensajes.dart';
import 'services/navegacion.dart';
import 'services/notificaciones.dart';
import 'services/server_config.dart';
import 'services/sesion.dart';
import 'services/ventana_flotante.dart';
import 'theme/app_theme.dart';
import 'widgets/lb.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  VentanaFlotante.iniciar();
  await ServerConfig.cargar();
  await Sesion.i.cargar();
  runApp(const LocalBusApp());
  Notificaciones.i.iniciar();
  Sesion.i.refrescar();
}

class LocalBusApp extends StatelessWidget {
  const LocalBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) => MaterialApp(
        title: 'LocalBus',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        builder: (context, child) => MensajesHost(child: child ?? const SizedBox.shrink()),
        home: const Principal(),
      ),
    );
  }
}

/// Las mismas secciones del menú de la web, con la barra de navegación abajo.
class Principal extends StatefulWidget {
  const Principal({super.key});

  @override
  State<Principal> createState() => _PrincipalState();
}

class _PrincipalState extends State<Principal> {
  final _visitadas = <int>{Navegacion.mapa};

  @override
  void initState() {
    super.initState();
    Navegacion.pestana.addListener(_alCambiar);
    Navegacion.bienvenida.addListener(_alBienvenida);
    Sesion.i.addListener(_alCambiar);
  }

  @override
  void dispose() {
    Navegacion.pestana.removeListener(_alCambiar);
    Navegacion.bienvenida.removeListener(_alBienvenida);
    Sesion.i.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    if (!mounted) return;
    setState(() => _visitadas.add(Navegacion.pestana.value));
  }

  /// Primer inicio de sesión: seguir en el mapa o conocer LocalBus.
  void _alBienvenida() {
    if (!Navegacion.bienvenida.value || !mounted) return;
    Navegacion.bienvenida.value = false;
    final nombre = Sesion.i.usuario?.nombre ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      mostrarModal<void>(
        context,
        titulo: 'Te damos la bienvenida, $nombre',
        contenido: (c) => _Bienvenida(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    final actual = Navegacion.pestana.value;
    final usuario = Sesion.i.usuario;
    // Las pantallas se crean la primera vez que se visitan y después conservan su estado
    final pantallas = <Widget>[
      const MapaScreen(),
      _visitadas.contains(Navegacion.alertas) ? const AlertasScreen() : const SizedBox.shrink(),
      _visitadas.contains(Navegacion.rutas) ? const RutasScreen() : const SizedBox.shrink(),
      _visitadas.contains(Navegacion.acerca) ? const AcercaScreen() : const SizedBox.shrink(),
      _visitadas.contains(Navegacion.cuenta) ? const CuentaTab() : const SizedBox.shrink(),
    ];

    return PopScope(
      canPop: actual == Navegacion.mapa,
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho) Navegacion.ir(Navegacion.mapa);
      },
      child: Scaffold(
        body: IndexedStack(index: actual, children: pantallas),
        // En la ventana flotante solo cabe el mapa
        bottomNavigationBar: ValueListenableBuilder<bool>(
          valueListenable: VentanaFlotante.activa,
          builder: (context, flotante, barra) => flotante ? const SizedBox.shrink() : barra!,
          child: Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: lb.linea))),
          child: NavigationBar(
            selectedIndex: actual,
            onDestinationSelected: Navegacion.ir,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
              const NavigationDestination(
                  icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alertas'),
              const NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: 'Rutas'),
              const NavigationDestination(
                  icon: Icon(Icons.info_outline), selectedIcon: Icon(Icons.info), label: 'Acerca de'),
              usuario == null
                  ? const NavigationDestination(
                      icon: Icon(Icons.login_rounded), selectedIcon: Icon(Icons.login_rounded), label: 'Ingresar')
                  : NavigationDestination(
                      icon: AvatarIniciales(iniciales: usuario.iniciales, color: usuario.color, size: 26),
                      label: 'Mi perfil',
                    ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _Bienvenida extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lb = context.lb;
    Widget opcion(IconData icono, String titulo, String texto, VoidCallback alTocar) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: lb.blanco,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: lb.linea),
              borderRadius: BorderRadius.circular(AppTheme.radio),
            ),
            child: InkWell(
              onTap: alTocar,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(icono, size: 36, color: lb.azul),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(titulo, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: lb.tinta)),
                      const SizedBox(height: 2),
                      Text(texto, style: TextStyle(fontSize: 14, height: 1.35, color: lb.grisTexto)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Es tu primera vez en LocalBus. ¿Qué quieres hacer ahora?',
            style: TextStyle(fontSize: 15.5, height: 1.4, color: lb.tinta)),
        const SizedBox(height: 16),
        opcion(Icons.place_outlined, 'Seguir en el mapa', 'Mira las rutas y dónde van los buses en este momento.', () {
          Navigator.of(context).pop();
          Navegacion.ir(Navegacion.mapa);
        }),
        opcion(Icons.info_outline, 'Conocer LocalBus', 'Descubre qué es y cómo te ayuda a moverte por la ciudad.', () {
          Navigator.of(context).pop();
          Navegacion.ir(Navegacion.acerca);
        }),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(children: const [
            TextSpan(text: 'Cuando quieras, encuentras '),
            TextSpan(text: 'Acerca de', style: TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: ' en la barra de abajo.'),
          ]),
          style: TextStyle(fontSize: 13.5, color: lb.grisTexto),
        ),
      ],
    );
  }
}
