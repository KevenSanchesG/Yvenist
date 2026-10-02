import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Chave de envio à loja: descrita em android/key.properties, que não é versionado
// (modelo em android/key.properties.example; passo a passo em
// docs/09-guides/android-release.md). Sem esse arquivo um APK de release ainda
// é gerado, assinado com a chave de debug, para testar na própria máquina.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Um app bundle só serve para enviar à loja, e a loja recusa a chave de debug.
// Sem a chave de envio o pacote nem começa a ser gerado: o erro aparece aqui,
// com o motivo, e não minutos depois nem na tela de envio do Play Console.
gradle.taskGraph.whenReady {
    if (hasTask("${project.path}:bundleRelease") && !hasReleaseKeystore) {
        throw GradleException(
            "Sem android/key.properties o app bundle sairia assinado com a chave de " +
                "debug, que a Play Store recusa. Crie a chave de envio e o arquivo: " +
                "docs/09-guides/android-release.md",
        )
    }
}

android {
    namespace = "com.yvenist.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Identifica o app nas lojas para sempre: não pode mudar depois da
        // primeira publicação. O mesmo valor é o Bundle Identifier no iOS.
        applicationId = "com.yvenist.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
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
            // Com a chave de publicação configurada, é ela que assina. Sem ela,
            // a de debug: serve para `flutter run --release` na própria
            // máquina, mas a Play Store recusa um app assinado assim.
            signingConfig = signingConfigs.getByName(
                if (hasReleaseKeystore) "release" else "debug",
            )
        }
    }
}

flutter {
    source = "../.."
}
