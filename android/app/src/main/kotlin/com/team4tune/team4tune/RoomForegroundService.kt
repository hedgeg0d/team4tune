package com.team4tune.team4tune

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class RoomForegroundService : Service() {
    private var roomCode = ""
    private var title = "Connected"
    private var playing = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForegroundCompat()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_PAUSE -> {
                MainActivity.sendRoomAction("pause")
                playing = false
                show()
            }
            ACTION_RESUME -> {
                MainActivity.sendRoomAction("resume")
                playing = true
                show()
            }
            ACTION_REWIND -> MainActivity.sendRoomAction("rewind")
            ACTION_FORWARD -> MainActivity.sendRoomAction("forward")
            ACTION_LEAVE -> MainActivity.sendRoomAction("leave")
            ACTION_START, ACTION_UPDATE -> {
                roomCode = intent.getStringExtra(EXTRA_ROOM_CODE).orEmpty()
                title = intent.getStringExtra(EXTRA_TITLE).orEmpty().ifEmpty { "Connected" }
                playing = intent.getBooleanExtra(EXTRA_PLAYING, false)
                show()
            }
        }
        return START_STICKY
    }

    private fun show() {
        ensureChannel()
        val notification = notification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun notification(): Notification {
        val openIntent = packageManager.getLaunchIntentForPackage(packageName) ?: Intent(this, MainActivity::class.java)
        val open = PendingIntent.getActivity(this, 0, openIntent, flags())
        val playPauseAction = if (playing) {
            NotificationCompat.Action(R.drawable.audio_service_pause, "Pause", action(ACTION_PAUSE, 1))
        } else {
            NotificationCompat.Action(R.drawable.audio_service_play_arrow, "Play", action(ACTION_RESUME, 2))
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.notification_icon)
            .setContentTitle(if (roomCode.isEmpty()) "team4tune" else "Room $roomCode")
            .setContentText(title)
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(NotificationCompat.Action(R.drawable.audio_service_fast_rewind, "-10s", action(ACTION_REWIND, 3)))
            .addAction(playPauseAction)
            .addAction(NotificationCompat.Action(R.drawable.audio_service_fast_forward, "+10s", action(ACTION_FORWARD, 4)))
            .addAction(NotificationCompat.Action(R.drawable.audio_service_stop, "Leave", action(ACTION_LEAVE, 5)))
            .build()
    }

    private fun action(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, RoomForegroundService::class.java).setAction(action)
        return PendingIntent.getService(this, requestCode, intent, flags())
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(NotificationChannel(CHANNEL_ID, "Room connection", NotificationManager.IMPORTANCE_LOW))
    }

    private fun flags(): Int {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return flags
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    companion object {
        const val CHANNEL_ID = "com.team4tune.team4tune.room"
        const val NOTIFICATION_ID = 4404
        const val ACTION_START = "com.team4tune.team4tune.room.START"
        const val ACTION_UPDATE = "com.team4tune.team4tune.room.UPDATE"
        const val ACTION_STOP = "com.team4tune.team4tune.room.STOP"
        const val ACTION_PAUSE = "com.team4tune.team4tune.room.PAUSE"
        const val ACTION_RESUME = "com.team4tune.team4tune.room.RESUME"
        const val ACTION_REWIND = "com.team4tune.team4tune.room.REWIND"
        const val ACTION_FORWARD = "com.team4tune.team4tune.room.FORWARD"
        const val ACTION_LEAVE = "com.team4tune.team4tune.room.LEAVE"
        const val EXTRA_ROOM_CODE = "roomCode"
        const val EXTRA_TITLE = "title"
        const val EXTRA_PLAYING = "playing"
    }
}
