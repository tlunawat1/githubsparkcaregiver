package com.parentalcare.parentalCareApp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class CriticalAlertRingingService : Service() {
    private var mediaPlayer: MediaPlayer? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START
        if (action == ACTION_STOP) {
            stopRinging()
            stopForeground(true)
            stopSelf()
            return START_NOT_STICKY
        }

        val alertId = intent?.getStringExtra(EXTRA_ALERT_ID) ?: ""
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Critical Alert"
        val body = intent?.getStringExtra(EXTRA_BODY) ?: "Attention required"
        val route = intent?.getStringExtra(EXTRA_ROUTE) ?: "/dependent"

        val notification = buildNotification(alertId, title, body, route)
        startForeground(NOTIFICATION_ID, notification)
        startRinging()

        return START_STICKY
    }

    private fun buildNotification(
        alertId: String,
        title: String,
        body: String,
        route: String
    ): Notification {
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Critical Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Critical alerts that require immediate action"
                setSound(
                    null,
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                enableVibration(true)
                setBypassDnd(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("critical_route", route)
            putExtra("critical_alert_id", alertId)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            0,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, CriticalAlertRingingService::class.java).apply {
            action = ACTION_STOP
            putExtra(EXTRA_ALERT_ID, alertId)
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .addAction(0, "Dismiss", stopPendingIntent)
            .setContentIntent(fullScreenPendingIntent)
            .build()
    }

    private fun startRinging() {
        if (mediaPlayer != null) return
        mediaPlayer = MediaPlayer().apply {
            val ringtoneUri = android.media.RingtoneManager.getDefaultUri(
                android.media.RingtoneManager.TYPE_ALARM
            )
            setDataSource(this@CriticalAlertRingingService, ringtoneUri)
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            isLooping = true
            prepare()
            start()
        }
    }

    private fun stopRinging() {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
    }

    override fun onDestroy() {
        stopRinging()
        super.onDestroy()
    }

    companion object {
        const val ACTION_START = "critical_alert_start"
        const val ACTION_STOP = "critical_alert_stop"
        const val EXTRA_ALERT_ID = "alert_id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_ROUTE = "route"
        const val CHANNEL_ID = "critical_alerts"
        const val NOTIFICATION_ID = 9111
    }
}
