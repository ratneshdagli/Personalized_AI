package com.yourorg.personalizedai

import android.content.Context
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

object ContextApiClient {
    private val client = OkHttpClient()

    fun postEvent(context: Context, json: String) {
        val prefs = context.getSharedPreferences(NotificationCaptureService.PREFS_NAME, Context.MODE_PRIVATE)
        val baseUrl = prefs.getString(NotificationCaptureService.KEY_BACKEND_URL, null) ?: return
        val mediaType = "application/json; charset=utf-8".toMediaType()
        val request = Request.Builder()
            .url(baseUrl.trimEnd('/') + "/api/ingest/context_event")
            .post(json.toRequestBody(mediaType))
            .build()
        Thread {
            runCatching { client.newCall(request).execute().use { } }
        }.start()
    }
}


