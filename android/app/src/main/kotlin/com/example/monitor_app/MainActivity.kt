package com.example.monitor_app

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Ventana flotante del mapa (imagen en imagen, como en Google Maps). La app avisa cuándo está permitida
 * (hay una ruta fijada en el mapa) y aquí se entra en ella al salir de la app.
 */
class MainActivity : FlutterActivity() {
    private var canal: MethodChannel? = null
    private var permitida = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        canal = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "localbus/ventana_flotante").apply {
            setMethodCallHandler { llamada, resultado ->
                if (llamada.method == "permitir") {
                    permitida = llamada.arguments == true
                    // Desde Android 12 el sistema entra solo al salir de la app
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && disponible()) {
                        runCatching { setPictureInPictureParams(parametros()) }
                    }
                    resultado.success(null)
                } else {
                    resultado.notImplemented()
                }
            }
        }
    }

    private fun disponible() = packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    @RequiresApi(Build.VERSION_CODES.O)
    private fun parametros(): PictureInPictureParams {
        val parametros = PictureInPictureParams.Builder().setAspectRatio(Rational(3, 4))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            parametros.setAutoEnterEnabled(permitida)
            parametros.setSeamlessResizeEnabled(false)
        }
        return parametros.build()
    }

    // Android 8 a 11: hay que entrar a mano cuando la persona sale de la app
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (permitida && disponible() &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && Build.VERSION.SDK_INT < Build.VERSION_CODES.S
        ) {
            runCatching { enterPictureInPictureMode(parametros()) }
        }
    }

    override fun onPictureInPictureModeChanged(enVentana: Boolean, configuracion: Configuration) {
        super.onPictureInPictureModeChanged(enVentana, configuracion)
        canal?.invokeMethod("cambio", enVentana)
    }
}
