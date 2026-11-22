import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// ── Automatic Version Code Auto-Increment ────────────────────────────
val versionProps = Properties()
val versionPropsFile = rootProject.file("version.properties")
if (!versionPropsFile.exists()) {
    versionProps["versionCode"] = "2010"
    versionProps.store(versionPropsFile.writer(), "Initial version code")
} else {
    versionProps.load(FileInputStream(versionPropsFile))
}

val isReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("bundleRelease", ignoreCase = true) || it.contains("assembleRelease", ignoreCase = true)
}

val storedCode = (versionProps["versionCode"] as String? ?: "2010").toInt()
val autoVersionCode: Int = if (isReleaseBuild) {
    if (!rootProject.extra.has("autoVersionCodeIncremented")) {
        val nextCode = maxOf(storedCode + 1, flutter.versionCode + 1)
        versionProps["versionCode"] = nextCode.toString()
        versionProps.store(versionPropsFile.writer(), "Auto-incremented release version")

        // Keep pubspec.yaml in sync
        val pubspecFile = rootProject.file("../pubspec.yaml")
        if (pubspecFile.exists()) {
            val content = pubspecFile.readText()
            val updated = content.replace(Regex("version:\\s*(\\d+\\.\\d+\\.\\d+)\\+\\d+")) { m ->
                "version: ${m.groupValues[1]}+$nextCode"
            }
            pubspecFile.writeText(updated)
        }
        rootProject.extra.set("autoVersionCodeIncremented", nextCode)
        println("🚀 [Auto-Version] Automatically incremented versionCode: $storedCode -> $nextCode")
        nextCode
    } else {
        rootProject.extra.get("autoVersionCodeIncremented") as Int
    }
} else {
    maxOf(storedCode, flutter.versionCode)
}

android {
    namespace = "com.telsoworld.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Production Application ID for Google Play Store
        applicationId = "com.telsoworld.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = autoVersionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

flutter {
    source = "../.."
}
