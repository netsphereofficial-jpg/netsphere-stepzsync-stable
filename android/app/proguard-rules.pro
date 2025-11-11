## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

## Play Core (deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

## Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

## Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

## Health & Pedometer
-keep class com.google.android.gms.fitness.** { *; }

## Camera
-keep class io.flutter.plugins.camera.** { *; }

## Gson (if used)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

## Keep model classes (customize based on your package)
-keep class com.health.stepzsync.stepzsync.models.** { *; }

## Sentry
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

## Health Connect / androidx.health
-keep public class androidx.health.** {
    public protected private *;
}
-dontwarn androidx.health.**

# Critical: Keep HealthDataSdkService (required for Health Connect permission callbacks)
-keep class androidx.health.platform.client.impl.sdkservice.HealthDataSdkService { *; }

# Keep Health Connect service interfaces
-keep interface androidx.health.platform.client.** { *; }

# Keep lifecycle classes (required for permission callbacks)
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.lifecycle.**

# Keep activity result contracts (used by health package for permissions)
-keep class androidx.activity.result.** { *; }
-dontwarn androidx.activity.result.**

## General Android
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
