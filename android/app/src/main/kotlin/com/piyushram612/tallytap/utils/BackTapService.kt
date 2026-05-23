package com.piyushram612.tallytap.utils

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.piyushram612.tallytap.ui.PopupActivity

class BackTapService : Service(), SensorEventListener {
    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var detector: BackTapDetector? = null

    companion object {
        private const val TAG = "TallyTapService"
        private const val CHANNEL_ID = "tallytap_back_tap"
        private const val NOTIFICATION_ID = 8800
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate: Initializing TallyTap Back Tap Service")
        
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        
        detector = BackTapDetector {
            Log.d(TAG, "Back tap gesture triggered! Checking active popup instances...")
            
            // Toggle Behavior: If the popup is already visible, triple back-tap closes it.
            // Otherwise, it launches the popup.
            val dismissed = PopupActivity.dismissActiveInstance()
            if (dismissed) {
                Log.d(TAG, "Active popup instance successfully dismissed via re-trigger gesture")
            } else {
                Log.d(TAG, "No active popup found. Launching fresh PopupActivity...")
                try {
                    val popupIntent = Intent(this, PopupActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    startActivity(popupIntent)
                    Log.d(TAG, "PopupActivity startActivity call finished successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to launch PopupActivity from background: ${e.message}", e)
                }
            }
        }

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        registerSensor()
    }

    private fun registerSensor() {
        accelerometer?.let {
            val registered = sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
            Log.d(TAG, "registerSensor: Accelerometer registered successfully? $registered")
        } ?: run {
            Log.e(TAG, "registerSensor: Accelerometer sensor not found on this device!")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: Service started sticky (startId: $startId)")
        return START_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy: Stopping TallyTap Back Tap Service and unregistering sensor")
        sensorManager?.unregisterListener(this)
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
            val name = "TallyTap Sensor Service"
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
            .setContentTitle("TallyTap Gesture Active")
            .setContentText("Triple tap back of phone to capture expense")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }
}
