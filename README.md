# LocalBus Monitor

App Flutter para ver en vivo los buses, las rutas y las alertas de LocalBus. Lee la API pública
del backend Django (`LocalBus_django`); no necesita iniciar sesión.

| Pestaña | Endpoint | Frecuencia |
|---|---|---|
| Mapa | `GET /api/ubicaciones/` y `GET /api/rutas/` | buses cada 5 s, rutas cada minuto |
| Rutas | `GET /api/rutas/` | al abrir y al deslizar para actualizar |
| Alertas | `GET /api/alertas/` | al abrir y al deslizar para actualizar |

## Ejecutar

1. Arranca Django escuchando en la red, no solo en localhost:

   ```bash
   python manage.py runserver 0.0.0.0:8000
   ```

2. Agrega la IP del computador a `DJANGO_ALLOWED_HOSTS` en el `.env` de Django
   (por ejemplo `DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,192.168.1.50`). Si falta, Django
   responde 400 y la app lo avisa.

3. Ejecuta la app indicando la dirección del servidor:

   ```bash
   flutter pub get
   flutter run --dart-define=API_URL=http://192.168.1.50:8000
   ```

   Sin `--dart-define` usa `http://192.168.20.59:8000` (ver `lib/config.dart`).

## Pruebas

```bash
flutter test
```

Prueban la lectura de las respuestas de la API (modelos) y el formato de fechas.

## Diseño

Sigue la guía de diseño de LocalBus (`docs/GUIA_DE_DISENO.md` del proyecto): blanco predominante
con negro, azul y rojo de la marca; verde y amarillo solo como estado; cada ruta con su color de
placa (`id % 7`, la misma paleta de la web); Barlow Condensed en títulos y placas, Atkinson
Hyperlegible en el texto; esquinas de 3 y 4 px, líneas de 1 px y sin sombras salvo en lo que flota
sobre el mapa. Tema claro u oscuro según el dispositivo.

Las tipografías se descargan de Google Fonts (`google_fonts`) la primera vez que se abre la app
con internet y quedan guardadas; sin conexión se usa la fuente del sistema.

## Estructura

- `lib/tema.dart`: colores (claro y oscuro), paleta de rutas, tipografías y tema.
- `lib/widgets/comunes.dart`: placa de ruta, insignias, fichas, campos y estados de carga, error y vacío.
- `lib/config.dart`: dirección del servidor e intervalos de consulta.
- `lib/services/api_service.dart`: peticiones a la API y mensajes de error.
- `lib/models/`: `Ruta`, `Alerta`, `BusUbicacion`.
- `lib/screens/`: mapa, rutas y alertas.
- `lib/utils/`: formato de fechas y etiquetas de estado.
