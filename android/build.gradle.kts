run {
    val packageConfig = rootProject.projectDir.resolve("../.dart_tool/package_config.json")
    val audioServiceRoot = if (packageConfig.exists()) {
        Regex("""\{\s*"name":\s*"audio_service".*?"rootUri":\s*"file://([^"]+)""", RegexOption.DOT_MATCHES_ALL)
            .find(packageConfig.readText())
            ?.groupValues
            ?.get(1)
    } else {
        null
    }
    if (audioServiceRoot != null) {
        val audioService = file("$audioServiceRoot/android/src/main/java/com/ryanheise/audioservice/AudioService.java")
        val old = """
|    int getResourceId(String resource) {
|        String[] parts = resource.split("/");
|        String resourceType = parts[0];
|        String resourceName = parts[1];
|        return getResources().getIdentifier(resourceName, resourceType, getApplicationContext().getPackageName());
|    }
""".trimMargin()
        val replacement = """
|    int getResourceId(String resource) {
|        String[] parts = resource.split("/");
|        String resourceType = parts[0];
|        String resourceName = parts[1];
|        int resourceId = getResources().getIdentifier(resourceName, resourceType, getApplicationContext().getPackageName());
|        if (resourceId != 0) {
|            return resourceId;
|        }
|        if (!"drawable".equals(resourceType)) {
|            return 0;
|        }
|        switch (resourceName) {
|            case "audio_service_fast_forward":
|                return R.drawable.audio_service_fast_forward;
|            case "audio_service_fast_rewind":
|                return R.drawable.audio_service_fast_rewind;
|            case "audio_service_pause":
|                return R.drawable.audio_service_pause;
|            case "audio_service_play_arrow":
|                return R.drawable.audio_service_play_arrow;
|            case "audio_service_skip_next":
|                return R.drawable.audio_service_skip_next;
|            case "audio_service_skip_previous":
|                return R.drawable.audio_service_skip_previous;
|            case "audio_service_stop":
|                return R.drawable.audio_service_stop;
|            default:
|                return 0;
|        }
|    }
""".trimMargin()
        val source = audioService.readText()
        if (source.contains(old)) {
            audioService.writeText(source.replace(old, replacement))
        }
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
    val forceCompileSdk = {
        extensions.findByName("android")?.let { android ->
            runCatching {
                android.javaClass
                    .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                    .invoke(android, 36)
            }
        }
    }
    if (state.executed) forceCompileSdk() else afterEvaluate { forceCompileSdk() }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
