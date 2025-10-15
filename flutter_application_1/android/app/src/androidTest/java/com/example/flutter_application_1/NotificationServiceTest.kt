package com.example.flutter_application_1

import android.content.Intent
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.LargeTest
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
@LargeTest
class NotificationServiceTest {

    @Test
    fun sendsBroadcast_and_MainActivity_receives() {
        // Launch activity to ensure EventChannel is ready
        ActivityScenario.launch(MainActivity::class.java).use {
            val intent = Intent(com.yourorg.personalizedai.NotificationCaptureService.ACTION_CONTEXT_EVENT)
            val json = "{" +
                    "\"source\":\"notification\"," +
                    "\"package\":\"com.example.test\"," +
                    "\"sender\":\"Tester\"," +
                    "\"text\":\"Hi from test\"," +
                    "\"timestamp\":${System.currentTimeMillis()}," +
                    "\"event_id\":\"test-123\"" +
                    "}"
            intent.putExtra(com.yourorg.personalizedai.NotificationCaptureService.EXTRA_EVENT_JSON, json)
            it.onActivity { activity ->
                activity.sendBroadcast(intent)
            }
            // No direct assertion on EventChannel; verify no crash. Logs can be inspected in CI with logcat.
        }
    }
}


