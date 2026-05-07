package com.oasis.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofenceStatusCodes
import com.google.android.gms.location.GeofencingEvent

import androidx.localbroadcastmanager.content.LocalBroadcastManager

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.os.Build
import androidx.core.app.NotificationCompat

class OasisGeofenceReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "OasisGeofenceReceiver"
        const val ACTION_GEOFENCE_EVENT = "com.oasis.app.ACTION_GEOFENCE_EVENT"
        const val EXTRA_GEOFENCE_ID = "geofence_id"
        const val EXTRA_TRANSITION_TYPE = "transition_type"
        private const val CHANNEL_ID = "geofence_channel"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_GEOFENCE_EVENT) return

        val geofencingEvent = GeofencingEvent.fromIntent(intent)
        if (geofencingEvent == null) {
            Log.e(TAG, "GeofencingEvent is null")
            return
        }

        if (geofencingEvent.hasError()) {
            val errorMessage = GeofenceStatusCodes.getStatusCodeString(geofencingEvent.errorCode)
            Log.e(TAG, "Geofencing error: $errorMessage")
            return
        }

        val geofenceTransition = geofencingEvent.geofenceTransition

        if (geofenceTransition == Geofence.GEOFENCE_TRANSITION_ENTER ||
            geofenceTransition == Geofence.GEOFENCE_TRANSITION_EXIT) {

            val triggeringGeofences = geofencingEvent.triggeringGeofences
            if (triggeringGeofences == null) {
                Log.e(TAG, "Triggering geofences is null")
                return
            }

            for (geofence in triggeringGeofences) {
                val geofenceId = geofence.requestId
                val transitionType = if (geofenceTransition == Geofence.GEOFENCE_TRANSITION_ENTER) "ENTER" else "EXIT"
                Log.d(TAG, "Geofence transition: $geofenceId ($transitionType)")

                if (geofenceId == "home_geofence" && transitionType == "ENTER") {
                    showHomeArrivalNotification(context)
                }

                // Send local broadcast to MainActivity (if running)
                val localIntent = Intent(ACTION_GEOFENCE_EVENT)
                localIntent.putExtra(EXTRA_GEOFENCE_ID, geofenceId)
                localIntent.putExtra(EXTRA_TRANSITION_TYPE, transitionType)
                LocalBroadcastManager.getInstance(context).sendBroadcast(localIntent)
            }
        } else {
            Log.e(TAG, "Invalid transition type: $geofenceTransition")
        }
    }

    private fun showHomeArrivalNotification(context: Context) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Oasis Home Alerts",
                NotificationManager.IMPORTANCE_HIGH
            )
            notificationManager.createNotificationChannel(channel)
        }

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationBuilder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Welcome Home! 🏠")
            .setContentText("Tap to check in and notify your partner.")
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)

        notificationManager.notify(2001, notificationBuilder.build())
    }
}
