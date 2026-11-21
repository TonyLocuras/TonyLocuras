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

// Fuerza el mismo compileSdk en todos los plugins (algunos compilan con 33
// y las dependencias de androidx exigen 34 o más).
subprojects {
    afterEvaluate {
        val ext = project.extensions.findByName("android")
        if (ext != null) {
            try {
                ext.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType).invoke(ext, 37)
            } catch (e: Exception) {
                println("No se pudo fijar compileSdk en ${project.name}: ${e.message}")
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
