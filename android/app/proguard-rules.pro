# Flutter ProGuard Rules
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.**
-dontwarn androidx.**
-dontwarn com.arthenica.ffmpegkit.**

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# FFmpeg Kit Rules
-keep class com.arthenica.ffmpegkit.** { *; }

# Video Player / ExoPlayer
-keep class androidx.media3.** { *; }
-keep class xyz.justsoft.video_thumbnail.** { *; }

# Models & JSON serialization
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
