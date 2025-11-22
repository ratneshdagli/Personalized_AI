package com.example.figma

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"
    private val CHANNEL = "com.personalized_ai.app/notifications"
    private var methodChannel: MethodChannel? = null

    private val notificationReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.personalized_ai.NOTIFICATION_POSTED") {
                val packageName = intent.getStringExtra("package")
                val sender = intent.getStringExtra("sender")
                val text = intent.getStringExtra("text")
                val timestamp = intent.getLongExtra("timestamp", 0)

                Log.d(TAG, "Forwarding notification to Flutter: $sender - $text")

                val payload = mapOf(
                    "app" to packageName,
                    "sender" to sender,
                    "text" to text,
                    "timestamp" to timestamp
                )

                methodChannel?.invokeMethod("onNotificationPosted", payload)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationAccessGranted" -> {
                    result.success(isNotificationServiceEnabled())
                }
                "openNotificationAccessSettings" -> {
                    startActivity(Intent(android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val pkgName = packageName
        val flat = android.provider.Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (!flat.isNullOrEmpty()) {
            val names = flat.split(":").toTypedArray()
            for (name in names) {
                val componentName = android.content.ComponentName.unflattenFromString(name)
                if (componentName != null) {
                    if (componentName.packageName == pkgName) {
                        return true
                    }
                }
            }
        }
        return false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MyAppDeepLink", "onCreate intent=${intent?.dataString}")
        handleIntent(intent)
        
        val filter = IntentFilter("com.personalized_ai.NOTIFICATION_POSTED")
        registerReceiver(notificationReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(notificationReceiver)
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
