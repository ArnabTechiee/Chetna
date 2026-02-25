plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.chetna_app"
    compileSdk = 35

    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.chetna_app"
        minSdk = 24
        targetSdk = 35
        
        // FIXED: .toInt() instead of .toInteger()
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName

        multiDexEnabled = true
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("debug")
        }
        
        getByName("debug") {
            versionNameSuffix = "-DEBUG"
        }
    }
    
    buildFeatures {
        viewBinding = true 
        buildConfig = true 
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")
    implementation("androidx.multidex:multidex:2.0.1")
    
    // Explicitly using the stable version here
    implementation("androidx.core:core-ktx:1.13.1") 
    implementation("androidx.appcompat:appcompat:1.6.1")
    
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
}

// --- CRITICAL FIX: FORCE LIBRARIES TO STAY ON STABLE VERSIONS ---
configurations.all {
    resolutionStrategy {
        force("androidx.browser:browser:1.8.0")
        force("androidx.core:core-ktx:1.13.1")
        force("androidx.core:core:1.13.1")
    }
}