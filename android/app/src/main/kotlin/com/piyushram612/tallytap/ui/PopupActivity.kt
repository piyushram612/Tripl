package com.piyushram612.tallytap.ui

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.view.WindowCompat
import com.piyushram612.tallytap.ui.components.PopupCard
import com.piyushram612.tallytap.ui.theme.TallyTapTheme

class PopupActivity : ComponentActivity() {

    companion object {
        private const val TAG = "PopupActivity"
        private var activeInstance: PopupActivity? = null
        
        /**
         * Closes the active PopupActivity instance if it is currently displayed on screen.
         * @return true if an active instance was found and dismissed, false otherwise.
         */
        fun dismissActiveInstance(): Boolean {
            activeInstance?.let {
                Log.d(TAG, "dismissActiveInstance: Active popup found, dismissing instantly...")
                it.finish()
                activeInstance = null
                return true
            }
            return false
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate: Registering active popup instance")
        activeInstance = this
        
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        // Remove transitions so the card appears instantly on top of the translucent window dim
        overridePendingTransition(0, 0)

        setContent {
            TallyTapTheme {
                PopupCard(
                    onClose = {
                        finish()
                        overridePendingTransition(0, 0)
                    }
                )
            }
        }
    }

    override fun finish() {
        if (activeInstance == this) {
            activeInstance = null
        }
        super.finish()
        // Ensure no entrance/exit flashing during native dismiss
        overridePendingTransition(0, 0)
    }

    override fun onDestroy() {
        if (activeInstance == this) {
            activeInstance = null
        }
        Log.d(TAG, "onDestroy: Unregistering active popup instance")
        super.onDestroy()
    }
}
