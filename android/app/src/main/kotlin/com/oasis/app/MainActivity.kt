package com.oasis.app

import android.content.Intent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val GEOFENCE_CHANNEL = "oasis/geofence"
    private val CALL_CHANNEL = "oasis/call"
    private val NOTIFICATION_CHANNEL = "oasis/notification_tap"
    private val geofenceManager by lazy { OasisGeofenceManager(this) }
    private var geofenceMethodChannel: MethodChannel? = null
    private var callMethodChannel: MethodChannel? = null
    private var notificationMethodChannel: MethodChannel? = null
    private var pendingCallId: String? = null
    private var pendingNotificationPayload: String? = null

    private val geofenceReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val id = intent.getStringExtra(OasisGeofenceReceiver.EXTRA_GEOFENCE_ID)
            val transition = intent.getStringExtra(OasisGeofenceReceiver.EXTRA_TRANSITION_TYPE)

            if (transition == "ENTER") {
                geofenceMethodChannel?.invokeMethod("onEnterRegion", mapOf("id" to id))
            } else if (transition == "EXIT") {
                geofenceMethodChannel?.invokeMethod("onExitRegion", mapOf("id" to id))
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        geofenceMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GEOFENCE_CHANNEL)
        callMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL)
        notificationMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)

        // Handle retrieval of data received during cold start
        notificationMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingNotificationPayload" -> {
                    result.success(pendingNotificationPayload)
                    pendingNotificationPayload = null
                }
                else -> result.notImplemented()
            }
        }

        callMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingCall" -> {
                    result.success(pendingCallId)
                    pendingCallId = null // Clear after retrieval
                }
                else -> result.notImplemented()
            }
        }

        handleIntent(intent)
        // ... (rest of geofenceMethodChannel handler)
        geofenceMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "addGeofence" -> {
                    val id = call.argument<String>("id")!!
                    val lat = call.argument<Double>("lat")!!
                    val lon = call.argument<Double>("lon")!!
                    val radius = call.argument<Double>("radius")!!.toFloat()
                    geofenceManager.addGeofence(id, lat, lon, radius)
                    result.success(null)
                }
                "removeGeofence" -> {
                    val id = call.argument<String>("id")!!
                    geofenceManager.removeGeofence(id)
                    result.success(null)
                }
                "removeAllGeofences" -> {
                    geofenceManager.removeAllGeofences()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        LocalBroadcastManager.getInstance(this).registerReceiver(
            geofenceReceiver,
            IntentFilter(OasisGeofenceReceiver.ACTION_GEOFENCE_EVENT)
        )
    }

    override fun onDestroy() {
        LocalBroadcastManager.getInstance(this).unregisterReceiver(geofenceReceiver)
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Required for notification taps to be delivered to Flutter 
        // when the app is already running in the background.
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.getBooleanExtra("accept_call", false)) {
            val callId = intent.getStringExtra("callId")
            pendingCallId = callId
            callMethodChannel?.invokeMethod("onCallAccepted", mapOf("callId" to callId))
        }
        
        val payload = intent.getStringExtra("notification_payload")
        if (payload != null) {
            pendingNotificationPayload = payload
            notificationMethodChannel?.invokeMethod("onNotificationTap", payload)
        }
    }
}
