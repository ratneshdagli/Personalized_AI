package com.yourorg.personalizedai

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.json.JSONObject
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class NotificationServiceTest {

    @Test
    fun receivesContextEventBroadcast() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val queue = ArrayBlockingQueue<String>(1)
        val filter = IntentFilter(NotificationCaptureService.ACTION_CONTEXT_EVENT)
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                val json = intent?.getStringExtra(NotificationCaptureService.EXTRA_EVENT_JSON)
                if (json != null) queue.offer(json)
            }
        }
        context.registerReceiver(receiver, filter)
        try {
            // Simulate a fake event
            val event = JSONObject().apply {
                put("package", "com.example.app")
                put("title", "Hello")
                put("text", "World")
                put("timestamp", System.currentTimeMillis())
                put("notificationId", 123)
                put("source", "notification")
                put("meta", JSONObject())
            }
            val intent = Intent(NotificationCaptureService.ACTION_CONTEXT_EVENT)
            intent.putExtra(NotificationCaptureService.EXTRA_EVENT_JSON, event.toString())
            context.sendBroadcast(intent)

            val received = queue.poll(2, TimeUnit.SECONDS)
            assertTrue("Expected to receive a context event broadcast", received != null)
        } finally {
            context.unregisterReceiver(receiver)
        }
    }
}


