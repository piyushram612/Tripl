package com.waypointlattice.tripl.utils

import android.util.Log
import com.waypointlattice.tripl.MainActivity

class BackTapDetector(private val onTripleTapTriggered: (recommendedForce: Float, recommendedJerk: Float) -> Unit) {
    private var lastTapTime = 0L
    private var tapCount = 0
    private var lastLinearZ = 0f
    private var isQuietBetweenTaps = true
    private var quietSamplesCount = 0
    
    // Calibration tracking arrays
    private val calibForces = FloatArray(3)
    private val calibJerks = FloatArray(3)
    
    // Gravity low-pass filter
    private val gravity = FloatArray(3)
    private var isGravityInitialized = false

    // Configurable thresholds (mutable, updated live or loaded from prefs)
    var tapThreshold = 2.5f
    var jerkThreshold = 2.5f
    
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
            quietSamplesCount++
            if (quietSamplesCount >= 2) {
                isQuietBetweenTaps = true
            }
        } else {
            quietSamplesCount = 0
        }

        // Use lowered threshold in calibration mode so the user can register taps even if current threshold is high
        val isCalib = MainActivity.calibrationMode
        val currentForceThreshold = if (isCalib) 1.5f else tapThreshold
        val currentJerkThreshold = if (isCalib) 1.5f else jerkThreshold

        // Max force cap: reject violent impacts (drops, falls, hard knocks)
        if (linearZ >= 25.0f) {
            if (tapCount > 0) {
                Log.d("BackTapDetector", "Violent impact detected (linearZ: ${String.format("%.2f", linearZ)} >= 25.0). Resetting tap sequence.")
                tapCount = 0
                lastTapTime = 0L
                isQuietBetweenTaps = true
                quietSamplesCount = 0
            }
            return
        }

        // Positive-only Z check to reject screen taps
        if (linearZ > currentForceThreshold) {
            // Cross-axis rejection: Check if movement is primarily on Z axis
            if (linearZ > (absX + absY) * 1.2f) {
                
                // Jerk rejection: Verify it's a sudden impact, not a smooth swing
                if (jerkZ > currentJerkThreshold) {
                    val timeDiff = currentTime - lastTapTime
                    if (timeDiff > debounceWindowMs) {
                        
                        // Quiet Window Check: Reject continuous vibration
                        if (tapCount == 0 || isQuietBetweenTaps) {
                            Log.d("BackTapDetector", "VALID TAP SPIKE! linearZ: ${String.format("%.2f", linearZ)}, timeDiff: ${timeDiff}ms, Jerk: ${String.format("%.2f", jerkZ)}")
        
                            if (timeDiff in tapWindowMinMs..tapWindowMaxMs) {
                                // Store calibration data
                                if (tapCount in 0..2) {
                                    calibForces[tapCount] = linearZ
                                    calibJerks[tapCount] = jerkZ
                                }
                                
                                tapCount++
                                isQuietBetweenTaps = false
                                quietSamplesCount = 0
                                
                                if (tapCount >= 3) {
                                    val f1 = calibForces[0]
                                    val f2 = calibForces[1]
                                    val f3 = calibForces[2]
                                    
                                    val maxForce = maxOf(f1, maxOf(f2, f3))
                                    val minForce = minOf(f1, minOf(f2, f3))
                                    
                                    val ratioLimit = (4.5f - 0.5f * (tapThreshold - 2.2f)).coerceIn(3.0f, 4.5f)
                                    val actualRatio = maxForce / minForce
                                    if (maxForce <= minForce * ratioLimit) {
                                        // Calculate calibrated values (60% of average)
                                        val avgForce = (f1 + f2 + f3) / 3f
                                        val avgJerk = (calibJerks[0] + calibJerks[1] + calibJerks[2]) / 3f
                                        
                                        val recommendedForce = (avgForce * 0.60f).coerceIn(2.2f, 4.5f)
                                        val recommendedJerk = (avgJerk * 0.50f).coerceIn(1.5f, 2.2f)
                                        
                                        Log.d("BackTapDetector", "🏆 TRIPLE BACK TAP DETECTED! Calibrated Force: $recommendedForce, Calibrated Jerk: $recommendedJerk (Ratio: ${String.format("%.2f", actualRatio)} <= Limit: ${String.format("%.2f", ratioLimit)})")
                                        onTripleTapTriggered(recommendedForce, recommendedJerk)
                                        
                                        // Reset
                                        lastTapTime = 0L
                                        tapCount = 0
                                        isQuietBetweenTaps = true
                                        quietSamplesCount = 0
                                    } else {
                                        Log.d("BackTapDetector", "Tap sequence rejected: force inconsistent (Max: ${String.format("%.2f", maxForce)}, Min: ${String.format("%.2f", minForce)}, Ratio: ${String.format("%.2f", actualRatio)} > Limit: ${String.format("%.2f", ratioLimit)})")
                                        // Reset
                                        lastTapTime = 0L
                                        tapCount = 0
                                        isQuietBetweenTaps = true
                                        quietSamplesCount = 0
                                    }
                                } else {
                                    lastTapTime = currentTime
                                }
                            } else {
                                // Start of a new tap sequence
                                tapCount = 1
                                calibForces[0] = linearZ
                                calibJerks[0] = jerkZ
                                isQuietBetweenTaps = false
                                quietSamplesCount = 0
                                lastTapTime = currentTime
                            }
                        } else {
                            Log.d("BackTapDetector", "Tap ignored: Continuous vibration/noise (not quiet between taps)")
                        }
                    } else {
                        Log.d("BackTapDetector", "Tap ignored: debounced (timeDiff: ${timeDiff}ms <= ${debounceWindowMs}ms)")
                    }
                } else {
                    Log.d("BackTapDetector", "Tap ignored: Low Jerk (smooth movement). Jerk:$jerkZ < $currentJerkThreshold")
                }
            } else {
                Log.d("BackTapDetector", "Tap ignored: Cross-axis rejection. Too much X/Y movement. Z:$linearZ, X:$absX, Y:$absY")
            }
        }
    }
}
