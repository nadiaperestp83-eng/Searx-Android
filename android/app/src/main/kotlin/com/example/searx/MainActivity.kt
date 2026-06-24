package com.zackptg5.searx

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "searxgo/private_browser",
            PrivateBrowserFactory(flutterEngine.dartExecutor.binaryMessenger)
        )
    }
}
