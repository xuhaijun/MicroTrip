plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.xuhai.micro_trip"
    compileSdk = flutter.compileSdkVersion
    // 本项目全部插件为纯 Dart/Kotlin/Java 实现，无原生 C/C++ 代码，无需指定 NDK。
    // 移除 ndkVersion 可避免 AGP 强制下载 NDK（国内网络下载常失败）。
    // ndkVersion = flutter.ndkVersion

    compileOptions {
        // 启用核心库脱糖：flutter_local_notifications 等依赖使用 Java 8+ API，
        // minSdk=26 设备缺少这些 API，需通过 desugaring 在运行时提供（AGP 9 强制要求显式开启）。
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.xuhai.micro_trip"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // minSdk 26：Health Connect（健康步数读取）要求 Android 8.0+（API 26）
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 【包体积优化·可选】仅打包 64 位架构（arm64-v8a）。
        // 现代设备（minSdk 26+）几乎全部为 64 位；剔除 armeabi-v7a / x86_64
        // 可让原生 .so（geolocator / health / background-service 等）体积减半。
        // ⚠️ 启用后要求本地 NDK 用于对 .so 做 strip；若构建报 "NDK not configured"，
        //    请安装 NDK 或保持注释，改用下方「flutter build appbundle」方案（Play 按设备分发所需 ABI）。
        // ndk {
        //     abiFilters += "arm64-v8a"
        // }
    }

    // === 发布签名配置（Phase 5：已生成 release keystore 并接入）===
    // keystore 生成命令（JDK 21 keytool，注意 Git Bash 需 MSYS_NO_PATHCONV=1）：
    //   keytool -genkeypair -v -keystore "D:/FlutterProjects/MicroTrip/android/app/keystore/release.keystore" ^
    //     -alias release -keyalg RSA -keysize 2048 -validity 10000
    // 密钥密码保存在 android/app/keystore/key.properties（已被 .gitignore 忽略，切勿提交）。
    // 说明：本项目 Gradle Kotlin DSL 脚本作用域内 java.util 被 AGP 隐式符号遮蔽，
    // 故不依赖 java.util.Properties，改用 Kotlin 标准库手动解析 key=value。
    val keyPropsFile = file("keystore/key.properties")
    val keyProps = mutableMapOf<String, String>()
    if (keyPropsFile.exists()) {
        keyPropsFile.readLines().forEach { raw ->
            val line = raw.trim()
            if (line.isNotEmpty() && !line.startsWith("#")) {
                val eq = line.indexOf('=')
                if (eq > 0) {
                    keyProps[line.substring(0, eq).trim()] = line.substring(eq + 1).trim()
                }
            }
        }
    }
    signingConfigs {
        create("release") {
            storeFile = file(keyProps["storeFile"] ?: "keystore/release.keystore")
            storePassword = keyProps["storePassword"] ?: ""
            keyAlias = keyProps["keyAlias"] ?: "release"
            keyPassword = keyProps["keyPassword"] ?: ""
        }
    }

    buildTypes {
        release {
            // 使用上面配置的 release 签名（keystore/key.properties 驱动）
            signingConfig = signingConfigs.getByName("release")
            // 【包体积优化】开启 R8 代码混淆 + 资源缩减，移除未使用代码与资源
            // （含未引用字符串、图片、布局）。与 --tree-shake-icons 配合效果最佳。
            isMinifyEnabled = true
            isShrinkResources = true
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

// 核心库脱糖运行时依赖（与上面 isCoreLibraryDesugaringEnabled 配套）
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
