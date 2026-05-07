package com.oasis.app

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * A dedicated, lightweight FlutterActivity for handling incoming calls 
 * securely over the lock screen.
 */
class OasisCallActivity : FlutterActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Turn on screen and show over lockscreen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Pass call arguments to Flutter
        val callerName = intent.getStringExtra("callerName") ?: "Unknown"
        val callId = intent.getStringExtra("callId") ?: ""
        val callerAvatar = intent.getStringExtra("callerAvatar") ?: ""
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "oasis/call_intent").setMethodCallHandler { call, result ->
            when (call.method) {
                "getIncomingCallData" -> {
                    result.success(mapOf(
                        "callerName" to callerName,
                        "callId" to callId,
                        "callerAvatar" to callerAvatar
                    ))
                }
                "acceptCall" -> {
                    val mainIntent = Intent(this, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        putExtra("accept_call", true)
                        putExtra("callId", call.argument<String>("callId"))
                    }
                    startActivity(mainIntent)
                    finish()
                    result.success(null)
                }
                "finishCallActivity" -> {
                    finish()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // Direct Flutter to use a specific entrypoint for faster boot
    override fun getDartEntrypointFunctionName(): String {
        return "callingMain"
    }
}
