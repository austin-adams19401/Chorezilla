plugins {
    id("org.jetbrains.kotlin.android") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// FlutterFire plugins skip the Kotlin Gradle plugin on AGP 9 and expect
// built-in Kotlin to compile their sources. This app keeps
// android.builtInKotlin=false so older plugins can still apply
// org.jetbrains.kotlin.android. Apply that plugin for any Android library
// that did not apply it itself.
subprojects {
    pluginManager.withPlugin("com.android.library") {
        if (!pluginManager.hasPlugin("org.jetbrains.kotlin.android")) {
            pluginManager.apply("org.jetbrains.kotlin.android")
            extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension>(
                "kotlin",
            ) {
                compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
