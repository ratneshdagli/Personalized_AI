package com.example.figma

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MyAppDeepLink", "onCreate intent=${intent?.dataString}")
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d("MyAppDeepLink", "onNewIntent: ${intent?.dataString}")
        Log.d(TAG, "onNewIntent called with: ${intent.data}")
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_VIEW && intent.data != null) {
            val data = intent.data
            Log.d(TAG, "Received intent with data: $data")
            Log.d(TAG, "Scheme: ${data?.scheme}, Host: ${data?.host}, Path: ${data?.path}")
            
            // Forward the intent to the Flutter side if needed
            // FlutterWebAuth2Plugin.setPendingIntent(intent)
        } else {
            Log.d(TAG, "No data in intent or not an ACTION_VIEW intent")
        }
    }
}
