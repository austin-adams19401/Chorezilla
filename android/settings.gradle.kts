pluginManagement {
    val flutterSdkPath =
        run {
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
    id("com.android.application") version "9.3.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.6.0") apply false
    // END: FlutterFire Configuration
    // Flutter 3.50 requires AGP 9.1.1+ / Gradle 9.3.1+. Kotlin 2.4.20 matches that template
    // and can read purchases-android 11, which is built with Kotlin 2.2.
    id("org.jetbrains.kotlin.android") version "2.4.20" apply false
}

include(":app")
