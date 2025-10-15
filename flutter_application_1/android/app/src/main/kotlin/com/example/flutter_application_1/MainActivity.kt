package com.example.flutter_application_1

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.provider.Settings

class MainActivity : FlutterActivity() {
    private val eventChannelName = "com.yourorg.personalizedai/context_events"
    private val methodChannelName = "com.yourorg.personalizedai/settings"
    private var eventsSink: EventChannel.EventSink? = null
    private var receiverRegistered = false

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.action ?: return
            android.util.Log.d("MainActivity", "Received broadcast with action: $action")
            if (action == com.yourorg.personalizedai.NotificationCaptureService.ACTION_CONTEXT_EVENT) {
                val json = intent.getStringExtra(com.yourorg.personalizedai.NotificationCaptureService.EXTRA_EVENT_JSON)
                android.util.Log.d("MainActivity", "Received event for Flutter: $json")
                json?.let { 
                    android.util.Log.d("MainActivity", "Forwarding to Flutter via EventChannel")
                    eventsSink?.success(it)
                    android.util.Log.d("MainActivity", "Successfully forwarded to Flutter")
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    android.util.Log.d("MainActivity", "Flutter started listening to events")
                    eventsSink = events
                    registerReceiverIfNeeded()
                }

                override fun onCancel(arguments: Any?) {
                    android.util.Log.d("MainActivity", "Flutter stopped listening to events")
                    eventsSink = null
                    unregisterReceiverIfNeeded()
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                val prefs = applicationContext.getSharedPreferences(
                    com.yourorg.personalizedai.NotificationCaptureService.PREFS_NAME,
                    Context.MODE_PRIVATE
                )
                when (call.method) {
                    "setServerForwarding" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        prefs.edit().putBoolean(
                            com.yourorg.personalizedai.NotificationCaptureService.KEY_SERVER_FORWARDING_ENABLED,
                            enabled
                        ).apply()
                        result.success(true)
                    }
                    "setBackendUrl" -> {
                        val url = call.argument<String>("url") ?: ""
                        prefs.edit().putString(
                            com.yourorg.personalizedai.NotificationCaptureService.KEY_BACKEND_URL,
                            url
                        ).apply()
                        result.success(true)
                    }
                    "setUserId" -> {
                        val userId = call.argument<String>("userId") ?: "device"
                        prefs.edit().putString(
                            com.yourorg.personalizedai.NotificationCaptureService.KEY_USER_ID,
                            userId
                        ).apply()
                        result.success(true)
                    }
                    "setAdvancedAccessibility" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        prefs.edit().putBoolean(
                            com.yourorg.personalizedai.ScreenAccessibilityService.KEY_ADVANCED_ENABLED,
                            enabled
                        ).apply()
                        result.success(true)
                    }
                    "getStatus" -> {
                        val status = mapOf(
                            "serverForwarding" to prefs.getBoolean(
                                com.yourorg.personalizedai.NotificationCaptureService.KEY_SERVER_FORWARDING_ENABLED,
                                true
                            ),
                            "backendUrl" to prefs.getString(
                                com.yourorg.personalizedai.NotificationCaptureService.KEY_BACKEND_URL,
                                ""
                            ),
                            "userId" to prefs.getString(
                                com.yourorg.personalizedai.NotificationCaptureService.KEY_USER_ID,
                                "device"
                            ),
                            "advancedAccessibility" to prefs.getBoolean(
                                com.yourorg.personalizedai.ScreenAccessibilityService.KEY_ADVANCED_ENABLED,
                                false
                            ),
                            "notificationAccessEnabled" to isNotificationListenerEnabled(),
                            "accessibilityEnabled" to isAccessibilityServiceEnabled(),
                            "receiverRegistered" to receiverRegistered,
                            "eventsSinkActive" to (eventsSink != null)
                        )
                        android.util.Log.d("MainActivity", "Status: $status")
                        result.success(status)
                    }
                    "openNotificationListenerSettings" -> {
                        startActivity(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    }
                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    }
                    "testNotification" -> {
                        android.util.Log.d("MainActivity", "Sending test notification to Flutter")
                        val testEvent = mapOf(
                            "package" to "com.example.test",
                            "title" to "Test Notification",
                            "text" to "This is a test notification to verify Flutter UI is working",
                            "timestamp" to System.currentTimeMillis(),
                            "notificationId" to 999,
                            "source" to "test",
                            "meta" to mapOf<String, Any>()
                        )
                        val json = org.json.JSONObject(testEvent).toString()
                        android.util.Log.d("MainActivity", "Test notification JSON: $json")
                        eventsSink?.success(json)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun registerReceiverIfNeeded() {
        if (!receiverRegistered) {
            android.util.Log.d("MainActivity", "Registering broadcast receiver")
            val filter = IntentFilter(com.yourorg.personalizedai.NotificationCaptureService.ACTION_CONTEXT_EVENT)
            // Restrict to our package broadcasts
            filter.addAction(com.yourorg.personalizedai.NotificationCaptureService.ACTION_CONTEXT_EVENT)
            // Add the RECEIVER_NOT_EXPORTED flag for Android 13+ (API 33+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(receiver, filter)
            }
            receiverRegistered = true
            android.util.Log.d("MainActivity", "Broadcast receiver registered successfully")
        }
    }

    private fun unregisterReceiverIfNeeded() {
        if (receiverRegistered) {
            unregisterReceiver(receiver)
            receiverRegistered = false
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiverIfNeeded()
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val cn = componentName.packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        return flat.contains(cn)
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expected = "${packageName}/com.yourorg.personalizedai.ScreenAccessibilityService"
        val flat = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        return flat.split(":").any { it.equals(expected, ignoreCase = true) }
    }
}
