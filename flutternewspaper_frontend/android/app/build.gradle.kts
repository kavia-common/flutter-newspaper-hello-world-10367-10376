plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")

    // Firebase config (google-services.json) support.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.flutternewspaper_frontend"

    // Explicitly compile with the latest SDK (backward compatible) to resolve SDK 36 requirement.
    compileSdk = 36

    // Plugins require this NDK version; using the highest required version is backward compatible.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    /**
     * Ensure we always generate a *single* universal (fat) APK for release builds.
     *
     * Some setups (or CI defaults) can enable ABI splits which produce multiple APKs
     * (e.g. app-armeabi-v7a-release.apk, app-arm64-v8a-release.apk). Those are not
     * installable as a single artifact for end users.
     *
     * With splits disabled, Gradle/Flutter emits one APK containing arm64 + armeabi-v7a
     * native libraries, which installs on typical Android 13 devices.
     */
    splits {
        abi {
            isEnable = false
            reset()
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.flutternewspaper_frontend"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        //
        // flutter_tts (Android) requires minSdkVersion 24+, otherwise the Android manifest merger fails.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
