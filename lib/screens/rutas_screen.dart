import 'package:flutter/material.dart';
import '../models/ruta.dart';
import '../services/api_service.dart';
import '../tema.dart';
import '../utils/estados.dart';
import '../utils/texto.dart';
import '../widgets/comunes.dart';

class RutasScreen extends StatefulWidget {
  /// Abre el mapa con esta ruta elegida.
  final ValueChanged<int> onVerEnMapa;

  const RutasScreen({super.key, required this.onVerEnMapa});

  @override
  State<RutasScreen> createState() => _RutasScreenState();
}

class _RutasScreenState extends State<RutasScreen> {
  /// Orden de los filtros de estado (null = todas).
  static const List<String?> _estados = [
    null,
    Ruta.activa,
    Ruta.sinBuses,
    Ruta.fueraHorario,
    Ruta.fueraServicio,
  ];

  final ApiService _apiService = ApiService();
  final TextEditingController _buscador = TextEditingController();
  List<Ruta> _rutas = [];
  bool _cargando = true;
  String? _error;

  String _busqueda = '';
  String? _empresa;
  String? _estado;

  @override
  void initState() {
    super.initState();
    _cargarRutas();
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _cargarRutas() async {
    setState(() {
      _cargando = _rutas.isEmpty;
      _error = null;
    });

    try {
      final rutas = await _apiService.obtenerRutas();
      if (mounted) {
        setState(() {
          _rutas = rutas;
          _cargando = false;
          // Si la empresa elegida ya no tiene rutas, se quita el filtro
          if (_empresa != null && !rutas.any((r) => r.empresa == _empresa)) _empresa = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _cargando = false;
        });
      }
    }
  }

  void _quitarFiltros() {
    _buscador.clear();
    setState(() {
      _busqueda = '';
      _empresa = null;
      _estado = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: barraSuperior(context, 'Rutas', acciones: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
          onPressed: _cargarRutas,
        ),
      ]),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_cargando) return const EstadoCargando('Cargando rutas…');

    if (_error != null && _rutas.isEmpty) {
      return EstadoError(
        titulo: 'No se pudieron cargar las rutas',
        mensaje: _error!,
        onReintentar: _cargarRutas,
      );
    }

    if (_rutas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: EstadoVacio('Todavía no hay rutas habilitadas. Cuando una empresa cree una, aparecerá aquí.'),
      );
    }

    // Búsqueda y empresa primero; los conteos de estado salen de ese resultado
    final candidatas = _rutas
        .where((r) => _empresa == null || r.empresa == _empresa)
        .where((r) => coincide(_busqueda, [r.codigo, r.nombre, r.origen, r.destino, r.empresa]))
        .toList();
    final visibles = candidatas.where((r) => _estado == null || r.estado == _estado).toList();

    return RefreshIndicator(
      onRefresh: _cargarRutas,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: visibles.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _filtros(candidatas, visibles.isEmpty);
          return _ficha(visibles[index - 1]);
        },
      ),
    );
  }

  Widget _filtros(List<Ruta> candidatas, bool sinResultados) {
    final c = context.colores;
    final empresas = _rutas.map((r) => r.empresa).where((e) => e.isNotEmpty).toSet().toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Si la última actualización falló, se avisa sin tapar las rutas que ya se tenían
        if (_error != null) EstadoVacio('No se pudo actualizar: $_error', accion: 'Reintentar', onAccion: _cargarRutas),
        TextField(
          controller: _buscador,
          textInputAction: TextInputAction.search,
          decoration: decoracionCampo(
            context,
            etiqueta: 'Buscar ruta',
            ayuda: 'Código, nombre, origen o destino',
            prefijo: const Icon(Icons.search),
            sufijo: _busqueda.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Borrar búsqueda',
                    onPressed: () {
                      _buscador.clear();
                      setState(() => _busqueda = '');
                    },
                  ),
          ),
          onChanged: (texto) => setState(() => _busqueda = texto),
        ),
        if (empresas.length > 1) ...[
          const SizedBox(height: 12),
          Desplegable<String?>(
            etiqueta: 'Empresa',
            valor: _empresa,
            opciones: {null: 'Todas las empresas', for (final e in empresas) e: e},
            alCambiar: (valor) => setState(() => _empresa = valor),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _estados.map((estado) {
            final cantidad = estado == null
                ? candidatas.length
                : candidatas.where((r) => r.estado == estado).length;
            final elegido = _estado == estado;
            return ChoiceChip(
              label: Text('${_nombreEstado(estado)} $cantidad'),
              labelStyle: TextStyle(
                color: elegido ? c.fondo : c.tinta,
                fontWeight: elegido ? FontWeight.w700 : FontWeight.w400,
              ),
              selected: elegido,
              selectedColor: c.tinta,
              backgroundColor: c.fondo,
              side: BorderSide(color: elegido ? c.tinta : c.linea),
              onSelected: (_) => setState(() => _estado = estado),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Divider(color: c.linea),
        const SizedBox(height: 16),
        if (sinResultados)
          EstadoVacio(
            'Ninguna ruta coincide con estos filtros.',
            accion: 'Quitar filtros',
            onAccion: _quitarFiltros,
          ),
      ],
    );
  }

  String _nombreEstado(String? estado) {
    if (estado == null) return 'Todas';
    switch (estado) {
      case Ruta.activa:
        return 'Activas';
      case Ruta.sinBuses:
        return 'Sin buses';
      case Ruta.fueraHorario:
        return 'Fuera de horario';
      case Ruta.fueraServicio:
        return 'Fuera de servicio';
      default:
        return estado;
    }
  }

  Widget _ficha(Ruta ruta) {
    final c = context.colores;
    final colorRuta = colorDeRuta(ruta.id);

    return Ficha(
      franjaSuperior: colorRuta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlacaRuta(codigo: ruta.codigo, rutaId: ruta.id, tamano: 17),
              const SizedBox(width: 10),
              Expanded(
                child: Text(ruta.nombre, style: estiloTitulo(size: 21, color: c.tinta)),
              ),
            ],
          ),
          if (ruta.empresa.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(ruta.empresa, style: TextStyle(fontSize: 13, color: c.grisTexto)),
          ],
          // La ruta activa es lo normal: no lleva insignia
          if (!ruta.estaActiva) ...[
            const SizedBox(height: 10),
            Insignia(etiquetaRuta(ruta)),
            if (ruta.motivo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(ruta.motivo, style: TextStyle(fontSize: 13, color: c.grisTexto)),
            ],
          ],
          const SizedBox(height: 14),
          Recorrido(origen: ruta.origen, destino: ruta.destino, color: colorRuta),
          const SizedBox(height: 14),
          Wrap(
            spacing: 28,
            runSpacing: 8,
            children: [
              DatoEtiquetado('Distancia', '${ruta.distanciaKm.toStringAsFixed(1).replaceAll('.', ',')} km'),
              DatoEtiquetado('Duración', '${ruta.duracionEstimadaMinutos} min'),
              DatoEtiquetado('Paradas', '${ruta.numParadas}'),
            ],
          ),
          const SizedBox(height: 12),
          if (ruta.tieneRecorrido)
            OutlinedButton.icon(
              onPressed: () => widget.onVerEnMapa(ruta.id),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Ver en el mapa'),
            )
          else
            Text('Sin recorrido trazado', style: TextStyle(fontSize: 13, color: c.grisTexto)),
        ],
      ),
    );
  }
}
