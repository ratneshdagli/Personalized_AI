plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

import org.gradle.api.JavaVersion

android {
    namespace = "com.example.flutter_application_1" // <-- add this

    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.flutter_application_1"
        minSdk = flutter.minSdkVersion
        targetSdk = 36

        // Safe fallback for flutterVersionCode/flutterVersionName properties
        versionCode = (project.findProperty("flutterVersionCode") as? String)?.toIntOrNull() ?: 1
        versionName = project.findProperty("flutterVersionName") as? String ?: "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    // If you have packagingOptions or flavor configs, keep them here
}

dependencies {
    // Required for Java 8+ library desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
}

// Flutter plugin configuration (keep as-is)
flutter {
    source = "../.."
}
