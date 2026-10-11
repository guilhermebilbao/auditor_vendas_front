import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Chave de assinatura do release: android/key.properties (fora do git), com storeFile,
// storePassword, keyAlias e keyPassword. Sem o arquivo, o release sai com a chave de debug,
// que serve para testar no aparelho, mas não para distribuir (README, "Gerar o app").
val propriedadesDaChave = Properties().apply {
    val arquivo = rootProject.file("key.properties")
    if (arquivo.exists()) arquivo.inputStream().use { load(it) }
}

android {
    namespace = "com.emplakey.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Definitivo: a Play Store não deixa trocar depois de publicar.
        applicationId = "com.emplakey.app"
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
        if (!propriedadesDaChave.isEmpty) {
            create("release") {
                storeFile = file(propriedadesDaChave.getProperty("storeFile"))
                storePassword = propriedadesDaChave.getProperty("storePassword")
                keyAlias = propriedadesDaChave.getProperty("keyAlias")
                keyPassword = propriedadesDaChave.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (propriedadesDaChave.isEmpty) {
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("release")
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
