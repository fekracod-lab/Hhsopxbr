# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Background Service
-keep class id.flutter.flutter_background_service.** { *; }

# Media Kit
-keep class com.alexmercerind.media_kit_video.** { *; }
-keep class com.alexmercerind.media_kit.** { *; }
-keep class io.github.media_kit.** { *; }

# FFmpeg Kit
-keep class com.arthenica.ffmpegkit.** { *; }

# Firebase (General safety for release minification)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.play.core.**

# Google Maps
-keep class com.google.android.gms.maps.** { *; }

# Dalal Alqaim App
-keep class com.dalal.alqaimapp.** { *; }
