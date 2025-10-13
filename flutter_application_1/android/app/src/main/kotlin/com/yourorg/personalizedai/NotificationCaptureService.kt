package com.yourorg.personalizedai

import android.content.Context
import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.collection.LruCache
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
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .build()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val pkg = sbn.packageName ?: return
        val notification = sbn.notification ?: return

        val extras = notification.extras
        val title = extras?.getCharSequence("android.title")?.toString() ?: ""
        val text = extras?.getCharSequence("android.text")?.toString() ?: ""
        val timestamp = sbn.postTime
        val notificationId = sbn.id

        val key = "$pkg#$notificationId#${timestamp}"
        val now = System.currentTimeMillis()
        val lastSeen = recentEvents.get(key)
        if (lastSeen != null && now - lastSeen < cacheTtlMs) {
            return // drop duplicate within TTL
        }
        recentEvents.put(key, now)

        val event = JSONObject().apply {
            put("package", pkg)
            put("title", title)
            put("text", text)
            put("timestamp", timestamp)
            put("notificationId", notificationId)
            put("source", "notification")
            put("meta", JSONObject())
        }

        // Emit locally for Flutter
        sendLocalBroadcast(this, event)

        // Optionally forward to backend based on shared preference set by Flutter UI
        if (shouldForwardToServer(this)) {
            forwardToBackendAsync(this, event)
        }
    }

    private fun sendLocalBroadcast(context: Context, event: JSONObject) {
        val intent = Intent(ACTION_CONTEXT_EVENT)
        intent.putExtra(EXTRA_EVENT_JSON, event.toString())
        context.sendBroadcast(intent)
    }

    private fun shouldForwardToServer(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_SERVER_FORWARDING_ENABLED, false)
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
                val response = okHttpClient.newCall(request).execute()
                response.close()
            } catch (t: Throwable) {
                Log.w(TAG, "Failed to forward context event", t)
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


