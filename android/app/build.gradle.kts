plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// ✅ Redirect build output to Flutter's expected location
buildDir = File(rootDir, "../build/app")

android {
    namespace = "com.oasis.app"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            freeCompilerArgs.add("-Xjvm-default=all")
        }
    }

    defaultConfig {
        applicationId = "com.oasis.app" // Production: com.oasis.app
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Used for local release builds
            // CI uses r0adkll/sign-android-release action instead
            val envStoreFile = System.getenv("RELEASE_STORE_FILE")
            val envStorePass = System.getenv("KEYSTORE_PASSWORD")
            val envKeyAlias = System.getenv("KEY_ALIAS")
            val envKeyPass = System.getenv("KEY_PASSWORD")

            if (!envStoreFile.isNullOrEmpty()) {
                storeFile = file(envStoreFile)
                storePassword = envStorePass
                keyAlias = envKeyAlias
                keyPassword = envKeyPass
                storeType = "PKCS12"
            }
        }
    }

    buildTypes {
        getByName("debug") {
            // Must match a package name in google-services.json
            applicationIdSuffix = "" 
        }
        getByName("release") {
            // Release build: com.oasis.app
            
            isMinifyEnabled = true
            isShrinkResources = false
            
            // Use release signing config for local builds if available
            val envStoreFile = System.getenv("RELEASE_STORE_FILE")
            if (!envStoreFile.isNullOrEmpty()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // For CI: build unsigned or with debug (CI action handles final signing)
                signingConfig = signingConfigs.getByName("debug")
            }
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

configurations.all {
    resolutionStrategy {
        force("androidx.annotation:annotation-experimental:1.4.1")
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.google.android.gms:play-services-location:21.0.1")
    implementation("androidx.localbroadcastmanager:localbroadcastmanager:1.1.0")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("com.google.firebase:firebase-messaging:24.0.0")
}