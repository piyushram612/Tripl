package com.waypointlattice.tripl

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.provider.Settings
import android.net.Uri
import android.widget.Toast
import com.waypointlattice.tripl.ui.PopupActivity
import com.waypointlattice.tripl.utils.BackTapService

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.waypointlattice.tripl/popup"
    private val EVENT_CHANNEL = "com.waypointlattice.tripl/backtap_events"

    companion object {
        // When true, back taps go to the event stream (calibration) instead of PopupActivity
        var calibrationMode = false
        var backTapEventSink: EventChannel.EventSink? = null
        var flutterEngineInstance: FlutterEngine? = null

        fun onBackTapDetected() {
            android.util.Log.d("TallyTapCalib", "onBackTapDetected: calibrationMode=$calibrationMode sink=$backTapEventSink")
            if (calibrationMode) {
                // EventSink.success() must be called on the main thread
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    if (backTapEventSink != null) {
                        android.util.Log.d("TallyTapCalib", "Sending tap event to Flutter event channel")
                        backTapEventSink?.success("tap")
                    } else {
                        android.util.Log.w("TallyTapCalib", "Sink is null! Flutter has not subscribed to the event channel yet.")
                    }
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent != null && intent.getStringExtra("navigate") == "create_transaction") {
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                flutterEngineInstance?.let { engine ->
                    android.util.Log.d("MainActivity", "Invoking navigate/create_transaction channel call to Flutter")
                    MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                        .invokeMethod("navigate", "create_transaction")
                }
            }, 600) // 600ms delay to ensure Flutter app state is active
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngineInstance = flutterEngine

        // ── Method Channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showPopup" -> {
                    val intent = Intent(this, PopupActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    startActivity(intent)
                    result.success(null)
                }
                "setBackTapEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    toggleBackTapService(enabled)
                    result.success(null)
                }
                "setCalibrationMode" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    calibrationMode = enabled
                    if (enabled) {
                        // Always start the sensor service during calibration so the
                        // accelerometer is guaranteed to be listening, even if the
                        // user hasn't toggled back tap on in Settings yet.
                        startBackTapService()
                    } else {
                        // When calibration ends, stop the service only if the user
                        // hasn't permanently enabled back tap in Settings.
                        val prefs = getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE)
                        val userEnabled = prefs.getBoolean("flutter.back_tap_enabled", false)
                        if (!userEnabled) {
                            stopService(Intent(this, BackTapService::class.java))
                        }
                    }
                    result.success(null)
                }
                "setSensitivity" -> {
                    val ms = (call.argument<Int>("ms") ?: BackTapService.DEFAULT_SENSITIVITY_MS.toInt()).toLong()
                    // Update the running detector immediately
                    BackTapService.updateSensitivity(ms)
                    // Also persist so next service start picks it up
                    val prefs = getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE)
                    prefs.edit().putInt("flutter.tap_sensitivity_ms", ms.toInt()).apply()
                    result.success(null)
                }
                "setHapticsEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    // Update the running service immediately
                    BackTapService.updateHapticsEnabled(enabled)
                    // Also persist so next service start picks it up
                    val prefs = getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("flutter.haptics_enabled", enabled).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ── Event Channel (streams back tap signals to Flutter) ──
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    backTapEventSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    backTapEventSink = null
                }
            })
    }

    private fun startBackTapService() {
        val serviceIntent = Intent(this, BackTapService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun toggleBackTapService(enabled: Boolean) {
        if (enabled) {
            checkAndRequestNotificationPermission()
            
            // Check for System Alert Window Overlay permission on Android M+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                Toast.makeText(
                    this,
                    "Please enable 'Display over other apps' to allow Back Tap triggers from Home Screen",
                    Toast.LENGTH_LONG
                ).show()
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                startActivity(intent)
            }
            
            startBackTapService()
        } else {
            stopService(Intent(this, BackTapService::class.java))
        }
    }

    private fun checkAndRequestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 101)
            }
        }
    }
}
