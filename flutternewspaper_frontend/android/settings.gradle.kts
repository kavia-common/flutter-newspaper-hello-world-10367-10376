pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false

    // Align Kotlin Gradle plugin with dependencies that may be built with newer Kotlin metadata
    // (e.g., flutter_tts transitively pulling Kotlin stdlib 2.x). This prevents metadata
    // "binary version ... is 2.2.0, expected 1.8.0" compilation failures.
    id("org.jetbrains.kotlin.android") version "2.2.0" apply false
}

include(":app")
