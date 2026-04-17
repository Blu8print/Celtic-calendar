plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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
        jvmTarget = JavaVersion.VERSION_17.toString()
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

    // Release signing reads from environment variables so the keystore never
    // has to be committed to version control.
    //
    // Required env vars (set in CI secrets / local shell before building):
    //   KEYSTORE_PATH     — absolute path to the .jks / .keystore file
    //   KEYSTORE_PASSWORD — store password
    //   KEY_ALIAS         — key alias inside the keystore
    //   KEY_PASSWORD      — key password
    //
    // To generate a keystore locally (one-time):
    //   keytool -genkey -v -keystore roots-calendar.jks \
    //           -keyalg RSA -keysize 2048 -validity 10000 \
    //           -alias roots-calendar
    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("KEYSTORE_PATH")
            if (keystorePath != null) {
                storeFile = file(keystorePath)
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            val releaseConfig = signingConfigs.getByName("release")
            // Use the release keystore when env vars are present; fall back to
            // debug keys only for local development builds without env vars set.
            signingConfig = if (releaseConfig.storeFile != null) releaseConfig
                            else signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
