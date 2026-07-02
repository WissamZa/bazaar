package io.github.wissamza.bazaar

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * QUALITY (Finding 6): Previously the AndroidManifest declared intent-filters
 * for `application/json` files (both VIEW and SEND actions), so tapping a
 * `.json` file in another app would offer to open it with Bazaar — but
 * `receive_sharing_intent` was never wired up on the Kotlin side, so the
 * file path was silently dropped and the user saw nothing happen.
 *
 * QUALITY (Finding 12): Package renamed from `com.example.bazaar` (the
 * default Flutter template value, rejected by the Play Store) to
 * `io.github.wissamza.bazaar`.
 *
 * This MainActivity now:
 *   1. Saves the incoming Intent on launch (cold start).
 *   2. Forwards it to the Dart side via the `receive_sharing_intent` method
 *      channel.
 *   3. Handles `onNewIntent` for the case where the activity is already
 *      running (warm start).
 *
 * The Dart side (in `lib/main.dart`) listens on the same channel and calls
 * `ShareService.importFromFile(path)` with the received file path.
 */
class MainActivity : FlutterActivity() {
    private val kChannelName = "receive_sharing_intent"
    private var initialIntent: Intent? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Capture the launch intent so we can forward it once the Flutter
        // engine is up.
        initialIntent = intent
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            kChannelName).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialMedia" -> {
                        val paths = arrayListOf<String>()
                        initialIntent?.let { i ->
                            extractSharedFilePath(i)?.let { paths.add(it) }
                            initialIntent = null
                        }
                        result.success(paths)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Warm start: the activity was already running. Forward immediately.
        val path = extractSharedFilePath(intent) ?: return
        methodChannel?.invokeMethod("onShareMediaChanged", arrayListOf(path))
    }

    /// Pull the file path out of either a SEND or VIEW intent.
    private fun extractSharedFilePath(intent: Intent): String? {
        val uri = intent.data ?: intent.getParcelableExtra<android.net.Uri>(
            Intent.EXTRA_STREAM)
            ?: return null
        // Resolve content:// URIs to a real filesystem path via the content
        // resolver. For file:// URIs, just use the path directly.
        return if (uri.scheme == "file") {
            uri.path
        } else {
            try {
                contentResolver.openInputStream(uri)?.use { input ->
                    // Copy to the app's cache dir so the Dart side can read it
                    // via a stable path.
                    val cacheFile = java.io.File(cacheDir,
                        "shared_${System.currentTimeMillis()}.json")
                    java.io.FileOutputStream(cacheFile).use { out ->
                        input.copyTo(out)
                    }
                    cacheFile.absolutePath
                }
            } catch (e: Exception) {
                null
            }
        }
    }
}
