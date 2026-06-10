package com.team4tune.team4tune

import android.content.Intent
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var pendingSharedText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
        shareChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitial" -> {
                    val text = pendingSharedText
                    pendingSharedText = null
                    result.success(text)
                }
                else -> result.notImplemented()
            }
        }
        handleShareIntent(intent)
        roomChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        roomChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val args = call.arguments as? Map<*, *>
                    startRoomService(
                        RoomForegroundService.ACTION_START,
                        args?.get("roomCode") as? String ?: "",
                        args?.get("title") as? String ?: "Connected",
                        args?.get("playing") as? Boolean ?: false,
                    )
                    result.success(null)
                }
                "update" -> {
                    val args = call.arguments as? Map<*, *>
                    startRoomService(
                        RoomForegroundService.ACTION_UPDATE,
                        args?.get("roomCode") as? String ?: "",
                        args?.get("title") as? String ?: "Connected",
                        args?.get("playing") as? Boolean ?: false,
                    )
                    result.success(null)
                }
                "stop" -> {
                    stopRoomService()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent?) {
        val text = extractSharedText(intent) ?: return
        val channel = shareChannel
        if (channel != null) {
            channel.invokeMethod("shared", text)
        } else {
            pendingSharedText = text
        }
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") return null
        return intent.getStringExtra(Intent.EXTRA_TEXT)?.takeIf { it.isNotBlank() }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        if (roomChannel != null) {
            roomChannel?.setMethodCallHandler(null)
            roomChannel = null
        }
        if (shareChannel != null) {
            shareChannel?.setMethodCallHandler(null)
            shareChannel = null
        }
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun startRoomService(action: String, roomCode: String, title: String, playing: Boolean) {
        val intent = Intent(this, RoomForegroundService::class.java)
            .setAction(action)
            .putExtra(RoomForegroundService.EXTRA_ROOM_CODE, roomCode)
            .putExtra(RoomForegroundService.EXTRA_TITLE, title)
            .putExtra(RoomForegroundService.EXTRA_PLAYING, playing)
        ContextCompat.startForegroundService(this, intent)
    }

    private fun stopRoomService() {
        val intent = Intent(this, RoomForegroundService::class.java).setAction(RoomForegroundService.ACTION_STOP)
        startService(intent)
    }

    companion object {
        private const val CHANNEL = "team4tune/room_foreground"
        private const val SHARE_CHANNEL = "team4tune/share"
        private var roomChannel: MethodChannel? = null
        private var shareChannel: MethodChannel? = null

        fun sendRoomAction(action: String) {
            roomChannel?.invokeMethod("action", action)
        }
    }
}
