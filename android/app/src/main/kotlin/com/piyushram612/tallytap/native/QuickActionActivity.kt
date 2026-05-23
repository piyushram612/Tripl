package com.piyushram612.tallytap.native

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.piyushram612.tallytap.ui.PopupActivity

class QuickActionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Immediately trigger transparent Dialog popup activity
        val intent = Intent(this, PopupActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        startActivity(intent)
        
        // Finalize lightweight redirect instantly
        finish()
        overridePendingTransition(0, 0)
    }
}
