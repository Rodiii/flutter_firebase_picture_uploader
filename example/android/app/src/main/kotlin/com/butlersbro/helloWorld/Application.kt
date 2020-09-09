package com.butlersbro.helloWorld
 
import io.flutter.app.FlutterApplication
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.PluginRegistry.PluginRegistrantCallback
import io.flutter.plugins.GeneratedPluginRegistrant
import android.content.Context
import androidx.multidex.MultiDex
 
class Application : FlutterApplication(), PluginRegistrantCallback {
 
    override fun onCreate() {
        super.onCreate()
    }
 
    override fun registerWith(registry: PluginRegistry?) {
    }

    override fun attachBaseContext(base: Context) {
      super.attachBaseContext(base)
      MultiDex.install(this)
    }

}