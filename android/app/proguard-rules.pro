# Flutter wrapper rules - keep Flutter engine classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.engine.** { *; }

# Freezed - Keep generated freezed classes
-keep class **.freezed.** { *; }
-keepclassmembers class ** {
    @com.google.gson.annotations.SerializedName <fields>;
}

# JSON Serializable - Keep generated .g.dart classes  
-keep class **.g.** { *; }
-keepclassmembers class ** {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Google Guava - Required for shared_preferences and other plugins
-keep class com.google.common.reflect.TypeToken { *; }
-keep class * extends com.google.common.reflect.TypeToken { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken { *; }

# Supabase / PostgREST / GoTrue / Serialization
-keep class io.supabase.** { *; }
-keep class io.github.jan.supabase.** { *; }
-keep class com.oasis.app.models.** { *; }
-keepclassmembers class com.oasis.app.models.** { *; }
-keepattributes Signature,Annotation,EnclosingMethod,InnerClasses,GenericSignature
-dontwarn moxy.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn io.github.jan.supabase.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Sentry
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# Keep method channels for plugins
-keepclassmembers class * {
    @io.flutter.plugin.common.MethodChannelHandler <methods>;
}

# Sentry / Compose
-dontwarn androidx.compose.**
-dontwarn androidx.window.**

# Inferred missing rules from build cache
-dontwarn androidx.compose.runtime.internal.StabilityInferred
-dontwarn androidx.compose.ui.Modifier
-dontwarn androidx.compose.ui.geometry.Offset
-dontwarn androidx.compose.ui.geometry.OffsetKt
-dontwarn androidx.compose.ui.geometry.Rect
-dontwarn androidx.compose.ui.graphics.Color$Companion
-dontwarn androidx.compose.ui.graphics.Color
-dontwarn androidx.compose.ui.graphics.ColorKt
-dontwarn androidx.compose.ui.layout.LayoutCoordinates
-dontwarn androidx.compose.ui.layout.LayoutCoordinatesKt
-dontwarn androidx.compose.ui.layout.ModifierInfo
-dontwarn androidx.compose.ui.node.LayoutNode
-dontwarn androidx.compose.ui.node.NodeCoordinator
-dontwarn androidx.compose.ui.node.Owner
-dontwarn androidx.compose.ui.semantics.AccessibilityAction
-dontwarn androidx.compose.ui.semantics.SemanticsActions
-dontwarn androidx.compose.ui.semantics.SemanticsConfiguration
-dontwarn androidx.compose.ui.semantics.SemanticsConfigurationKt
-dontwarn androidx.compose.ui.semantics.SemanticsModifierKt
-dontwarn androidx.compose.ui.semantics.SemanticsProperties
-dontwarn androidx.compose.ui.semantics.SemanticsPropertyKey
-dontwarn androidx.compose.ui.semantics.SemanticsPropertyReceiver
-dontwarn androidx.compose.ui.text.TextLayoutInput
-dontwarn androidx.compose.ui.text.TextLayoutResult
-dontwarn androidx.compose.ui.text.TextStyle
-dontwarn androidx.compose.ui.unit.IntSize
-dontwarn androidx.compose.ui.unit.TextUnit$Companion
-dontwarn androidx.compose.ui.unit.TextUnit
-dontwarn androidx.window.extensions.WindowExtensions
-dontwarn androidx.window.extensions.WindowExtensionsProvider
-dontwarn androidx.window.extensions.area.ExtensionWindowAreaPresentation
-dontwarn androidx.window.extensions.layout.DisplayFeature
-dontwarn androidx.window.extensions.layout.FoldingFeature
-dontwarn androidx.window.extensions.layout.WindowLayoutComponent
-dontwarn androidx.window.extensions.layout.WindowLayoutInfo
-dontwarn androidx.window.sidecar.SidecarDeviceState
-dontwarn androidx.window.sidecar.SidecarDisplayFeature
-dontwarn androidx.window.sidecar.SidecarInterface$SidecarCallback
-dontwarn androidx.window.sidecar.SidecarInterface
-dontwarn androidx.window.sidecar.SidecarProvider
-dontwarn androidx.window.sidecar.SidecarWindowLayoutInfo

# Play Services Core / Splitcompat (for deferred components)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# JNI / Native
-keep class com.tekartik.sqflite.** { *; }

# okhttp3
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okhttp3.internal.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.internal.**
-dontwarn okio.**

# uCrop
-dontwarn com.yalantis.ucrop.**
-dontwarn com.yalantis.ucrop.task.**
-dontwarn com.yalantis.ucrop.model.**
-dontwarn com.yalantis.ucrop.view.**
-dontwarn com.yalantis.ucrop.util.**
-keep class com.yalantis.ucrop.** { *; }
-keep interface com.yalantis.ucrop.** { *; }
-keep class com.yalantis.ucrop.task.** { *; }
-keep class com.yalantis.ucrop.model.** { *; }
-keep class com.yalantis.ucrop.view.** { *; }
-keep class com.yalantis.ucrop.util.** { *; }

# WebRTC Proguard Rules
-keep class org.webrtc.** { *; }
-keep class com.cloudwebrtc.** { *; }
-dontwarn org.webrtc.**
-dontwarn com.cloudwebrtc.**

# Razorpay Proguard Rules
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/*

# Required for the Javascript bridge to work in the Webview
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep the payment listeners
-keepclasseswithmembers class * {
    public void onPayment*(...);
}

# Keep LocalBroadcastManager to prevent NoClassDefFoundError
-keep class androidx.localbroadcastmanager.content.LocalBroadcastManager { *; }
-keep class androidx.localbroadcastmanager.content.LocalBroadcastManager$** { *; }

# ============================================================
# LiveKit (livekit_client 2.7.0) — WebRTC-based calling
# R8 strips these aggressively without these rules, causing
# UnsatisfiedLinkError / ClassNotFoundException on startup.
# ============================================================
-keep class livekit.** { *; }
-keep class io.livekit.** { *; }
-keep class livekit.org.webrtc.** { *; }
-dontwarn livekit.**
-dontwarn io.livekit.**

# Keep all JNI native method entry points (WebRTC, LiveKit, FFI)
-keepclasseswithmembernames class * {
    native <methods>;
}

# ============================================================
# flutter_background (de.julianassmann) — foreground service
# for keeping calls alive in the background on Android.
# ============================================================
-keep class de.julianassmann.flutter_background.** { *; }
-keepclassmembers class de.julianassmann.flutter_background.** { *; }
-dontwarn de.julianassmann.flutter_background.**

# ============================================================
# flutter_callkit_incoming (^3.0.0) — native incoming call UI
# ============================================================
-keep class com.hiennv.flutter_callkit_incoming.** { *; }
-keepclassmembers class com.hiennv.flutter_callkit_incoming.** { *; }
-dontwarn com.hiennv.flutter_callkit_incoming.**

# ============================================================
# audioplayers (^6.5.1) — ringtone / audio playback
# ============================================================
-keep class xyz.luan.audioplayers.** { *; }
-keepclassmembers class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# ============================================================
# permission_handler — microphone / camera permissions
# ============================================================
-keep class com.baseflow.permissionhandler.** { *; }
-keepclassmembers class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# ============================================================
# flutter_secure_storage / androidx.security
# ============================================================
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# ============================================================
# Kotlin reflection & coroutines (used by many plugins)
# ============================================================
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# ============================================================
# Firebase Messaging (FCM) — background handler
# @pragma('vm:entry-point') alone is not enough with R8
# ============================================================
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# ============================================================
# Gson / Serialization — used by Supabase & plugins
# ============================================================
-keep class com.google.gson.** { *; }
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ============================================================
# Post-Quantum Aura Cryptography Native Bindings (JNI / FFI)
# ============================================================
-keep class com.oasis.app.PqAuraNative { *; }
-keepclassmembers class com.oasis.app.PqAuraNative { *; }

