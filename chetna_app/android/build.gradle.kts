// RECTIFIED: Added buildscript to handle Firebase Google Services dependency
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Essential for reading google-services.json
        classpath("com.google.gms:google-services:4.3.15") 
    }
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

subprojects {
    project.evaluationDependsOn(":app")
}

/**
 * RECTIFIED: Robust Namespace Injection for Kotlin DSL
 * This ensures older plugins are assigned a namespace, preventing build errors.
 */
subprojects {
    val setupNamespace = {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            if (android.namespace == null) {
                android.namespace = project.group.toString()
            }
        }
    }
    
    if (project.state.executed) {
        setupNamespace()
    } else {
        project.afterEvaluate { 
            setupNamespace() 
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

