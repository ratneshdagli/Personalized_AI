package com.example.figma

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.content.Intent
import android.util.Log

class NotificationService : NotificationListenerService() {
    private val TAG = "NotificationService"

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            val packageName = sbn.packageName
            val extras = sbn.notification.extras
            val title = extras.getString("android.title") ?: ""
            val text = extras.getCharSequence("android.text")?.toString() ?: ""

            Log.d(TAG, "Notification from $packageName: $title - $text")

            // Broadcast to MainActivity
            val intent = Intent("com.personalized_ai.NOTIFICATION_POSTED")
            intent.putExtra("package", packageName)
            intent.putExtra("sender", title)
            intent.putExtra("text", text)
            intent.putExtra("timestamp", sbn.postTime)
            intent.setPackage(this.packageName) // Restrict to own app
            sendBroadcast(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error processing notification", e)
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // Optional: Handle removal
    }
}
