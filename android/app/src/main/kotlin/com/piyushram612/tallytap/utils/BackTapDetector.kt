package com.piyushram612.tallytap.utils

import android.util.Log

class BackTapDetector(private val onDoubleTapTriggered: () -> Unit) {
    private var lastZValue = 0f
    private var lastTapTime = 0L
    
    // Increased sensitivity threshold (lowered from 8.0f to 5.5f for extremely effortless double-taps/shakes)
    private val tapThreshold = 5.5f       
    private val debounceWindowMs = 120L    // Lowered slightly to allow fast rapid consecutive taps
    private val doubleTapWindowMinMs = 100L // Minimum duration to recognize separate tap events
    private val doubleTapWindowMaxMs = 500L // Maximum duration between consecutive taps

    fun processSensorEvent(zValue: Float) {
        val currentTime = System.currentTimeMillis()
        
        // Measure rapid acceleration delta in the Z axis (perpendicular to back of device)
        val deltaZ = Math.abs(zValue - lastZValue)
        lastZValue = zValue

        // Verbose logging for all minor impacts
        if (deltaZ > 2.5f) {
            Log.d("BackTapDetector", "DeltaZ vibration detected: ${String.format("%.2f", deltaZ)} m/s^2 (Threshold: $tapThreshold)")
        }

        if (deltaZ > tapThreshold) {
            val timeDiff = currentTime - lastTapTime
            if (timeDiff > debounceWindowMs) {
                Log.d("BackTapDetector", "VALID TAP SPIKE! DeltaZ: ${String.format("%.2f", deltaZ)} m/s^2, timeDiff: ${timeDiff}ms since last tap")

                if (timeDiff in doubleTapWindowMinMs..doubleTapWindowMaxMs) {
                    Log.d("BackTapDetector", "🏆 DOUBLE BACK TAP DETECTED SUCCESSFULLY!")
                    onDoubleTapTriggered()
                    lastTapTime = 0L // Reset
                } else {
                    lastTapTime = currentTime
                }
            } else {
                Log.d("BackTapDetector", "Tap ignored: debounced (timeDiff: ${timeDiff}ms <= ${debounceWindowMs}ms)")
            }
        }
    }
}
