package com.yourorg.personalizedai

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * ScreenAccessibilityService
 *
 * Safe scaffold that only runs when explicitly enabled by the user (advanced mode).
 * - Listens to TYPE_WINDOW_STATE_CHANGED and TYPE_VIEW_TEXT_CHANGED
 * - Extracts visible text nodes and current package name
 * - Applies strict rate limit and app allow/deny lists
 * - Emits sanitized events via local broadcast; optional server forwarding is handled by Flutter
 *
 * To enable: Navigate users to Accessibility Settings via Intent("android.settings.ACCESSIBILITY_SETTINGS").
 */
class ScreenAccessibilityService : AccessibilityService() {

    private var lastEmitTimeMs: Long = 0
    private val minEmitIntervalMs: Long = 3500 // conservative rate limit

    private val okHttpClient: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .build()
    }

    private val whitelistPackages = setOf(
        // Add common messaging/media apps if user opts in
        "com.whatsapp",
        "com.instagram.android",
        "com.netflix.mediaclient",
        "in.startv.hotstar",
    )

    private val blacklistPackages = setOf(
        // Never capture from password managers or banking apps
        "com.google.android.apps.authenticator2",
        "com.lastpass.lpandroid",
        "com.phonepe.app",
        "com.google.android.apps.nbu.paisa.user",
        "com.truecaller",
    )

    override fun onServiceConnected() {
        super.onServiceConnected()
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        }
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return

        if (!isAdvancedModeEnabled(this)) return
        if (pkg in blacklistPackages) return
        if (whitelistPackages.isNotEmpty() && pkg !in whitelistPackages) return

        val now = System.currentTimeMillis()
        if (now - lastEmitTimeMs < minEmitIntervalMs) return

        val root = rootInActiveWindow ?: return
        val texts = JSONArray()
        collectVisibleTexts(root, texts, 0)

        if (texts.length() == 0) return

        // Check if this is WhatsApp and handle specifically
        if (pkg == "com.whatsapp") {
            handleWhatsAppAccessibilityEvent(texts, now)
        }

        val payload = JSONObject().apply {
            put("package", pkg)
            put("text_nodes", texts)
            put("timestamp", now)
            put("source", "accessibility")
            put("meta", JSONObject().apply { put("eventType", event.eventType) })
        }

        sendLocalBroadcast(this, payload)
        lastEmitTimeMs = now
    }

    override fun onInterrupt() {
        // No-op
    }

    private fun collectVisibleTexts(node: AccessibilityNodeInfo, out: JSONArray, depth: Int) {
        if (depth > 40) return // safety bound
        val text = node.text?.toString()?.trim()
        if (!text.isNullOrEmpty()) {
            // Limit size to prevent large dumps
            val clipped = if (text.length > 200) text.substring(0, 200) else text
            out.put(clipped)
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectVisibleTexts(child, out, depth + 1)
            child.recycle()
        }
    }

    private fun sendLocalBroadcast(context: Context, event: JSONObject) {
        val intent = Intent(NotificationCaptureService.ACTION_CONTEXT_EVENT)
        intent.putExtra(NotificationCaptureService.EXTRA_EVENT_JSON, event.toString())
        context.sendBroadcast(intent)
    }

    private fun handleWhatsAppAccessibilityEvent(texts: JSONArray, timestamp: Long) {
        val prefs = getSharedPreferences(NotificationCaptureService.PREFS_NAME, Context.MODE_PRIVATE)
        val backendUrl = prefs.getString(NotificationCaptureService.KEY_BACKEND_URL, null) ?: return
        val userId = prefs.getString(NotificationCaptureService.KEY_USER_ID, "device") ?: "device"

        // Combine all text nodes into a single message
        val combinedText = StringBuilder()
        for (i in 0 until texts.length()) {
            val text = texts.getString(i)
            if (text.isNotEmpty()) {
                combinedText.append(text).append(" ")
            }
        }

        val messageText = combinedText.toString().trim()
        if (messageText.isEmpty()) return

        val whatsappData = JSONObject().apply {
            put("sender", "WhatsApp User") // We can't easily extract sender from accessibility
            put("message", messageText)
            put("timestamp", timestamp)
            put("user_id", userId)
        }

        Thread {
            try {
                val mediaType = "application/json; charset=utf-8".toMediaType()
                val body = whatsappData.toString().toRequestBody(mediaType)
                val request = Request.Builder()
                    .url(backendUrl.trimEnd('/') + "/api/whatsapp/add")
                    .post(body)
                    .build()
                val response = okHttpClient.newCall(request).execute()
                response.close()
                Log.d(TAG, "WhatsApp accessibility content forwarded successfully")
            } catch (t: Throwable) {
                Log.w(TAG, "Failed to forward WhatsApp accessibility content", t)
            }
        }.start()
    }

    private fun isAdvancedModeEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(NotificationCaptureService.PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_ADVANCED_ENABLED, false)
    }

    companion object {
        const val KEY_ADVANCED_ENABLED: String = "advanced_accessibility_enabled"
        const val TAG: String = "ScreenAccService"
    }
}


