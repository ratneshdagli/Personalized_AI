plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Add this for Java 8 features
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    
    // Add this for Kotlin
    kotlinOptions {
        jvmTarget = "1.8"
    }
    namespace = "com.example.figma"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    
    // Enable prefab for native dependencies
    buildFeatures {
        prefab = true
    }
    
    // Configure packaging options
    packagingOptions {
        jniLibs {
            useLegacyPackaging = true
            // Add this to exclude unnecessary native libraries
            excludes += listOf(
                "**/libmediapipe_jni.so",
                "**/libmediapipe_framework.so",
                "**/libmediapipe_util.so"
            )
        }
        resources.excludes.addAll(
            listOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/license.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/notice.txt",
                "META-INF/ASL2.0",
                "**/lib/**/libc++_shared.so",
                "**/lib/**/libmediapipe_jni.so",
                "**/lib/**/libmediapipe_android_deps.so",
                "**/lib/**/libmediapipe_audio_utils.so",
                "**/lib/**/libmediapipe_framework.so",
                "**/lib/**/libmediapipe_util.so",
                "**/lib/**/libmediapipe_vision_utils.so"
            )
        )
    }

    // Packaging options are already defined above

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.figma"
        minSdk = 24 // Android 7.0 (Nougat)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Configure ABI filters for native libraries
        ndk {
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86_64"))
        }
        
        // Enable multidex support
        multiDexEnabled = true
        
        // OAuth redirect scheme for Hugging Face authentication
        manifestPlaceholders["appAuthRedirectScheme"] = "com.example.figma"
        
        // Add these intent filters for OAuth
        manifestPlaceholders["hostName"] = "auth"
        manifestPlaceholders["scheme"] = "com.example.figma"
        manifestPlaceholders["pathPrefix"] = "/"
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

dependencies {
    implementation(kotlin("stdlib-jdk7"))
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("com.google.mediapipe:tasks-genai:0.10.27")
    
    // Add these if not already present
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.9.0")
}
