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
    if (project.name != "app") {
        afterEvaluate {
            project.extensions.findByName("android")?.let { ext ->
                try {
                    ext.javaClass.getMethod("setCompileSdk", Int::class.java).invoke(ext, 35)
                } catch (e: Exception) {
                    ext.javaClass.getMethod("setCompileSdkVersion", Int::class.java).invoke(ext, 35)
                }
            }
        }
    }
}