# ─── Java XML (referenced by Apache Tika via R8) ───────────────────────
-dontwarn javax.xml.stream.XMLStreamException

# ─── Google Play Core (deferred components not used) ──────────────────
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# ─── Agora SDK ──────────────────────────────────────────────────────────
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# ─── WebRTC (used by Agora internally) ─────────────────────────────────
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# ─── Flutter plugins ────────────────────────────────────────────────────
-keep class io.flutter.plugins.** { *; }


# ─── RevenueCat Purchases SDK ──────────────────────────────────────────
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# ─── Google Play Billing ───────────────────────────────────────────────
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# ─── Firebase (safety net, usually bundled via consumer rules already) ─
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ─── OkHttp / Okio (used by Dio for HTTP calls) ────────────────────────
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okio.**
-keep class okio.** { *; }
-keep interface okio.** { *; }

# ─── Flutter core engine ────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-dontwarn io.flutter.**

# ─── Google Sign-In / GMS ───────────────────────────────────────────────
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ─── Annotations / JS interface ────────────────────────────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
