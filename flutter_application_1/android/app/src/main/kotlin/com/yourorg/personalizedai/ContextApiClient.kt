package com.yourorg.personalizedai

import android.content.Context
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

object ContextApiClient {
    private val client = OkHttpClient()

    private fun epochMsToIso(ts: Long): String {
        // Basic ISO8601 without timezone conversion (UTC 'Z')
        val sdf = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
        sdf.timeZone = java.util.TimeZone.getTimeZone("UTC")
        return sdf.format(java.util.Date(ts))
    }

    fun postCanonicalEvent(context: Context, rawEventJson: String) {
        val prefs = context.getSharedPreferences(NotificationCaptureService.PREFS_NAME, Context.MODE_PRIVATE)
        val baseUrl = prefs.getString(NotificationCaptureService.KEY_BACKEND_URL, null) ?: return

        val event = org.json.JSONObject(rawEventJson)
        val appName = event.optString("package", "")
        val title = event.optString("sender", event.optString("title", ""))
        val message = event.optString("text", "")
        val ts = event.optLong("timestamp", System.currentTimeMillis())
        val isoTs = epochMsToIso(ts)

        val backendPayload = org.json.JSONObject()
            .put("app_name", appName)
            .put("title", title)
            .put("message", message)
            .put("timestamp", isoTs)

        val mediaType = "application/json; charset=utf-8".toMediaType()
        val request = Request.Builder()
            .url(baseUrl.trimEnd('/') + "/api/ingest/context_event")
            .post(backendPayload.toString().toRequestBody(mediaType))
            .build()

        Thread {
            runCatching { client.newCall(request).execute().use { } }
        }.start()
    }
}


