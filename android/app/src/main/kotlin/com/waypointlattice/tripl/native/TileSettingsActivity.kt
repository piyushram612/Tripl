package com.waypointlattice.tripl.native

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.service.quicksettings.TileService
import android.util.Log
import android.widget.Toast
import android.content.ComponentName
import com.waypointlattice.tripl.utils.BackTapService

class TileSettingsActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        try {
            val isServiceRunning = BackTapService.instance != null
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            
            if (isServiceRunning) {
                // Stop the service
                stopService(Intent(this, BackTapService::class.java))
                prefs.edit().putBoolean("flutter.back_tap_enabled", false).apply()
                Toast.makeText(this, "Back Tap Listener Disabled", Toast.LENGTH_SHORT).show()
            } else {
                // Start the service
                val serviceIntent = Intent(this, BackTapService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }
                prefs.edit().putBoolean("flutter.back_tap_enabled", true).apply()
                Toast.makeText(this, "Back Tap Listener Enabled", Toast.LENGTH_SHORT).show()
            }
            
            // Request the TileService to update the tile
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                TileService.requestListeningState(this, ComponentName(this, TriplTileService::class.java))
            }
        } catch (e: Exception) {
            Log.e("TileSettingsActivity", "Error toggling service on long press: ${e.message}", e)
        }
        
        finish()
    }
}
