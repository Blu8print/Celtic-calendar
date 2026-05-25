import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}

android {
    namespace = "nl.blu8print.rootscalendar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "nl.blu8print.rootscalendar"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Required by flutter_appauth so the OS routes the OAuth redirect back to this app.
        manifestPlaceholders["appAuthRedirectScheme"] = "com.googleusercontent.apps.994680507449-c3pkq1is9vpo7ioohnu5r6j56b4hi3ne"
    }

    // Release signing reads from android/key.properties (never committed to git).
    // Create that file with:
    //   storePassword=<your password>
    //   keyPassword=<your password>
    //   keyAlias=roots-calendar
    //   storeFile=../../roots-calendar-release.jks
    signingConfigs {
        create("release") {
            if (keyPropertiesFile.exists()) {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            val releaseConfig = signingConfigs.getByName("release")
            // Use release keystore when key.properties is present; fall back to
            // debug keys only for local builds without the properties file.
            signingConfig = if (keyPropertiesFile.exists()) releaseConfig
                            else signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

configurations.all {
    resolutionStrategy {
        // home_widget pulls in glance-appwidget alpha which requires compileSdk 37 + AGP 9.1.
        // Force to the latest stable release that works with compileSdk 36 / AGP 8.x.
        force("androidx.glance:glance:1.1.1")
        force("androidx.glance:glance-appwidget:1.1.1")
        force("androidx.glance:glance-material3:1.1.1")
        force("androidx.glance:glance-material:1.1.1")
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
