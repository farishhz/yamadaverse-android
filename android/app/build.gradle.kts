import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val propertiKunci = Properties()
val berkasPropertiKunci = rootProject.file("key.properties")
if (berkasPropertiKunci.exists()) {
    berkasPropertiKunci.inputStream().use { propertiKunci.load(it) }
}

android {
    namespace = "io.yamadaverse"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.yamadaverse"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (berkasPropertiKunci.exists()) {
            create("release") {
                keyAlias = propertiKunci["keyAlias"] as String
                keyPassword = propertiKunci["keyPassword"] as String
                storeFile = file(propertiKunci["storeFile"] as String)
                storePassword = propertiKunci["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (berkasPropertiKunci.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
