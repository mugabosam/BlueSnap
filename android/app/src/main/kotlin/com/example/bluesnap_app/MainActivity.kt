package com.example.bluesnap_app

import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.view.WindowManager
// FlutterFragmentActivity is required by local_auth for the biometric prompt.
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // In release builds, block screenshots / screen recording and hide the
        // app's content in the recent-apps switcher — this protects the private
        // messages on screen. Debug builds stay capturable for development.
        val debuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!debuggable) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        }
    }
}
