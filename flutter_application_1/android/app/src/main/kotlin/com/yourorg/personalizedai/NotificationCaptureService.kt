package com.yourorg.personalizedai

import android.content.Context
import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.collection.LruCache
import okhttp3.ConnectionSpec
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * NotificationCaptureService
 *
 * Captures incoming notifications and emits sanitized context events.
 * - Dedupe by (package + id + postTime) with short TTL using in-memory cache
 * - Broadcasts locally via Intent for Flutter wrapper to receive
 * - Optionally forwards to backend if the app toggles server forwarding (via shared prefs)
 *
 * Permissions/Enablement:
 * - User must manually enable this app as a Notification Listener in Settings.
 * - Navigate users with: startActivity(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"))
 */
class NotificationCaptureService : NotificationListenerService() {

    private val cacheTtlMs: Long = TimeUnit.MINUTES.toMillis(2)
    private val cacheSize = 256
    private val recentEvents: LruCache<String, Long> = object : LruCache<String, Long>(cacheSize) {}

    private val okHttpClient: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectionSpecs(listOf(
                ConnectionSpec.CLEARTEXT,      // Allow HTTP
                ConnectionSpec.MODERN_TLS      // Keep HTTPS secure
            ))
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .build()
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "NotificationCaptureService created")
        initializeDefaultPreferences()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        Log.d(TAG, "=== NOTIFICATION CAPTURED ===")
        Log.d(TAG, "Notification service is active.")
        
        if (sbn == null) {
            Log.w(TAG, "Received null notification")
            return
        }

        val pkg = sbn.packageName ?: return
        val notification = sbn.notification ?: return

        Log.d(TAG, "Notification received from: $pkg")

        val extras = notification.extras
        val title = extras?.getCharSequence("android.title")?.toString() ?: ""
        var text = extras?.getCharSequence("android.text")?.toString() ?: ""
        // Enhance extraction for apps like WhatsApp that use bigText or textLines
        if (text.isEmpty()) {
            val bigText = extras?.getCharSequence("android.bigText")?.toString()
            if (!bigText.isNullOrEmpty()) text = bigText
        }
        if (text.isEmpty()) {
            val lines = extras?.getCharSequenceArray("android.textLines")
            if (lines != null && lines.isNotEmpty()) {
                text = lines.joinToString(" ") { it.toString() }
            }
        }
        if (text.isEmpty()) {
            val sub = extras?.getCharSequence("android.subText")?.toString()
            if (!sub.isNullOrEmpty()) text = sub
        }
        val timestamp = sbn.postTime
        val notificationId = sbn.id

        Log.d(TAG, "Extracted notification - Title: '$title', Text: '$text', Timestamp: $timestamp")

        val key = "$pkg#$notificationId#${timestamp}"
        val now = System.currentTimeMillis()
        val lastSeen = recentEvents.get(key)
        if (lastSeen != null && now - lastSeen < cacheTtlMs) {
            Log.d(TAG, "Dropping duplicate notification within TTL")
            return // drop duplicate within TTL
        }
        recentEvents.put(key, now)

        // Check if this is a WhatsApp notification
        if (pkg == "com.whatsapp" && text.isNotEmpty()) {
            Log.d(TAG, "WhatsApp notification captured.")
            
            // Filter out system messages and only process actual user messages
            if (isActualWhatsAppMessage(title, text)) {
                Log.d(TAG, "Processing actual WhatsApp message content")
                handleWhatsAppNotification(title, text, timestamp)
            } else {
                Log.d(TAG, "Skipping WhatsApp system notification: '$text'")
            }
        }

        // ALWAYS broadcast ALL notifications to Flutter UI (including WhatsApp)
        val event = JSONObject().apply {
            put("package", pkg)
            put("title", title)
            put("text", text)
            put("timestamp", timestamp)
            put("notificationId", notificationId)
            put("source", "notification")
            put("meta", JSONObject())
        }

        Log.d(TAG, "Constructed JSON payload: ${event.toString()}")

        // Emit locally for Flutter - THIS IS CRITICAL FOR LIVE NOTIFICATIONS
        try {
            Log.d(TAG, "Broadcasting notification to Flutter UI...")
            sendLocalBroadcast(this, event)
            Log.d(TAG, "Notification broadcast sent successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to broadcast notification to Flutter UI", e)
        }

        // Optionally forward to backend based on shared preference set by Flutter UI
        if (shouldForwardToServer(this)) {
            Log.d(TAG, "Forwarding notification to backend")
            forwardToBackendAsync(this, event)
        } else {
            Log.d(TAG, "Server forwarding disabled, skipping backend call")
        }
    }

    private fun sendLocalBroadcast(context: Context, event: JSONObject) {
        val intent = Intent(ACTION_CONTEXT_EVENT)
        intent.putExtra(EXTRA_EVENT_JSON, event.toString())
        Log.d(TAG, "Sending broadcast with action: $ACTION_CONTEXT_EVENT")
        Log.d(TAG, "Broadcast data: ${event.toString()}")
        context.sendBroadcast(intent)
        Log.d(TAG, "Broadcast sent successfully")
    }

    private fun isActualWhatsAppMessage(title: String, text: String): Boolean {
        // Filter out system messages and notifications
        val systemMessages = listOf(
            "new messages",
            "new message", 
            "checking for new messages",
            "checking for messages",
            "messages",
            "message",
            "missed call",
            "missed calls",
            "call",
            "calls",
            "voice message",
            "voice messages",
            "photo",
            "photos",
            "video",
            "videos",
            "document",
            "documents",
            "sticker",
            "stickers",
            "location",
            "contact",
            "contacts",
            "group",
            "groups",
            "broadcast",
            "broadcasts"
        )
        
        val textLower = text.lowercase().trim()
        val titleLower = title.lowercase().trim()
        
        // Skip if text is just a number (like "2" for "2 new messages")
        if (textLower.matches(Regex("^\\d+$"))) {
            return false
        }
        
        // Skip if text contains system message keywords
        for (systemMsg in systemMessages) {
            if (textLower.contains(systemMsg) || titleLower.contains(systemMsg)) {
                return false
            }
        }
        
        // Skip very short messages that are likely system notifications
        if (textLower.length < 3 && !textLower.matches(Regex("^[a-zA-Z0-9]+$"))) { // Allow short actual words/codes
            return false
        }
        
        // Skip messages that are just punctuation or symbols
        if (textLower.matches(Regex("^[\\s\\p{Punct}]+$"))) {
            return false
        }
        
        // This looks like an actual user message
        return true
    }

    private fun shouldForwardToServer(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        // **FIX**: Changed default value from 'ture' (typo) to 'true'
        return prefs.getBoolean(KEY_SERVER_FORWARDING_ENABLED, true)
    }

    private fun initializeDefaultPreferences() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        
        // Set defaults if not already set
        if (!prefs.contains(KEY_SERVER_FORWARDING_ENABLED)) {
            editor.putBoolean(KEY_SERVER_FORWARDING_ENABLED, true)
            Log.d(TAG, "Initialized server forwarding to true")
        }
        
        if (!prefs.contains(KEY_BACKEND_URL)) {
            editor.putString(KEY_BACKEND_URL, "http://192.168.29.143:8000")
            Log.d(TAG, "Initialized backend URL to default")
        }
        
        if (!prefs.contains(KEY_USER_ID)) {
            editor.putString(KEY_USER_ID, "device")
            Log.d(TAG, "Initialized user ID to device")
        }
        
        editor.apply()
    }

    private fun handleWhatsAppNotification(title: String, text: String, timestamp: Long) {
        Log.d(TAG, "Processing WhatsApp notification - Title: '$title', Text: '$text'")
        
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        
        val backendUrl = prefs.getString(KEY_BACKEND_URL, "http://192.168.29.143:8000")
        val userId = prefs.getString(KEY_USER_ID, "device") ?: "device"
        val serverForwardingEnabled = prefs.getBoolean(KEY_SERVER_FORWARDING_ENABLED, true)

        Log.d(TAG, "WhatsApp forwarding config - Backend URL: $backendUrl, User ID: $userId, Server Forwarding: $serverForwardingEnabled")

        // Always proceed with WhatsApp forwarding (server forwarding is enabled by default)
        if (!serverForwardingEnabled) {
            Log.d(TAG, "Server forwarding disabled, skipping WhatsApp backend call")
            return
        }
        
        if (backendUrl == null || backendUrl.isEmpty()) {
            Log.d(TAG, "Backend URL not configured, skipping WhatsApp backend call")
            return
        }

        // Extract sender from title (WhatsApp format: "Sender Name" or "Group Name")
        val sender = title.ifEmpty { "Unknown" }

        val whatsappData = JSONObject().apply {
            put("sender", sender)
            put("message", text)
            put("timestamp", timestamp)
            put("user_id", userId)
        }

        Log.d(TAG, "WhatsApp JSON payload: ${whatsappData.toString()}")

        Thread {
            try {
                val url = if (backendUrl.endsWith("/")) backendUrl + "api/whatsapp/add" else backendUrl + "/api/whatsapp/add"
                Log.d(TAG, "Sending WhatsApp data to: $url")
                Log.d(TAG, "OkHttp client configured with CLEARTEXT support")
                
                val mediaType = "application/json; charset=utf-8".toMediaType()
                val body = whatsappData.toString().toRequestBody(mediaType)
                val request = Request.Builder()
                    .url(url)
                    .post(body)
                    .header("Content-Type", "application/json")
                    .build()
                
                Log.d(TAG, "Payload: ${whatsappData.toString()}")
                val response = okHttpClient.newCall(request).execute()
                
                if (response.isSuccessful) {
                    Log.d(TAG, "Backend response: ${response.code} ${response.message}")
                } else {
                    Log.w(TAG, "Backend responded with ${response.code} ${response.message}")
                }
                response.close()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to forward WhatsApp message", e)
            }
        }.start()
    }

    private fun forwardToBackendAsync(context: Context, event: JSONObject) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val backendUrl = prefs.getString(KEY_BACKEND_URL, null) ?: return
        val userId = prefs.getString(KEY_USER_ID, "device") ?: "device"
        val payload = JSONObject(event.toString()).apply { put("user_id", userId) }

        Thread {
            try {
                val mediaType = "application/json; charset=utf-8".toMediaType()
                val body = payload.toString().toRequestBody(mediaType)
                val request = Request.Builder()
                    .url(backendUrl.trimEnd('/') + "/api/ingest/context_event")
                    .post(body)
                    .build()
                
                Log.d(TAG, "Sending notification payload to backend: ${request.url}")
                Log.d(TAG, "Payload: ${payload.toString()}")
                val response = okHttpClient.newCall(request).execute()
                Log.d(TAG, "Notification forwarded successfully - Response code: ${response.code}")
                if (!response.isSuccessful) {
                    Log.w(TAG, "Backend returned error: ${response.code} ${response.message}")
                }
                response.close()
            } catch (t: Throwable) {
                Log.e(TAG, "Failed to forward context event to backend", t)
            }
        }.start()
    }

    companion object {
        const val TAG: String = "NotifCaptureService"
        const val ACTION_CONTEXT_EVENT: String = "com.yourorg.personalizedai.CONTEXT_EVENT"
        const val EXTRA_EVENT_JSON: String = "event_json"

        // Shared preferences keys configured by Flutter UI
        const val PREFS_NAME: String = "personalized_ai_prefs"
        const val KEY_SERVER_FORWARDING_ENABLED: String = "server_forwarding_enabled"
        const val KEY_BACKEND_URL: String = "backend_url"
        const val KEY_USER_ID: String = "user_id"
    }
}