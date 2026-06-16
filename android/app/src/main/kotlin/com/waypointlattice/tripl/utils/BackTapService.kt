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
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.waypointlattice.tripl.ui.PopupActivity

class BackTapService : Service(), SensorEventListener {
    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    var detector: BackTapDetector? = null
    private var isSensorRegistered = false
    private var hapticsEnabled = true

    private val screenStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    Log.d(TAG, "Screen went off, pausing sensor to save battery")
                    unregisterSensor()
                }
                Intent.ACTION_USER_PRESENT -> {
                    Log.d(TAG, "Device unlocked, resuming sensor")
                    registerSensor()
                }
                Intent.ACTION_SCREEN_ON -> {
                    Log.d(TAG, "Screen turned on, resuming sensor")
                    registerSensor()
                }
            }
        }
    }

    companion object {
        private const val TAG = "TriplService"
        private const val CHANNEL_ID = "tripl_back_tap"
        private const val NOTIFICATION_ID = 8800
        const val DEFAULT_SENSITIVITY_MS = 400L

        // Live reference so MainActivity can update the detector window at runtime
        var instance: BackTapService? = null

        fun updateSensitivity(ms: Long) {
            instance?.detector?.tapWindowMaxMs = ms
            android.util.Log.d(TAG, "Sensitivity updated live to ${ms}ms")
        }

        fun updateHapticsEnabled(enabled: Boolean) {
            instance?.let {
                it.hapticsEnabled = enabled
                android.util.Log.d(TAG, "Haptics enabled updated live to $enabled")
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
            val raw = prefs.getInt("flutter.tap_sensitivity_ms", DEFAULT_SENSITIVITY_MS.toInt())
            // Clamp to valid range to guard against corrupted values
            raw.toLong().coerceIn(200L, 1000L)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load tap sensitivity, using default: ${e.message}")
            DEFAULT_SENSITIVITY_MS
        }
        Log.d(TAG, "Loaded tap sensitivity: ${savedMs}ms")

        hapticsEnabled = try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.getBoolean("flutter.haptics_enabled", true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load haptics preference, using default: ${e.message}")
            true
        }
        Log.d(TAG, "Loaded haptics enabled: $hapticsEnabled")

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        detector = BackTapDetector {
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            if (keyguardManager.isKeyguardLocked) {
                Log.d(TAG, "Triple tap detected, but device is locked. Ignoring.")
                return@BackTapDetector
            }

            Log.d(TAG, "Back tap gesture triggered!")
            triggerVibration()

            // Always notify MainActivity (used by calibration event stream)
            Log.d("TallyTapCalib", "BackTapService: triple tap complete, notifying MainActivity. calibrationMode=${com.waypointlattice.tripl.MainActivity.calibrationMode}")
            com.waypointlattice.tripl.MainActivity.onBackTapDetected()

            // Only launch/dismiss popup when NOT in calibration mode
            if (!com.waypointlattice.tripl.MainActivity.calibrationMode) {
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
        
        // Initial check
        checkAndRegisterSensor()
    }

    private fun triggerVibration() {
        if (!hapticsEnabled) {
            Log.d(TAG, "Vibration skipped: haptics are disabled in settings")
            return
        }
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

    private fun checkAndRegisterSensor() {
        // We now just register the sensor directly to handle unreliable ACTION_USER_PRESENT broadcasts
        registerSensor()
    }

    private fun registerSensor() {
        if (!isSensorRegistered) {
            accelerometer?.let {
                isSensorRegistered = sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) ?: false
                Log.d(TAG, "registerSensor: Accelerometer registered successfully? $isSensorRegistered")
            } ?: run {
                Log.e(TAG, "registerSensor: Accelerometer sensor not found on this device!")
            }
        }
    }
    
    private fun unregisterSensor() {
        if (isSensorRegistered) {
            sensorManager?.unregisterListener(this)
            isSensorRegistered = false
            Log.d(TAG, "unregisterSensor: Accelerometer unregistered")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: Service started sticky (startId: $startId)")
        return START_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy: Stopping Tripl Back Tap Service and unregistering sensor")
        instance = null
        try {
            unregisterReceiver(screenStateReceiver)
        } catch (e: IllegalArgumentException) {
            Log.e(TAG, "Receiver not registered", e)
        }
        unregisterSensor()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onSensorChanged(event: SensorEvent?) {
        if (event != null && event.sensor.type == Sensor.TYPE_ACCELEROMETER) {
            val x = event.values[0]
            val y = event.values[1]
            val z = event.values[2]
            detector?.processSensorEvent(x, y, z)
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
            Log.d(TAG, "createNotificationChannel: Channel created successfully")
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
