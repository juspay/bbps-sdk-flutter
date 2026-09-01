// hypersdkflutter reads these root-project properties to decide which native
// HyperSDK to pull in (it otherwise falls back to 2.2.2) and which client's
// assets to bundle. Kept in sync with the iOS side and the bbps block in
// app/build.gradle.
extra["hyperSDKVersion"] = "2.2.7-rc.28"
extra["clientId"] = "stock"

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
