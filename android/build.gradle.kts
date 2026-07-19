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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    // 1. Configure namespace immediately when plugin is applied (must be done early)
    plugins.withId("com.android.library") {
        configure<com.android.build.gradle.BaseExtension> {
            if (namespace == null) {
                val manifestFile = file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val manifestContent = manifestFile.readText()
                    val match = Regex("package=\"([^\"]+)\"").find(manifestContent)
                        ?: Regex("package='([^']+)'").find(manifestContent)
                    if (match != null) {
                        namespace = match.groupValues[1]
                    } else {
                        namespace = "com.codevalop.${project.name.replace("-", "_")}"
                    }
                } else {
                    namespace = "com.codevalop.${project.name.replace("-", "_")}"
                }
            }
        }

        // Align Kotlin compile jvmTarget with Java compile target dynamically
        tasks.configureEach {
            if (name.startsWith("compile") && name.endsWith("Kotlin")) {
                try {
                    val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
                    val targetCompat = android?.compileOptions?.targetCompatibility
                    if (targetCompat != null) {
                        val jvmTargetValue = when (targetCompat) {
                            JavaVersion.VERSION_17 -> "17"
                            JavaVersion.VERSION_11 -> "11"
                            JavaVersion.VERSION_1_8 -> "1.8"
                            else -> targetCompat.toString()
                        }
                        val kotlinOptions = property("kotlinOptions")
                        kotlinOptions?.javaClass?.getMethod("setJvmTarget", String::class.java)?.invoke(kotlinOptions, jvmTargetValue)
                    }
                } catch (e: Exception) {}
            }
        }
    }

    plugins.withId("com.android.application") {
        configure<com.android.build.gradle.BaseExtension> {
            if (namespace == null) {
                val manifestFile = file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val manifestContent = manifestFile.readText()
                    val match = Regex("package=\"([^\"]+)\"").find(manifestContent)
                        ?: Regex("package='([^']+)'").find(manifestContent)
                    if (match != null) {
                        namespace = match.groupValues[1]
                    } else {
                        namespace = "com.codevalop.${project.name.replace("-", "_")}"
                    }
                } else {
                    namespace = "com.codevalop.${project.name.replace("-", "_")}"
                }
            }
        }
    }

    // 2. Configure compileSdkVersion surgically for raw_sound after evaluation
    val configureRawSoundSdk = {
        if (project.name == "raw_sound") {
            configure<com.android.build.gradle.BaseExtension> {
                compileSdkVersion(34)
            }
        }
    }

    if (state.executed) {
        configureRawSoundSdk()
    } else {
        afterEvaluate {
            configureRawSoundSdk()
        }
    }
}
