package com.oasis.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Base64
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import java.io.File
import java.nio.charset.StandardCharsets

class OasisMessagingService : FirebaseMessagingService() {
    companion object {
        private const val TAG = "OasisMessagingService"
        private const val CHANNEL_ID = "oasis_channel"
        private const val SECURE_STORAGE_NAME = "FlutterSecureStorage"
        private const val STATE_ENC_KEY = "key_pq_aura_state_encryption_key"
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        Log.d(TAG, "Push received from: ${remoteMessage.from}")

        val data = remoteMessage.data
        if (data.isEmpty()) return

        val isEncrypted = data["encrypted_keys"] != null || data["signal_message_type"] != null
        val messageType = data["message_type"] ?: data["type"]

        if (messageType == "call") {
            launchCallActivity(data)
            return
        }
        
        if (isEncrypted) {
            decryptAndShowNotification(data)
        } else {
            showNotification(
                data["title"] ?: "New Notification",
                data["body"] ?: "",
                data
            )
        }
    }

    private fun launchCallActivity(data: Map<String, String>) {
        val intent = Intent(this, OasisCallActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("callerName", data["title"] ?: "Someone")
            putExtra("callId", data["call_id"] ?: "")
            putExtra("callerAvatar", data["sender_avatar"] ?: "")
        }

        // We also need to build a high-priority notification with a full-screen intent
        // This ensures the OS actually wakes up the screen and shows our Activity
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "oasis_call_channel",
                "Oasis Calls",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setSound(null, null) // Handled by Flutter later or play custom ringtone here
            }
            notificationManager.createNotificationChannel(channel)
        }

        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationBuilder = NotificationCompat.Builder(this, "oasis_call_channel")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Incoming Call")
            .setContentText(data["title"] ?: "Someone is calling")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(pendingIntent, true)
            .setAutoCancel(true)

        notificationManager.notify(1001, notificationBuilder.build())
        
        // Try starting the activity directly as well
        try {
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start CallActivity directly", e)
        }
    }

    private fun decryptAndShowNotification(data: Map<String, String>) {
        var statePtr: Long = 0
        try {
            val senderId = data["sender_id"] ?: data["actor_id"] ?: return
            
            // 1. Get Encryption Key from Secure Storage
            val masterKey = MasterKey.Builder(this)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            val sharedPrefs = EncryptedSharedPreferences.create(
                this,
                SECURE_STORAGE_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )

            val base64Key = sharedPrefs.getString(STATE_ENC_KEY, null) ?: return
            val encryptionKey = Base64.decode(base64Key, Base64.DEFAULT)

            // 2. Construct Path (Flutter's applicationSupportDirectory)
            // Path: /data/user/0/com.oasis.app/files/pqa_sessions/session_$id.pqa
            val sessionFile = File(filesDir, "pqa_sessions/session_$senderId.pqa")
            if (!sessionFile.exists()) {
                Log.e(TAG, "Session file not found: ${sessionFile.absolutePath}")
                return
            }

            // 3. Load State Atomic
            statePtr = PqAuraNative.loadAtomic(sessionFile.absolutePath, encryptionKey)
            if (statePtr == 0L) {
                Log.e(TAG, "Failed to load ratchet state")
                showNotification(data["title"] ?: "New Message", "🔒 Encrypted message", data)
                return
            }

            // 4. Decrypt
            val header = Base64.decode(data["header"] ?: "", Base64.DEFAULT)
            val ciphertext = Base64.decode(data["content"] ?: data["body"] ?: "", Base64.DEFAULT)
            val ad = (data["ad"] ?: "").toByteArray(StandardCharsets.UTF_8)

            val plaintext = PqAuraNative.decrypt(statePtr, header, ciphertext, ad)

            if (plaintext != null) {
                // 5. Save Updated State
                PqAuraNative.saveAtomic(statePtr, sessionFile.absolutePath, encryptionKey)
                
                showNotification(
                    data["title"] ?: "New Message",
                    String(plaintext, StandardCharsets.UTF_8),
                    data
                )
            } else {
                showNotification(data["title"] ?: "New Message", "🔒 Decryption failed", data)
            }

        } catch (e: Exception) {
            Log.e(TAG, "Native decryption error", e)
            showNotification(data["title"] ?: "New Message", "🔒 Encrypted message", data)
        } finally {
            if (statePtr != 0L) {
                PqAuraNative.freeState(statePtr)
            }
        }
    }

    private fun showNotification(title: String, body: String, data: Map<String, String>) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Oasis Notifications",
                NotificationManager.IMPORTANCE_HIGH
            )
            notificationManager.createNotificationChannel(channel)
        }

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("notification_payload", jsonEncode(data))
        }

        val pendingIntent = PendingIntent.getActivity(
            this, System.currentTimeMillis().toInt(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info) 
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)

        notificationManager.notify(System.currentTimeMillis().toInt(), notificationBuilder.build())
    }

    private fun jsonEncode(data: Map<String, String>): String {
        val entries = data.entries.joinToString(",") { (k, v) -> "\"$k\":\"$v\"" }
        return "{$entries}"
    }
}
