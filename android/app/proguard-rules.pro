# ProGuard/R8 rules for Obsession Tracker
# These rules ensure proper obfuscation while maintaining app functionality

#-------------------------------------------
# Flutter-specific rules
#-------------------------------------------

# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Play Core deferred components (referenced by Flutter but not used)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

#-------------------------------------------
# SQLCipher (encrypted database)
#-------------------------------------------
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

#-------------------------------------------
# Mapbox
#-------------------------------------------
-keep class com.mapbox.** { *; }
-dontwarn com.mapbox.**

#-------------------------------------------
# Location services
#-------------------------------------------
-keep class com.google.android.gms.location.** { *; }
-keep class com.google.android.gms.common.** { *; }

#-------------------------------------------
# Biometric authentication
#-------------------------------------------
-keep class androidx.biometric.** { *; }

#-------------------------------------------
# Camera and image processing
#-------------------------------------------
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

#-------------------------------------------
# Secure storage
#-------------------------------------------
-keep class androidx.security.crypto.** { *; }

#-------------------------------------------
# JSON serialization (for GraphQL responses)
#-------------------------------------------
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep model classes that are serialized (adjust package as needed)
-keep class com.obsessiontracker.app.models.** { *; }

#-------------------------------------------
# Kotlin-specific rules
#-------------------------------------------
-dontwarn kotlin.**
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

#-------------------------------------------
# Coroutines
#-------------------------------------------
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.**

#-------------------------------------------
# Prevent obfuscation of native methods
#-------------------------------------------
-keepclasseswithmembernames class * {
    native <methods>;
}

#-------------------------------------------
# Remove logging in release builds (security)
#-------------------------------------------
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
}

#-------------------------------------------
# Google Play Billing (required for in-app purchases)
#-------------------------------------------
-keep class com.android.vending.billing.** { *; }
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# Keep org.json (Android framework, but can be stripped if added as dependency)
-keep class org.json.* { *; }

#-------------------------------------------
# Kotlinx Serialization
#-------------------------------------------

# Keep `Companion` object fields of serializable classes.
-if @kotlinx.serialization.Serializable class **
-keepclassmembers class <1> {
    static <1>$Companion Companion;
}

# Keep `serializer()` on companion objects (both default and named) of serializable classes.
-if @kotlinx.serialization.Serializable class ** {
    static **$* *;
}
-keepclassmembers class <2>$<3> {
    kotlinx.serialization.KSerializer serializer(...);
}

# Keep `INSTANCE.serializer()` of serializable objects.
-if @kotlinx.serialization.Serializable class ** {
    public static ** INSTANCE;
}
-keepclassmembers class <1> {
    public static <1> INSTANCE;
    kotlinx.serialization.KSerializer serializer(...);
}

# @Serializable and @Polymorphic are used at runtime for polymorphic serialization.
-keepattributes RuntimeVisibleAnnotations,AnnotationDefault

# Fix for R8 issues when target Android is 14 but compile version is lower
-keep class kotlinx.serialization.internal.ClassValueParametrizedCache$initClassValue$1 { ** computeValue(java.lang.Class); }
-keep class kotlinx.serialization.internal.ClassValueCache$initClassValue$1 { ** computeValue(java.lang.Class); }

#-------------------------------------------
# Facebook SDK (referenced by other SDKs)
#-------------------------------------------
-dontwarn com.facebook.annotations.DoNotOptimize
-dontwarn com.facebook.common.preconditions.Preconditions
-dontwarn com.facebook.infer.annotation.Nullsafe
-dontwarn com.facebook.infer.annotation.NullsafeStrict
-dontwarn com.facebook.secure.sanitizer.intf.DataSanitizer

#-------------------------------------------
# URL Launcher plugin
#-------------------------------------------
-keep class io.flutter.plugins.urllauncher.** { *; }
-dontwarn io.flutter.plugins.urllauncher.**

#-------------------------------------------
# Package Info Plus plugin
#-------------------------------------------
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }
-dontwarn dev.fluttercommunity.plus.packageinfo.**

#-------------------------------------------
# In App Review plugin
#-------------------------------------------
-keep class dev.britannio.in_app_review.** { *; }
-dontwarn dev.britannio.in_app_review.**

# Google Play Core (required by In App Review)
-keep class com.google.android.play.core.review.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.**

#-------------------------------------------
# Connectivity Plus plugin
#-------------------------------------------
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-dontwarn dev.fluttercommunity.plus.connectivity.**

#-------------------------------------------
# Shared Preferences plugin
#-------------------------------------------
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**

#-------------------------------------------
# File Picker plugin
#-------------------------------------------
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-dontwarn com.mr.flutter.plugin.filepicker.**

#-------------------------------------------
# Flutter Local Notifications
#-------------------------------------------
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

#-------------------------------------------
# Geolocator plugin
#-------------------------------------------
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

#-------------------------------------------
# Permission Handler plugin
#-------------------------------------------
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

#-------------------------------------------
# Photo Manager plugin
#-------------------------------------------
-keep class com.fluttercandies.photo_manager.** { *; }
-dontwarn com.fluttercandies.photo_manager.**

#-------------------------------------------
# Image Compress plugin
#-------------------------------------------
-keep class com.fluttercandies.flutter_image_compress.** { *; }
-dontwarn com.fluttercandies.flutter_image_compress.**

#-------------------------------------------
# Audio plugins
#-------------------------------------------
-keep class com.ryanheise.audio_session.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.simform.audio_waveforms.** { *; }
-keep class com.llfbandit.record.** { *; }
-dontwarn com.ryanheise.**
-dontwarn com.simform.**
-dontwarn com.llfbandit.**

#-------------------------------------------
# Speech to Text plugin
#-------------------------------------------
-keep class com.csdcorp.speech_to_text.** { *; }
-dontwarn com.csdcorp.speech_to_text.**

#-------------------------------------------
# Flutter TTS plugin
#-------------------------------------------
-keep class com.tundralabs.fluttertts.** { *; }
-dontwarn com.tundralabs.fluttertts.**

#-------------------------------------------
# Local Auth plugin
#-------------------------------------------
-keep class io.flutter.plugins.localauth.** { *; }
-dontwarn io.flutter.plugins.localauth.**

#-------------------------------------------
# Path Provider plugin
#-------------------------------------------
-keep class io.flutter.plugins.pathprovider.** { *; }
-dontwarn io.flutter.plugins.pathprovider.**

#-------------------------------------------
# Device Info Plus plugin
#-------------------------------------------
-keep class dev.fluttercommunity.plus.device_info.** { *; }
-dontwarn dev.fluttercommunity.plus.device_info.**

#-------------------------------------------
# Battery Plus plugin
#-------------------------------------------
-keep class dev.fluttercommunity.plus.battery.** { *; }
-dontwarn dev.fluttercommunity.plus.battery.**

#-------------------------------------------
# Sensors Plus plugin
#-------------------------------------------
-keep class dev.fluttercommunity.plus.sensors.** { *; }
-dontwarn dev.fluttercommunity.plus.sensors.**

#-------------------------------------------
# Share Plus plugin
#-------------------------------------------
-keep class dev.fluttercommunity.plus.share.** { *; }
-dontwarn dev.fluttercommunity.plus.share.**

#-------------------------------------------
# Workmanager plugin
#-------------------------------------------
-keep class dev.fluttercommunity.workmanager.** { *; }
-keep class be.tramckrijte.workmanager.** { *; }
-dontwarn dev.fluttercommunity.workmanager.**
-dontwarn be.tramckrijte.workmanager.**

#-------------------------------------------
# Compass plugin
#-------------------------------------------
-keep class com.hemanthraj.fluttercompass.** { *; }
-dontwarn com.hemanthraj.fluttercompass.**

#-------------------------------------------
# PDF plugin
#-------------------------------------------
-keep class io.scer.pdfx.** { *; }
-dontwarn io.scer.pdfx.**

#-------------------------------------------
# Accessibility Service plugin
#-------------------------------------------
-keep class slayer.accessibility.service.flutter_accessibility_service.** { *; }
-dontwarn slayer.accessibility.service.**

#-------------------------------------------
# Optimization settings
#-------------------------------------------
-optimizationpasses 5
-allowaccessmodification
-repackageclasses ''

#-------------------------------------------
# Keep source file names for crash reports
# (remove this line for maximum obfuscation)
#-------------------------------------------
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
