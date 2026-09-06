package com.oasis.app

import android.content.Intent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ComponentName
import android.content.pm.PackageManager

class MainActivity : FlutterFragmentActivity() {
    private val GEOFENCE_CHANNEL = "oasis/geofence"
    private val CALL_CHANNEL = "oasis/call"
    private val NOTIFICATION_CHANNEL = "oasis/notification_tap"
    private val STEALTH_CHANNEL = "oasis/stealth_mode"
    private val MEMORY_CHANNEL = "oasis/memory"
    private val geofenceManager by lazy { OasisGeofenceManager(this) }
    private val zeroTapRestoreManager by lazy { ZeroTapRestoreManager(this) }
    private var geofenceMethodChannel: MethodChannel? = null
    private var callMethodChannel: MethodChannel? = null
    private var notificationMethodChannel: MethodChannel? = null
    private var stealthMethodChannel: MethodChannel? = null
    private var memoryMethodChannel: MethodChannel? = null
    private var zeroTapMethodChannel: MethodChannel? = null
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

        try {
            val messenger = flutterEngine.dartExecutor
            geofenceMethodChannel = MethodChannel(messenger, GEOFENCE_CHANNEL)
            callMethodChannel = MethodChannel(messenger, CALL_CHANNEL)
            notificationMethodChannel = MethodChannel(messenger, NOTIFICATION_CHANNEL)
            stealthMethodChannel = MethodChannel(messenger, STEALTH_CHANNEL)
            memoryMethodChannel = MethodChannel(messenger, MEMORY_CHANNEL)
            zeroTapMethodChannel = MethodChannel(messenger, ZeroTapRestoreManager.CHANNEL_NAME)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to initialize method channels: $e")
        }

        zeroTapMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getRestoreKey" -> {
                    zeroTapRestoreManager.getRestoreKey { token, error ->
                        if (error != null) {
                            result.error("RESTORE_GET_ERROR", error, null)
                        } else {
                            result.success(token)
                        }
                    }
                }
                "saveRestoreKey" -> {
                    val token = call.argument<String>("token")
                    if (token.isNullOrEmpty()) {
                        result.error("INVALID_ARGS", "Token cannot be empty", null)
                    } else {
                        zeroTapRestoreManager.saveRestoreKey(token) { success, error ->
                            if (error != null) {
                                result.error("RESTORE_SAVE_ERROR", error, null)
                            } else {
                                result.success(success)
                            }
                        }
                    }
                }
                "clearRestoreKey" -> {
                    zeroTapRestoreManager.clearRestoreKey { success ->
                        result.success(success)
                    }
                }
                else -> result.notImplemented()
            }
        }

        stealthMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "setStealthMode" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    setStealthMode(enable)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

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

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        try {
            memoryMethodChannel?.invokeMethod("onTrimMemory", level)
            if (level >= android.content.ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN) {
                System.gc()
            }
        } catch (e: Exception) {
            android.util.Log.w("MainActivity", "Error handling onTrimMemory: $e")
        }
    }

    override fun onLowMemory() {
        super.onLowMemory()
        try {
            memoryMethodChannel?.invokeMethod("onTrimMemory", android.content.ComponentCallbacks2.TRIM_MEMORY_COMPLETE)
            System.gc()
        } catch (e: Exception) {
            android.util.Log.w("MainActivity", "Error handling onLowMemory: $e")
        }
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

    private fun setStealthMode(enable: Boolean) {
        val packageManager = packageManager
        val normalAlias = ComponentName(this, "com.oasis.app.MainActivityAliasNormal")
        val decoyAlias = ComponentName(this, "com.oasis.app.MainActivityAliasDecoy")

        if (enable) {
            packageManager.setComponentEnabledSetting(
                decoyAlias,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            packageManager.setComponentEnabledSetting(
                normalAlias,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            android.util.Log.d("MainActivity", "Decoy mode alias enabled, normal alias disabled")
        } else {
            packageManager.setComponentEnabledSetting(
                normalAlias,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            packageManager.setComponentEnabledSetting(
                decoyAlias,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            android.util.Log.d("MainActivity", "Normal mode alias enabled, decoy alias disabled")
        }
    }
}
