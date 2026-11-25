plugins {
    id(libs.plugins.android.library.get().pluginId)
    id("com.chaquo.python") version "17.2.0"
}

android {
    namespace = "org.amnezia.vpn.relayadmin"
    defaultConfig {
        ndk.abiFilters += providers.gradleProperty("qtTargetAbiList").get().split(",")
    }
}

chaquopy {
    defaultConfig {
        version = "3.13"
        extractPackages("coldwire_admin_bundle")
        pip {
            options("--only-binary", ":all:", "--find-links",
                providers.gradleProperty("coldwireAdminWheels").get())
            install("paramiko==5.1.0")
            install("cryptography==50.0.2")
            install("cffi==2.0.0")
        }
    }
    sourceSets {
        getByName("main").setSrcDirs(listOf(providers.gradleProperty("coldwireAdminBundle").get()))
    }
}
