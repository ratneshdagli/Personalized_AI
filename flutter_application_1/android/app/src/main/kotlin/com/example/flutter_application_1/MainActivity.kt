package com.example.flutter_application_1

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val eventChannelName = "com.yourorg.personalizedai/context_events"
    private val methodChannelName = "com.yourorg.personalizedai/settings"
    private var eventsSink: EventChannel.EventSink? = null
    private var receiverRegistered = false

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.action ?: return
            if (action == com.yourorg.personalizedai.NotificationCaptureService.ACTION_CONTEXT_EVENT) {
                val json = intent.getStringExtra(com.yourorg.personalizedai.NotificationCaptureService.EXTRA_EVENT_JSON)
                json?.let { eventsSink?.success(it) }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventsSink = events
                    registerReceiverIfNeeded()
                }

                override fun onCancel(arguments: Any?) {
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
                                false
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
                            )
                        )
                        result.success(status)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun registerReceiverIfNeeded() {
        if (!receiverRegistered) {
            val filter = IntentFilter(com.yourorg.personalizedai.NotificationCaptureService.ACTION_CONTEXT_EVENT)
            registerReceiver(receiver, filter)
            receiverRegistered = true
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
}
