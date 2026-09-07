package com.waypointlattice.tripl.utils

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.waypointlattice.tripl.ui.PopupActivity
import com.waypointlattice.tripl.MainActivity
import io.flutter.plugin.common.MethodChannel
import android.content.ComponentName
import android.service.quicksettings.TileService
class BackTapService : Service(), SensorEventListener {
    private var sensorManager: SensorManager? = null
    private var motionSensor: Sensor? = null
    private var gyroSensor: Sensor? = null
    
    var detector: BackTapDetector? = null
    private var isSensorRegistered = false
    private var isGyroRegistered = false
    private var hapticsEnabled = true

    private val screenStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    Log.d(TAG, "Screen went off, pausing sensors to save battery")
                    unregisterSensors()
                }
                Intent.ACTION_USER_PRESENT, Intent.ACTION_SCREEN_ON -> {
                    Log.d(TAG, "Screen turned on/unlocked, resuming sensors")
                    registerSensors()
                }
            }
        }
    }

    companion object {
        private const val TAG = "TriplService"
        private const val CHANNEL_ID = "tripl_back_tap"
        private const val NOTIFICATION_ID = 8800
        const val DEFAULT_SENSITIVITY_MS = 400L

        var instance: BackTapService? = null

        fun updateSensitivity(ms: Long) {
            instance?.detector?.tapWindowMaxMs = ms
            Log.d(TAG, "Sensitivity updated live to ${ms}ms")
        }

        fun updateThresholds(force: Float, jerk: Float) {
            instance?.detector?.let {
                it.tapThreshold = force
                it.jerkThreshold = jerk
                Log.d(TAG, "Thresholds updated live to Force=$force, Jerk=$jerk")
            }
        }

        fun updateHapticsEnabled(enabled: Boolean) {
            instance?.let {
                it.hapticsEnabled = enabled
                Log.d(TAG, "Haptics enabled updated live to $enabled")
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "onCreate: Initializing Tripl Back Tap Service")

        // Load saved sensitivity from SharedPreferences
        val savedMs = try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val value = prefs.all["flutter.tap_sensitivity_ms"]
            val raw = when (value) {
                is Long -> value
                is Int -> value.toLong()
                is Float -> value.toLong()
                is Double -> value.toLong()
                is String -> value.toLongOrNull() ?: DEFAULT_SENSITIVITY_MS
                else -> DEFAULT_SENSITIVITY_MS
            }
            raw.coerceIn(300L, 800L)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load tap sensitivity, using default: ${e.message}")
            DEFAULT_SENSITIVITY_MS
        }
        Log.d(TAG, "Loaded tap sensitivity: ${savedMs}ms")

        hapticsEnabled = try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val value = prefs.all["flutter.haptics_enabled"]
            when (value) {
                is Boolean -> value
                is String -> value.toBoolean()
                else -> true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load haptics preference, using default: ${e.message}")
            true
        }

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        motionSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        gyroSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
        Log.d(TAG, "Sensors initialized. Gyro Available? ${gyroSensor != null}")

        val defaultForce = 2.5f
        val defaultJerk = 2.0f

        val savedForce = try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val value = prefs.all["flutter.tap_threshold"]
            val raw = when (value) {
                is Float -> value
                is Double -> value.toFloat()
                is Long -> value.toFloat()
                is Int -> value.toFloat()
                is String -> value.toFloatOrNull() ?: defaultForce
                else -> defaultForce
            }
            raw.coerceIn(2.2f, 4.5f)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load tap threshold, using default: ${e.message}")
            defaultForce
        }

        val savedJerk = try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val value = prefs.all["flutter.jerk_threshold"]
            val raw = when (value) {
                is Float -> value
                is Double -> value.toFloat()
                is Long -> value.toFloat()
                is Int -> value.toFloat()
                is String -> value.toFloatOrNull() ?: defaultJerk
                else -> defaultJerk
            }
            raw.coerceIn(1.5f, 2.2f)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load jerk threshold, using default: ${e.message}")
            defaultJerk
        }

        detector = BackTapDetector { force, jerk ->
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            if (keyguardManager.isKeyguardLocked) {
                Log.d(TAG, "Triple tap detected, but device is locked. Ignoring.")
                return@BackTapDetector
            }

            Log.d(TAG, "Back tap gesture triggered! Force=$force, Jerk=$jerk")
            triggerVibration()

            MainActivity.onBackTapDetected(force, jerk)

            if (!MainActivity.calibrationMode) {
                val dismissed = PopupActivity.dismissActiveInstance()
                if (dismissed) {
                    Log.d(TAG, "Active popup dismissed via re-trigger gesture")
                } else {
                    Log.d(TAG, "Launching fresh PopupActivity...")
                    try {
                        val popupIntent = Intent(this, PopupActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        }
                        startActivity(popupIntent)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to launch PopupActivity: ${e.message}", e)
                    }
                }
            }
        }

        detector?.tapWindowMaxMs = savedMs
        detector?.tapThreshold = savedForce
        detector?.jerkThreshold = savedJerk

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        
        // Register Broadcast Receiver for screen/lock state
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screenStateReceiver, filter)
        }
        
        registerSensors()

        // Notify Flutter of state change
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            MainActivity.flutterEngineInstance?.let { engine ->
                try {
                    MethodChannel(engine.dartExecutor.binaryMessenger, "com.waypointlattice.tripl/popup")
                        .invokeMethod("onBackTapStateChanged", true)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to send state change to Flutter: ${e.message}")
                }
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                TileService.requestListeningState(this, ComponentName(this, "com.waypointlattice.tripl.native.TriplTileService"))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to request tile listening state: ${e.message}")
            }
        }
    }


    private fun triggerVibration() {
        if (!hapticsEnabled) return
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as android.os.VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(android.os.VibrationEffect.createOneShot(150, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(150)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to vibrate: ${e.message}")
        }
    }

    private fun registerSensors() {
        if (!isSensorRegistered) {
            motionSensor?.let {
                isSensorRegistered = sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) ?: false
                Log.d(TAG, "registerSensors: Accelerometer registered successfully: $isSensorRegistered")
            }
        }
        if (!isGyroRegistered) {
            gyroSensor?.let {
                isGyroRegistered = sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) ?: false
                Log.d(TAG, "registerSensors: Gyroscope sensor registered: $isGyroRegistered")
            }
        }
    }
    
    private fun unregisterSensors() {
        if (isSensorRegistered) {
            sensorManager?.unregisterListener(this, motionSensor)
            isSensorRegistered = false
            Log.d(TAG, "unregisterSensors: Accelerometer unregistered")
        }
        if (isGyroRegistered && !MainActivity.calibrationMode) {
            sensorManager?.unregisterListener(this, gyroSensor)
            isGyroRegistered = false
            Log.d(TAG, "unregisterSensors: Gyroscope unregistered")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: Service started sticky (startId: $startId)")
        return START_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy: Stopping Tripl Back Tap Service")
        instance = null
        try {
            unregisterReceiver(screenStateReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error cleaning up screenStateReceiver: ${e.message}")
        }
        unregisterSensors()

        android.os.Handler(android.os.Looper.getMainLooper()).post {
            MainActivity.flutterEngineInstance?.let { engine ->
                try {
                    MethodChannel(engine.dartExecutor.binaryMessenger, "com.waypointlattice.tripl/popup")
                        .invokeMethod("onBackTapStateChanged", false)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to send state change to Flutter: ${e.message}")
                }
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                TileService.requestListeningState(this, ComponentName(this, "com.waypointlattice.tripl.native.TriplTileService"))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to request tile listening state: ${e.message}")
            }
        }

        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onSensorChanged(event: SensorEvent?) {
        if (event != null) {
            when (event.sensor.type) {
                Sensor.TYPE_ACCELEROMETER -> {
                    detector?.processSensorEvent(event.values[0], event.values[1], event.values[2])
                }
                Sensor.TYPE_GYROSCOPE -> {
                    detector?.processGyroEvent(event.values[0], event.values[1], event.values[2])
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Tripl Sensor Service"
            val desc = "Listens for physical triple taps on the phone back casing"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = desc
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val popupIntent = Intent(this, PopupActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            popupIntent,
            pendingIntentFlags
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Tripl Gesture Active")
            .setContentText("Triple tap back of phone to capture expense")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }
}
