plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")

    // PLUGIN GOOGLE SERVICES (FIREBASE)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.delivery_app"
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
        applicationId = "com.example.delivery_app"
        multiDexEnabled = true
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // FIREBASE BOM
    implementation(platform("com.google.firebase:firebase-bom:34.8.0"))

    // FIREBASE ANALYTICS (OBLIGATORIO PARA VALIDAR CONFIG)
    implementation("com.google.firebase:firebase-analytics")
}

flutter {
    source = "../.."
}
