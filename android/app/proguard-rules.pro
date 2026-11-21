# Flutter Core & Plugins
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.**
-dontwarn androidx.**
-dontwarn com.arthenica.ffmpegkit.**

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Pigeon & Image Picker
-keep class dev.flutter.pigeon.** { *; }
-keep interface dev.flutter.pigeon.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep interface io.flutter.plugins.imagepicker.** { *; }
-keepclasseswithmembers class io.flutter.plugins.imagepicker.** { *; }
-keepclassmembers class io.flutter.plugins.imagepicker.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-dontwarn dev.flutter.pigeon.**
-dontwarn io.flutter.plugins.imagepicker.**

# FFmpeg Kit Rules
-keep class com.arthenica.ffmpegkit.** { *; }

# Video Player / ExoPlayer / Media3
-keep class io.flutter.plugins.videoplayer.** { *; }
-keep class androidx.media3.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-keep class xyz.justsoft.video_thumbnail.** { *; }
-dontwarn androidx.media3.**
-dontwarn com.google.android.exoplayer2.**
-keep class androidx.media3.extractor.** { *; }
-keep class androidx.media3.decoder.** { *; }
-keep class androidx.media3.exoplayer.** { *; }
-keep class androidx.media3.exoplayer.audio.** { *; }
-keep class androidx.media3.exoplayer.video.** { *; }
-keep class com.google.android.exoplayer2.audio.** { *; }
-keep class com.google.android.exoplayer2.video.** { *; }

# Shared Preferences & Other Plugins
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }

# Models & JSON serialization
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Stack trace preservation & Obfuscation
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
