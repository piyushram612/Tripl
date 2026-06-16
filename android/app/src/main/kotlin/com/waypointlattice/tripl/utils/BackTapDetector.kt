package com.waypointlattice.tripl.utils

import android.util.Log

class BackTapDetector(private val onTripleTapTriggered: () -> Unit) {
    private var lastTapTime = 0L
    private var tapCount = 0
    private var lastLinearZ = 0f
    private var isQuietBetweenTaps = true
    
    // Gravity low-pass filter
    private val gravity = FloatArray(3)
    private var isGravityInitialized = false

    private val tapThreshold = 2.5f
    private val jerkThreshold = 2.5f
    private val debounceWindowMs = 110L
    private val tapWindowMinMs = 100L
    var tapWindowMaxMs = 400L // Configurable via sensitivity slider
    private val quietThreshold = 1.0f

    fun processSensorEvent(xValue: Float, yValue: Float, zValue: Float) {
        val currentTime = System.currentTimeMillis()
        
        // Alpha is calculated as t / (t + dT)
        val alpha = 0.8f

        if (!isGravityInitialized) {
            gravity[0] = xValue
            gravity[1] = yValue
            gravity[2] = zValue
            isGravityInitialized = true
        } else {
            gravity[0] = alpha * gravity[0] + (1 - alpha) * xValue
            gravity[1] = alpha * gravity[1] + (1 - alpha) * yValue
            gravity[2] = alpha * gravity[2] + (1 - alpha) * zValue
        }

        // Linear acceleration (high-pass filter to remove gravity)
        val linearX = xValue - gravity[0]
        val linearY = yValue - gravity[1]
        val linearZ = zValue - gravity[2]

        val absZ = Math.abs(linearZ)
        val absX = Math.abs(linearX)
        val absY = Math.abs(linearY)
        val jerkZ = Math.abs(linearZ - lastLinearZ)
        
        lastLinearZ = linearZ

        // Check if the sensor has settled down (quiet window)
        if (absZ < quietThreshold) {
            isQuietBetweenTaps = true
        }

        if (absZ > 2.5f) {
            Log.d("BackTapDetector", "Linear Z spike: ${String.format("%.2f", absZ)}, Jerk: ${String.format("%.2f", jerkZ)}")
        }

        if (absZ > tapThreshold) {
            // 1. Cross-axis rejection: Check if movement is primarily on Z axis
            if (absZ > (absX + absY) * 1.2f) {
                
                // 2. Jerk rejection: Verify it's a sudden impact, not a smooth swing
                if (jerkZ > jerkThreshold) {
                    val timeDiff = currentTime - lastTapTime
                    if (timeDiff > debounceWindowMs) {
                        
                        // 3. Quiet Window Check: Reject continuous vibration
                        if (tapCount == 0 || isQuietBetweenTaps) {
                            Log.d("BackTapDetector", "VALID TAP SPIKE! Linear Z: ${String.format("%.2f", absZ)}, timeDiff: ${timeDiff}ms")
        
                            if (timeDiff in tapWindowMinMs..tapWindowMaxMs) {
                                tapCount++
                                isQuietBetweenTaps = false
                                if (tapCount >= 3) {
                                    Log.d("BackTapDetector", "🏆 TRIPLE BACK TAP DETECTED SUCCESSFULLY!")
                                    onTripleTapTriggered()
                                    lastTapTime = 0L // Reset
                                    tapCount = 0
                                } else {
                                    lastTapTime = currentTime
                                }
                            } else {
                                // Start of a new tap sequence
                                tapCount = 1
                                isQuietBetweenTaps = false
                                lastTapTime = currentTime
                            }
                        } else {
                            Log.d("BackTapDetector", "Tap ignored: Continuous vibration/noise (not quiet between taps)")
                        }
                    } else {
                        Log.d("BackTapDetector", "Tap ignored: debounced (timeDiff: ${timeDiff}ms <= ${debounceWindowMs}ms)")
                    }
                } else {
                    Log.d("BackTapDetector", "Tap ignored: Low Jerk (smooth movement). Jerk:$jerkZ < $jerkThreshold")
                }
            } else {
                Log.d("BackTapDetector", "Tap ignored: Cross-axis rejection. Too much X/Y movement. Z:$absZ, X:$absX, Y:$absY")
            }
        }
    }
}
