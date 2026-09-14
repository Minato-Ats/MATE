import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (Play App Signing upload key). key.properties/*.jks are
// gitignored and never committed — see android/.gitignore.
//
// Deliberately does NOT fall back to the debug signing config when
// key.properties is missing (that was fine during development, but this
// project is now pre-release: shipping a "release" build silently signed
// with the debug key must never happen again). Instead, any Gradle task
// whose name contains "Release" is made to fail fast — see the
// tasks.configureEach block below — while debug builds are completely
// unaffected regardless of whether key.properties exists.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.minatoapps.mate"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.minatoapps.mate"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Real upload-key signing when key.properties is present;
            // otherwise left unsigned — the tasks.configureEach block below
            // turns that into an explicit build failure before any release
            // artifact could actually be produced, rather than silently
            // falling back to the debug key or shipping an unsigned build.
            signingConfig = if (hasReleaseSigning) signingConfigs.getByName("release") else null
        }
    }
}

// Refuse to produce ANY release-flavored output without real signing in
// place. Matches by task name (contains "Release") rather than hardcoding
// just assembleRelease/bundleRelease so this can't be bypassed by invoking
// an intermediate Gradle task directly. Debug tasks never match this and
// are completely unaffected either way.
tasks.configureEach {
    if (!hasReleaseSigning && name.contains("Release")) {
        doFirst {
            throw GradleException(
                "Refusing to run '$name': no release signing found at " +
                    "android/key.properties. Release builds must be signed with the " +
                    "real upload keystore — see the signing setup notes; debug builds " +
                    "are unaffected by this check.",
            )
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
