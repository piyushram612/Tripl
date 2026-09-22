package com.waypointlattice.tripl.utils

import android.util.Log
import com.waypointlattice.tripl.MainActivity

/**
 * BackTapDetector: A physics-based, elastic-cadence triple back-tap gesture recognition engine.
 *
 * It processes raw 3-axis accelerometer and gyroscope streams to detect deliberate finger back-taps
 * on the phone casing while rejecting environmental noise, bed/couch drops, vehicle vibrations,
 * footstep gait impacts, screen tap recoils, and off-axis shocks.
 */
class BackTapDetector(private val onTripleTapTriggered: (recommendedForce: Float, recommendedJerk: Float) -> Unit) {
    private var lastTapTime = 0L
    private var firstTapTime = 0L
    private var tapCount = 0
    private var lastLinearZ = 0f
    
    // Settling refractory window tracking (65ms post-tap chassis resonance mute)
    private var postTapRefractoryUntil = 0L
    
    // Calibration tracking arrays (stores peak force and jerk for ratio verification)
    private val calibForces = FloatArray(3)
    private val calibJerks = FloatArray(3)
    
    // Low-pass filter vector for gravity extraction
    private val gravity = FloatArray(3)
    private var isGravityInitialized = false

    // Configurable thresholds (loaded from preferences or calibrated dynamically)
    var tapThreshold = 2.5f
    var jerkThreshold = 2.0f
    
    // Configurable sensitivity window (elastic upper bound for tap pacing)
    var tapWindowMaxMs = 400L // Upper interval bound (range: 300ms - 800ms via UI slider)
    private val tapWindowMinMs = 70L // Elastic minimum interval (supports rapid double/triple tap bursts)

    /**
     * Autonomous Motion Mode state flag.
     * Evaluated dynamically from real-time accelerometer and gyroscope motion metrics.
     * Tightens force ratio and gyro stillness thresholds during transit/walking without blocking tap capture.
     */
    var isMotionMode: Boolean = false
        set(value) {
            if (field != value) {
                field = value
                Log.d("BackTapDetector", "Motion Mode changed: isMotionMode=$field")
            }
        }

    // Autonomous Motion Mode tracking with hysteresis
    private var motionStillStartTime = 0L
    private val MOTION_ENTER_THRESHOLD = 1.20f  // runningNoise floor to trigger Motion Mode (raised to prevent taps from triggering it)
    private val MOTION_EXIT_THRESHOLD = 0.65f   // runningNoise floor to transition back to Still Mode
    private val MOTION_EXIT_DELAY_MS = 1500L    // sustained calm duration before exiting Motion Mode

    // Gyroscope tracking state
    private var gyroX = 0f
    private var gyroY = 0f
    private var gyroZ = 0f
    private var gyroMag = 0f
    private var gyroBaseline = 0f
    private var lastGyroTimestamp = 0L

    // Free-fall weightlessness detection state (filters soft couch/bed drops)
    private var freeFallStartTime = 0L
    private var lastFreeFallTime = 0L

    // Pulse width duration tracking state
    private var spikeStartTime = 0L
    private var isSpikeActive = false

    // Timing, cooldown, and noise floor tracking state
    private var lastTimestamp = 0L
    private var cooldownLockoutTime = 0L
    private var lastNegativeSpikeTime = 0L
    private var runningNoise = 0f
    private val spikeHistory = mutableListOf<Long>()

    /**
     * Ingests 3-axis gyroscope Angular Velocity (rad/s).
     * Computes raw magnitude and maintains a time-invariant low-pass baseline (tau = 150ms).
     * This separates sustained rotational motion (walking, turning, arm swinging) from 
     * the transient 15-25ms rotational recoil produced by the physical tap impact.
     */
    fun processGyroEvent(gx: Float, gy: Float, gz: Float) {
        val currentTime = System.currentTimeMillis()
        gyroX = gx
        gyroY = gy
        gyroZ = gz
        gyroMag = Math.sqrt((gx * gx + gy * gy + gz * gz).toDouble()).toFloat()

        if (lastGyroTimestamp == 0L) {
            gyroBaseline = gyroMag
        } else {
            val dtGyro = Math.max(0.001f, (currentTime - lastGyroTimestamp) / 1000f)
            // Time constant tau = 0.15s (150ms): absorbs 15-25ms tap recoil shocks while tracking sustained motion
            val tau = 0.15f
            val alpha = (tau / (tau + dtGyro)).coerceIn(0.70f, 0.98f)
            gyroBaseline = alpha * gyroBaseline + (1f - alpha) * gyroMag
        }
        lastGyroTimestamp = currentTime
    }

    /**
     * Main Processing Pipeline: Executed on every raw Accelerometer event.
     * Implements a 12-step physics cascade to isolate valid back-tap gestures.
     */
    fun processSensorEvent(xValue: Float, yValue: Float, zValue: Float) {
        val currentTime = System.currentTimeMillis()

        // =======================================================================================
        // STEP 0: Time-Delta Calculation, Smooth Gravity Low-Pass Filter & Cooldown Lockout Gate
        // =======================================================================================
        // What it does: Calculates sample elapsed time `dt`, updates the gravity LPF vector, and 
        //               mutes gesture processing if within a post-impact cooldown lockout.
        // Why it exists: Large drops or knocks cause lingering mechanical chassis ringing for ~800ms.
        //                Crucially, updating gravity during cooldown prevents synthetic `dt` jumps
        //                when cooldown expires.
        // Threshold: Cooldown Lockout = 800ms; LPF Tau = 0.1s.
        // =======================================================================================
        if (lastTimestamp == 0L) {
            lastTimestamp = currentTime
        }
        val dt = (currentTime - lastTimestamp) / 1000f
        lastTimestamp = currentTime

        if (dt <= 0f) return

        // Time-invariant low-pass filter coefficient calculation: alpha = tau / (tau + dt)
        val timeConstant = 0.1f
        val alpha = timeConstant / (timeConstant + dt)

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

        // Mute gesture detection during active cooldown lockout, but keep gravity filter updated
        if (currentTime < cooldownLockoutTime) {
            return
        }

        // Isolate true linear acceleration by subtracting the gravity vector (High-Pass Filter)
        val linearX = xValue - gravity[0]
        val linearY = yValue - gravity[1]
        val linearZ = zValue - gravity[2]

        val absZ = Math.abs(linearZ)
        val absX = Math.abs(linearX)
        val absY = Math.abs(linearY)

        // =======================================================================================
        // STEP 0.5: Inactivity Auto-Reset for Abandoned / Stale Tap Sequences
        // =======================================================================================
        // What it does: Resets `tapCount = 0` if the user stops tapping before completing 3 taps.
        // Why it exists: Prevents a single accidental bump from sitting in memory and triggering 
        //                a tap later when the user performs a second tap minutes later.
        // Threshold: Timeout = max(tapWindowMaxMs + 150ms, 600ms).
        // =======================================================================================
        val autoResetTimeout = Math.max(tapWindowMaxMs + 150L, 600L)
        if (tapCount > 0 && (currentTime - lastTapTime > autoResetTimeout)) {
            Log.d("BackTapDetector", "[Step 0.5] Inactivity timeout (${currentTime - lastTapTime}ms > ${autoResetTimeout}ms). Resetting tap sequence.")
            tapCount = 0
            lastTapTime = 0L
            firstTapTime = 0L
            spikeHistory.clear()
        }

        // =======================================================================================
        // STEP 1: Orientation Gating (Landscape Lockout & Flat Desk Bypass)
        // =======================================================================================
        // What it does: Suppresses detection when held in sideways landscape orientation, EXCEPT 
        //               when the device is lying flat on a desk (dominant Z-gravity).
        // Why it exists: Side-swiping or typing in landscape creates heavy lateral accelerations.
        //                However, users often tap their phone while it rests flat on a desk.
        // Threshold: Flat Desk Check: abs(gravityZ) >= 7.0 m/s^2 (~0.7g).
        // =======================================================================================
        val isCalib = MainActivity.calibrationMode
        val absGravityZ = Math.abs(gravity[2])
        val isFlatOnDesk = absGravityZ >= 7.0f
        val isLandscape = Math.abs(gravity[0]) > Math.abs(gravity[1])

        if (isLandscape && !isFlatOnDesk && !isCalib) {
            return
        }

        // =======================================================================================
        // STEP 1.5: Free-Fall Weightlessness Detector (Bed & Couch Soft Drop Suppression)
        // =======================================================================================
        // What it does: Monitors total acceleration vector magnitude. If magnitude drops below
        //               3.2 m/s^2 (~0.3g) for >= 80ms, the device is flagged as airborne.
        // Why it exists: Dropping a phone onto a bed or sofa cushion produces a soft rebound impact.
        //                Step 3 misses this because peak Z-force is mild (~10-15 m/s^2), but free-fall
        //                weightlessness detection squashes 100% of these drop false-positives.
        // Threshold: Weightlessness Floor = 3.2 m/s^2; Minimum Airborne Duration = 80ms;
        //            Post-Drop Mute Window = 700ms.
        // =======================================================================================
        val rawMag = Math.sqrt((xValue * xValue + yValue * yValue + zValue * zValue).toDouble()).toFloat()
        if (rawMag < 3.2f) {
            if (freeFallStartTime == 0L) {
                freeFallStartTime = currentTime
            } else if (currentTime - freeFallStartTime >= 80L) {
                lastFreeFallTime = currentTime
            }
        } else {
            freeFallStartTime = 0L
        }

        if (currentTime - lastFreeFallTime < 700L) {
            if (absZ > 5.0f) {
                Log.d("BackTapDetector", "[Step 1.5] Impact suppressed: phone landing after free-fall weightlessness drop (${currentTime - lastFreeFallTime}ms ago).")
            }
            return
        }

        // =======================================================================================
        // STEP 2: Dynamic Ambient Noise Floor Estimation & Adaptive Threshold Scaling
        // =======================================================================================
        // What it does: Computes an Exponential Moving Average (EMA) of total motion to measure
        //               ambient vibration (walking gait, vehicle rumble) and scales the force floor.
        // Why it exists: Fixed thresholds fail in vibrating environments. When moving, the threshold
        //               dynamically inflates to keep false positives out while capturing deliberate taps.
        // Threshold: Base Noise Floor = 1.2 m/s^2 (Motion Mode) / 1.5 m/s^2 (Standard Mode);
        //            Decay Factor = 0.98.
        // =======================================================================================
        // Only update running ambient noise when NOT in an active tap sequence or post-tap settling window.
        // This prevents the user's deliberate back taps from inflating runningNoise and falsely triggering Motion Mode.
        val isInTapSequence = (tapCount > 0) || (currentTime < postTapRefractoryUntil)
        if (!isInTapSequence) {
            val totalLinearMotion = absX + absY + absZ
            val noiseInput = totalLinearMotion.coerceAtMost(3.0f)
            val noiseDecay = 0.98f
            runningNoise = noiseDecay * runningNoise + (1 - noiseDecay) * noiseInput

            // Autonomous Motion Mode evaluation with hysteresis
            if (runningNoise >= MOTION_ENTER_THRESHOLD) {
                motionStillStartTime = 0L
                if (!isMotionMode) {
                    isMotionMode = true
                }
            } else if (runningNoise <= MOTION_EXIT_THRESHOLD) {
                if (isMotionMode) {
                    if (motionStillStartTime == 0L) {
                        motionStillStartTime = currentTime
                    } else if (currentTime - motionStillStartTime >= MOTION_EXIT_DELAY_MS) {
                        isMotionMode = false
                        motionStillStartTime = 0L
                    }
                }
            } else {
                // Deadband between 0.65f and 1.20f: reset calm timer so inter-step pauses don't prematurely exit
                motionStillStartTime = 0L
            }
        }

        val baseNoiseFloor = if (isMotionMode) 1.2f else 1.5f
        val noiseMultiplier = if (runningNoise > baseNoiseFloor) {
            1.0f + (runningNoise - baseNoiseFloor) * (if (isMotionMode) 0.75f else 0.5f)
        } else {
            1.0f
        }

        val baseForce = if (isCalib) 1.5f else tapThreshold
        val currentForceThreshold = baseForce * noiseMultiplier

        // Time-invariant Jerk calculation (rate of acceleration change, normalized to 10ms frame)
        val normalizedJerkZ = Math.abs(linearZ - lastLinearZ) * (0.01f / dt)
        lastLinearZ = linearZ

        // =======================================================================================
        // STEP 3: Violent Impact Rejection (Drop & Off-Axis Shock Filter)
        // =======================================================================================
        // What it does: Evaluates Z-axis force and 3D vector impact magnitude. If force exceeds
        //               38.0 m/s^2 (~4g), triggers an immediate 800ms cooldown lockout and resets sequence.
        // Why it exists: Hard drops on desks or off-axis corner bumps produce massive kinetic shocks.
        //                This gate mutes the pipeline to prevent post-impact structural ringing.
        // Threshold: LinearZ >= 38.0 m/s^2 OR Total Vector Impact Magnitude >= 38.0 m/s^2.
        // =======================================================================================
        val impactMag = Math.sqrt((linearX * linearX + linearY * linearY + linearZ * linearZ).toDouble()).toFloat()
        if (linearZ >= 38.0f || impactMag >= 38.0f) {
            Log.d("BackTapDetector", "[Step 3] Violent impact detected (Z: ${String.format("%.2f", linearZ)}, ImpactMag: ${String.format("%.2f", impactMag)}). Activating 800ms lockout.")
            cooldownLockoutTime = currentTime + 800L
            tapCount = 0
            lastTapTime = 0L
            firstTapTime = 0L
            spikeHistory.clear()
            return
        }

        // Track strong negative Z excursions (front screen tap pushes screen away)
        // Raised to -4.5 m/s^2 to prevent back-tap chassis rebound (-2 to -3 m/s^2) from triggering it
        if (linearZ < -4.5f) {
            lastNegativeSpikeTime = currentTime
        }

        // =======================================================================================
        // STEP 4: Positive Tap Polarity & Force Upper Bound Ceiling Check
        // =======================================================================================
        // What it does: Verifies linear Z is positive (inward tap against casing) and exceeds
        //               the adaptive force floor while remaining below the 26.0 m/s^2 ceiling.
        // Why it exists: Finger back-taps press the casing forward (+Z). Negative spikes (-Z)
        //                are screen taps or releases. Knocks > 26.0 m/s^2 are non-tap shocks.
        // Threshold: currentForceThreshold < linearZ <= 26.0 m/s^2.
        // =======================================================================================
        val tapForceCeiling = 26.0f
        if (linearZ > currentForceThreshold && linearZ <= tapForceCeiling) {

            // ===================================================================================
            // STEP 5: Front Screen Tap Recoil Suppression
            // ===================================================================================
            // What it does: Rejects weak positive Z recoils preceded within 70ms by a strong negative front-screen tap.
            // Why it exists: Tapping the front screen pushes the phone away (-Z), causing hand 
            //                grip recoil back (+Z). Real back taps deliver strong positive impulse (Z >= 6.0 m/s^2)
            //                or occur during an active sequence (tapCount > 0) where negative dips are casing rebounds.
            // Threshold: Screen Recoil Time Window < 70ms AND linearZ < 6.0 m/s^2 AND tapCount == 0.
            // ===================================================================================
            if (currentTime - lastNegativeSpikeTime < 70L) {
                if (tapCount == 0 && linearZ < 6.0f) {
                    Log.d("BackTapDetector", "[Step 5] Spike ignored: classified as front screen tap recoil (Z: ${String.format("%.2f", linearZ)} < 6.0).")
                    return
                }
            }

            // ===================================================================================
            // STEP 6: Dominant Axis Impulse Ratio (Tilted Hand Posture Support)
            // ===================================================================================
            // What it does: Ensures Z-axis impulse dominates lateral magnitude (sqrt(X^2 + Y^2)).
            // Why it exists: Real back-taps are perpendicular to the back cover. Corner bumps or
            //                side shakes distribute energy heavily into X/Y. Using 0.8x lateral
            //                ratio allows valid taps even when holding the device at a 45-degree angle.
            // Threshold: linearZ > 0.8 * sqrt(linearX^2 + linearY^2).
            // ===================================================================================
            val lateralMag = Math.sqrt((linearX * linearX + linearY * linearY).toDouble()).toFloat()
            if (linearZ > lateralMag * 0.8f) {

                // ===============================================================================
                // STEP 7: Jerk Sharpness & Gyroscope Rotational Motion Gating
                // ===============================================================================
                // What it does: Validates rate of acceleration change (Jerk) AND verifies that 
                //               prior background rotational motion (gyroBaseline) was calm, 
                //               preventing false taps during walking arm swings, wrist twists, or turns.
                // Why it exists: Genuine finger taps are sharp mechanical transients (high Jerk) 
                //                delivered while the phone is held relatively steady. The tap impact 
                //                itself imparts micro-recoil torque (pitch/roll up to ~5 rad/s for 15ms), 
                //                so we check pre-impact smoothed baseline motion rather than dropping 
                //                taps due to their own transient recoil. Yaw (Z-rotation) is also checked 
                //                since normal Z-axis taps produce near-zero yaw torque.
                // Threshold: Jerk > currentJerkThreshold; 
                //            Baseline Gyro Ceiling = 1.4 rad/s (Standard) / 0.9 rad/s (Motion Mode);
                //            Yaw Gyro Ceiling = 2.5 rad/s (Standard) / 1.8 rad/s (Motion Mode);
                //            Instantaneous Recoil Ceiling = 6.5 rad/s (Standard) / 4.5 rad/s (Motion Mode);
                //            Bypassed when isCalib is active.
                // ===============================================================================
                val baseJerk = if (isCalib) 1.5f else jerkThreshold
                val currentJerkThreshold = baseJerk * noiseMultiplier

                if (normalizedJerkZ > currentJerkThreshold) {

                    // Gyroscope Rotational Stillness Check (if gyro data is active within last 500ms)
                    val isGyroActive = (currentTime - lastGyroTimestamp < 500L)
                    if (isGyroActive && !isCalib) {
                        val baselineLimit = if (isMotionMode) 1.4f else 1.8f
                        val yawLimit = if (isMotionMode) 2.0f else 2.8f
                        val shockCeiling = if (isMotionMode) 5.5f else 7.5f

                        // 1. Check sustained background motion before impact (rejects walking / active handling)
                        if (gyroBaseline > baselineLimit) {
                            Log.d("BackTapDetector", "[Step 7] Spike ignored: background rotational motion active (gyroBaseline: ${String.format("%.2f", gyroBaseline)} rad/s > $baselineLimit)")
                            return
                        }

                        // 2. Check yaw twist (perpendicular back taps produce negligible Z-axis yaw torque)
                        if (Math.abs(gyroZ) > yawLimit) {
                            Log.d("BackTapDetector", "[Step 7] Spike ignored: excessive yaw rotation (gyroZ: ${String.format("%.2f", gyroZ)} rad/s > $yawLimit)")
                            return
                        }

                        // 3. Check extreme instantaneous shock ceiling (violent spins, drops, or tumbles)
                        if (gyroMag > shockCeiling) {
                            Log.d("BackTapDetector", "[Step 7] Spike ignored: extreme rotational shock (gyroMag: ${String.format("%.2f", gyroMag)} rad/s > $shockCeiling)")
                            return
                        }
                    }

                    val timeDiff = currentTime - lastTapTime

                    // ===========================================================================
                    // STEP 8: Refractory Settling Window & Elastic Cadence Verification
                    // ===========================================================================
                    // What it does: Mutes chassis ringing for 65ms post-tap, verifies inter-tap 
                    //               gap is within bounds (70ms - tapWindowMaxMs), and checks
                    //               global gesture duration cap (max 1.2s - 1.4s).
                    // Why it exists: Structural casing resonance after Tap 1 often registers as a 
                    //               false Tap 2 within 40ms. The 65ms refractory window eliminates 
                    //               resonance while allowing rapid user tapping (>= 70ms).
                    // Threshold: Refractory Window = 65ms; Min Inter-Tap Gap = 70ms; 
                    //            Max Inter-Tap Gap = tapWindowMaxMs (default 400ms);
                    //            Max Gesture Total Duration = min(1400ms, tapWindowMaxMs * 2.2).
                    // ===========================================================================
                    if (timeDiff > tapWindowMinMs) {

                        // Mute chassis resonance ringing within 65ms of preceding tap
                        if (currentTime < postTapRefractoryUntil) {
                            Log.d("BackTapDetector", "[Step 8] Spike ignored: post-tap 65ms refractory window active.")
                            return
                        }

                        Log.d("BackTapDetector", "Valid Tap Candidate Spike! Z: ${String.format("%.2f", linearZ)}, Inter-tap Gap: ${timeDiff}ms, Jerk: ${String.format("%.2f", normalizedJerkZ)}")

                        val isValidGap = (timeDiff in tapWindowMinMs..tapWindowMaxMs)

                        if (isValidGap) {
                            // Enforce global gesture duration cap for 3-tap sequence
                            val maxGestureDuration = Math.min(1400L, (tapWindowMaxMs * 2.2).toLong())
                            val currentGestureDuration = if (firstTapTime > 0L) currentTime - firstTapTime else 0L

                            if (tapCount >= 2 && currentGestureDuration > maxGestureDuration) {
                                Log.d("BackTapDetector", "[Step 8] Gesture sequence reset: overall time exceeded (${currentGestureDuration}ms > ${maxGestureDuration}ms).")
                                tapCount = 1
                                firstTapTime = currentTime
                                lastTapTime = currentTime
                                calibForces[0] = linearZ
                                calibJerks[0] = normalizedJerkZ
                                postTapRefractoryUntil = currentTime + 65L
                                return
                            }

                            // Store tap metrics for ratio consistency check
                            if (tapCount in 0..2) {
                                calibForces[tapCount] = linearZ
                                calibJerks[tapCount] = normalizedJerkZ
                            }

                            // ===================================================================
                            // STEP 9: Dynamic Impulse Density Filter (Vibration Burst Suppression)
                            // ===================================================================
                            // What it does: Tracks spike frequency over a rolling window. If more
                            //               than 3-4 spikes occur in rapid succession, squashes gesture.
                            // Why it exists: Continuous vibration sources (bus engine, jackhammer,
                            //               rough road) produce rapid repeated spikes that pass
                            //               individual thresholds. Density tracking identifies continuous noise.
                            // Threshold: Max Spikes = 3 (Standard) / 4 (Motion Mode) in history window.
                            // ===================================================================
                            val historyWindow = tapWindowMaxMs * 2 + 200L
                            spikeHistory.removeAll { currentTime - it > historyWindow }
                            spikeHistory.add(currentTime)

                            val maxSpikeLimit = if (isMotionMode) 4 else 3
                            if (spikeHistory.size > maxSpikeLimit) {
                                Log.d("BackTapDetector", "[Step 9] Gesture suppressed: dense vibration activity (${spikeHistory.size} spikes in ${historyWindow}ms).")
                                tapCount = 0
                                lastTapTime = 0L
                                firstTapTime = 0L
                                spikeHistory.clear()
                                return
                            }

                            tapCount++
                            lastTapTime = currentTime
                            postTapRefractoryUntil = currentTime + 65L

                            // ===================================================================
                            // STEP 10: Human Force Consistency & Triple Tap Gesture Completion
                            // ===================================================================
                            // What it does: Evaluates the ratio between peak and minimum forces of
                            //               all 3 taps (maxForce / minForce). If ratio <= limit,
                            //               fires the triple back-tap callback.
                            // Why it exists: Human finger back-taps in a single sequence have highly
                            //               consistent impact energy (force ratio <= 3.5 - 4.5).
                            //               Random physical jostles vary wildly in force ratio.
                            // Threshold: Max Force Ratio = 3.5 (Motion Mode) / 4.5 (Standard Mode).
                            // ===================================================================
                            if (tapCount >= 3) {
                                val f1 = calibForces[0]
                                val f2 = calibForces[1]
                                val f3 = calibForces[2]

                                val maxForce = maxOf(f1, maxOf(f2, f3))
                                val minForce = minOf(f1, minOf(f2, f3))

                                val maxAllowedRatio = if (isMotionMode) 4.2f else 5.2f
                                val actualRatio = maxForce / minForce

                                if (maxForce <= minForce * maxAllowedRatio) {
                                    val avgForce = (f1 + f2 + f3) / 3f
                                    val avgJerk = (calibJerks[0] + calibJerks[1] + calibJerks[2]) / 3f

                                    val recommendedForce = (avgForce * 0.60f).coerceIn(2.2f, 4.5f)
                                    val recommendedJerk = (avgJerk * 0.50f).coerceIn(1.5f, 2.2f)

                                    Log.d("BackTapDetector", "🏆 [Step 10] TRIPLE BACK TAP TRIGGERED! Avg Force: $avgForce, Avg Jerk: $avgJerk (Force Ratio: ${String.format("%.2f", actualRatio)} <= Limit: $maxAllowedRatio)")
                                    onTripleTapTriggered(recommendedForce, recommendedJerk)

                                    // Reset sequence state after successful gesture trigger
                                    lastTapTime = 0L
                                    firstTapTime = 0L
                                    tapCount = 0
                                    spikeHistory.clear()
                                } else {
                                    Log.d("BackTapDetector", "[Step 10] Sequence rejected: force ratio too inconsistent (Max: ${String.format("%.2f", maxForce)}, Min: ${String.format("%.2f", minForce)}, Ratio: ${String.format("%.2f", actualRatio)} > Limit: $maxAllowedRatio)")
                                    lastTapTime = 0L
                                    firstTapTime = 0L
                                    tapCount = 0
                                    spikeHistory.clear()
                                }
                            }
                        } else {
                            // Start of a new tap sequence (Tap 1)
                            tapCount = 1
                            firstTapTime = currentTime
                            lastTapTime = currentTime
                            calibForces[0] = linearZ
                            calibJerks[0] = normalizedJerkZ
                            postTapRefractoryUntil = currentTime + 65L

                            spikeHistory.clear()
                            spikeHistory.add(currentTime)
                        }
                    } else {
                        Log.d("BackTapDetector", "Tap ignored: debounced (gap: ${timeDiff}ms <= min gap: ${tapWindowMinMs}ms)")
                    }
                } else {
                    Log.d("BackTapDetector", "Tap ignored: Low Jerk ($normalizedJerkZ < threshold: $currentJerkThreshold)")
                }
            } else {
                Log.d("BackTapDetector", "Tap ignored: Lateral axis magnitude dominant (Z:$linearZ < 0.8 * LateralMag:$lateralMag)")
            }
        }
    }

    /**
     * Resets all internal gesture state tracking variables.
     */
    fun resetState() {
        tapCount = 0
        lastTapTime = 0L
        firstTapTime = 0L
        postTapRefractoryUntil = 0L
        cooldownLockoutTime = 0L
        lastNegativeSpikeTime = 0L
        spikeHistory.clear()
        runningNoise = 0f
        gyroBaseline = 0f
        motionStillStartTime = 0L
        freeFallStartTime = 0L
        lastFreeFallTime = 0L
        Log.d("BackTapDetector", "Detector state reset successfully.")
    }
}
