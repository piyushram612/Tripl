package com.waypointlattice.tripl.utils

import android.animation.ValueAnimator
import android.annotation.SuppressLint
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
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import androidx.core.app.NotificationCompat
import com.waypointlattice.tripl.MainActivity
import com.waypointlattice.tripl.ui.PopupActivity
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.max

class CameraTapService : Service() {

    private var windowManager: WindowManager? = null
    private var overlayView: CameraTapOverlayView? = null
    private var currentPositionMode = "auto"
    private var hapticsEnabled = true

    private val mainHandler = Handler(Looper.getMainLooper())

    private val screenStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    Log.d(TAG, "Screen off, hiding camera overlay")
                    overlayView?.visibility = View.GONE
                }
                Intent.ACTION_SCREEN_ON, Intent.ACTION_USER_PRESENT -> {
                    Log.d(TAG, "Screen on, displaying camera overlay")
                    overlayView?.visibility = View.VISIBLE
                }
            }
        }
    }

    companion object {
        private const val TAG = "CameraTapService"
        private const val CHANNEL_ID = "tripl_camera_tap"
        private const val NOTIFICATION_ID = 8801
        private const val TAP_WINDOW_MS = 500L

        var instance: CameraTapService? = null

        fun updatePosition(position: String) {
            instance?.let { service ->
                service.currentPositionMode = position
                service.mainHandler.post {
                    service.relayoutOverlay()
                }
            }
        }

        fun updateHapticsEnabled(enabled: Boolean) {
            instance?.hapticsEnabled = enabled
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "onCreate: Initializing Camera Cutout Tap Service")

        loadPreferences()
        createNotificationChannel()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    createNotification(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NOTIFICATION_ID, createNotification())
            }
        } else {
            startForeground(NOTIFICATION_ID, createNotification())
        }

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

        setupOverlay()
        notifyFlutterState(true)
    }

    private fun loadPreferences() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val pos = prefs.all["flutter.camera_cutout_position"]
            currentPositionMode = when (pos) {
                is String -> pos
                else -> "auto"
            }

            val hapticsVal = prefs.all["flutter.haptics_enabled"]
            hapticsEnabled = when (hapticsVal) {
                is Boolean -> hapticsVal
                is String -> hapticsVal.toBoolean()
                else -> true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading preferences: ${e.message}")
        }
    }

    private fun setupOverlay() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            Log.w(TAG, "Cannot draw overlays: SYSTEM_ALERT_WINDOW permission not granted")
            return
        }

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        overlayView = CameraTapOverlayView(this).apply {
            onTripleTapListener = {
                handleCameraTripleTap()
            }
            onCutoutDetectedListener = { cutoutRect ->
                if (currentPositionMode == "auto") {
                    updatePositionForCutout(cutoutRect)
                }
            }
        }

        val layoutParams = createLayoutParams()
        try {
            windowManager?.addView(overlayView, layoutParams)
            Log.d(TAG, "Camera tap overlay view successfully added to WindowManager")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add camera tap overlay view: ${e.message}", e)
        }
    }

    private fun createLayoutParams(): WindowManager.LayoutParams {
        val windowType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS

        val defaultSize = dpToPx(56f)

        return WindowManager.LayoutParams(
            defaultSize,
            defaultSize,
            windowType,
            flags,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            x = 0
            y = 0
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            }
        }
    }

    private fun relayoutOverlay() {
        val view = overlayView ?: return
        val wm = windowManager ?: return
        val params = view.layoutParams as? WindowManager.LayoutParams ?: createLayoutParams()

        val touchSize = dpToPx(56f)
        params.width = touchSize
        params.height = touchSize

        when (currentPositionMode) {
            "left" -> {
                params.gravity = Gravity.TOP or Gravity.START
                params.x = dpToPx(16f)
                params.y = 0
            }
            "right" -> {
                params.gravity = Gravity.TOP or Gravity.END
                params.x = dpToPx(16f)
                params.y = 0
            }
            "center" -> {
                params.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                params.x = 0
                params.y = 0
            }
            "auto" -> {
                // Check if last detected cutout is available
                val lastCutout = view.lastDetectedCutout
                if (lastCutout != null && !lastCutout.isEmpty) {
                    updatePositionForCutout(lastCutout)
                    return
                } else {
                    params.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                    params.x = 0
                    params.y = 0
                }
            }
        }

        try {
            wm.updateViewLayout(view, params)
            Log.d(TAG, "Overlay repositioned: mode=$currentPositionMode, gravity=${params.gravity}, x=${params.x}, y=${params.y}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update overlay layout: ${e.message}")
        }
    }

    private fun updatePositionForCutout(rect: Rect) {
        val view = overlayView ?: return
        val wm = windowManager ?: return
        val params = view.layoutParams as? WindowManager.LayoutParams ?: return

        val targetWidth = max(rect.width() + dpToPx(28f), dpToPx(56f))
        val targetHeight = max(rect.height() + dpToPx(28f), dpToPx(56f))

        params.width = targetWidth
        params.height = targetHeight
        params.gravity = Gravity.TOP or Gravity.START
        params.x = (rect.centerX() - targetWidth / 2).coerceAtLeast(0)
        params.y = (rect.centerY() - targetHeight / 2).coerceAtLeast(0)

        try {
            wm.updateViewLayout(view, params)
            Log.d(TAG, "Overlay adjusted to DisplayCutout: center=(${rect.centerX()}, ${rect.centerY()}), size=(${targetWidth}x${targetHeight})")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update overlay for cutout: ${e.message}")
        }
    }

    private fun handleCameraTripleTap() {
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (keyguardManager.isKeyguardLocked) {
            Log.d(TAG, "Camera triple tap detected, but device is locked. Ignoring.")
            return
        }

        Log.d(TAG, "Camera triple tap gesture confirmed!")
        triggerVibration()

        MainActivity.onCameraTapDetected()

        if (!MainActivity.calibrationMode) {
            val dismissed = PopupActivity.dismissActiveInstance()
            if (dismissed) {
                Log.d(TAG, "Active popup dismissed via camera triple tap")
            } else {
                Log.d(TAG, "Launching fresh PopupActivity via camera triple tap...")
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

    fun triggerVibration() {
        if (!hapticsEnabled) return
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(150, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(150)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to vibrate: ${e.message}")
        }
    }

    fun triggerTick() {
        if (!hapticsEnabled) return
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                vibrator.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK))
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(20, 80))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(20)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to tick vibrate: ${e.message}")
        }
    }

    private fun notifyFlutterState(running: Boolean) {
        mainHandler.post {
            MainActivity.flutterEngineInstance?.let { engine ->
                try {
                    MethodChannel(engine.dartExecutor.binaryMessenger, "com.waypointlattice.tripl/popup")
                        .invokeMethod("onCameraTapStateChanged", running)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to send camera tap state to Flutter: ${e.message}")
                }
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Tripl Camera Tap Service"
            val desc = "Listens for physical triple taps on the front camera hole punch"
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
            1,
            popupIntent,
            pendingIntentFlags
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Tripl Camera Tap Active")
            .setContentText("Triple tap camera hole punch to capture expense")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: CameraTapService running sticky (startId: $startId)")
        return START_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy: Stopping CameraTapService")
        instance = null

        try {
            unregisterReceiver(screenStateReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error cleaning up screenStateReceiver: ${e.message}")
        }

        overlayView?.let { view ->
            try {
                windowManager?.removeView(view)
            } catch (e: Exception) {
                Log.e(TAG, "Error removing overlay view: ${e.message}")
            }
            overlayView = null
        }

        notifyFlutterState(false)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun dpToPx(dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp,
            resources.displayMetrics
        ).toInt()
    }

    /**
     * Custom touch overlay view positioned over the front camera cutout.
     * Renders subtle animated mint rings on each tap and detects triple tap sequences.
     */
    @SuppressLint("ViewConstructor")
    inner class CameraTapOverlayView(context: Context) : View(context) {

        var onTripleTapListener: (() -> Unit)? = null
        var onCutoutDetectedListener: ((Rect) -> Unit)? = null
        var lastDetectedCutout: Rect? = null

        private var tapCount = 0
        private var lastTapTime = 0L
        private var downX = 0f
        private var downY = 0f
        private var isDragging = false

        private var animProgress = 0f
        private var isSuccessAnimation = false

        private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dpToPx(3f).toFloat()
            color = Color.parseColor("#00E5A3") // Tripl Brand Mint
        }

        private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.parseColor("#3300E5A3")
        }

        private val animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 350
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                animProgress = it.animatedValue as Float
                invalidate()
            }
        }

        private val resetTapCountRunnable = Runnable {
            if (tapCount > 0) {
                Log.d(TAG, "Tap sequence timed out (count was $tapCount), resetting.")
                tapCount = 0
            }
        }

        init {
            isClickable = true
            isFocusable = false

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                setOnApplyWindowInsetsListener { _, insets ->
                    val cutout = insets.displayCutout
                    if (cutout != null) {
                        val topRect = cutout.boundingRectTop.takeIf { !it.isEmpty }
                            ?: cutout.boundingRects.firstOrNull { it.top <= dpToPx(60f) }

                        if (topRect != null && !topRect.isEmpty) {
                            lastDetectedCutout = topRect
                            onCutoutDetectedListener?.invoke(topRect)
                        }
                    }
                    insets
                }
            }
        }

        override fun onAttachedToWindow() {
            super.onAttachedToWindow()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                rootWindowInsets?.displayCutout?.let { cutout ->
                    val topRect = cutout.boundingRectTop.takeIf { !it.isEmpty }
                        ?: cutout.boundingRects.firstOrNull { it.top <= dpToPx(60f) }
                    if (topRect != null && !topRect.isEmpty) {
                        lastDetectedCutout = topRect
                        onCutoutDetectedListener?.invoke(topRect)
                    }
                }
            }
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)

            if (animProgress > 0f && animProgress < 1f) {
                val cx = width / 2f
                val cy = height / 2f
                val baseRadius = (minOf(width, height) / 2f) * 0.4f

                val maxExpand = if (isSuccessAnimation) 1.6f else 1.25f
                val currentRadius = baseRadius + (baseRadius * (maxExpand - 1f) * animProgress)

                val alpha = ((1f - animProgress) * 255).toInt().coerceIn(0, 255)
                ringPaint.alpha = alpha
                glowPaint.alpha = (alpha * 0.35f).toInt().coerceIn(0, 255)

                canvas.drawCircle(cx, cy, currentRadius, glowPaint)
                canvas.drawCircle(cx, cy, currentRadius, ringPaint)

                if (isSuccessAnimation) {
                    val outerRadius = currentRadius * 1.3f
                    ringPaint.alpha = (alpha * 0.6f).toInt().coerceIn(0, 255)
                    canvas.drawCircle(cx, cy, outerRadius, ringPaint)
                }
            }
        }

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouchEvent(event: MotionEvent): Boolean {
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX
                    downY = event.rawY
                    isDragging = false
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = abs(event.rawX - downX)
                    val dy = abs(event.rawY - downY)
                    // If user moves more than 16dp (e.g. pulling down notification shade), cancel taps
                    if (dx > dpToPx(16f) || dy > dpToPx(16f)) {
                        isDragging = true
                        removeCallbacks(resetTapCountRunnable)
                        tapCount = 0
                    }
                    return true
                }
                MotionEvent.ACTION_UP -> {
                    if (isDragging) {
                        return true
                    }
                    handleTap()
                    return true
                }
            }
            return super.onTouchEvent(event)
        }

        private fun handleTap() {
            removeCallbacks(resetTapCountRunnable)

            val now = SystemClock.uptimeMillis()
            val elapsed = now - lastTapTime

            if (elapsed <= TAP_WINDOW_MS) {
                tapCount++
            } else {
                tapCount = 1
            }
            lastTapTime = now

            val isFinal = tapCount >= 3
            isSuccessAnimation = isFinal

            animator.cancel()
            animator.start()

            if (isFinal) {
                tapCount = 0
                onTripleTapListener?.invoke()
            } else {
                triggerTick()
                postDelayed(resetTapCountRunnable, TAP_WINDOW_MS)
            }
        }
    }
}
