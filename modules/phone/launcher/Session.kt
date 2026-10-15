package dev.neru.bare

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.Icon
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import org.json.JSONObject

private const val CHANNEL = "pc"
private val ROUTES = mapOf("tether" to "usb tether", "tailnet" to "tailnet")

class SessionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val session = Intent(context, Session::class.java)
        val route = intent.getStringExtra("route")
        if (route in ROUTES) context.startForegroundService(session.putExtra("route", route)) else context.stopService(session)
    }
}

class Session : Service(), SharedPreferences.OnSharedPreferenceChangeListener {
    private lateinit var prefs: SharedPreferences
    private var start = System.currentTimeMillis()
    private var route = ""
    private var closing = false

    override fun onBind(intent: Intent?) = null

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        prefs.registerOnSharedPreferenceChangeListener(this)
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(NotificationChannel(CHANNEL, "pc session", NotificationManager.IMPORTANCE_LOW))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "kill") {
            val run = Intent("com.termux.RUN_COMMAND")
                .setClassName(TERMUX, "$TERMUX.app.RunCommandService")
                .putExtra("$TERMUX.RUN_COMMAND_PATH", "/data/data/$TERMUX/files/usr/bin/bash")
                .putExtra("$TERMUX.RUN_COMMAND_ARGUMENTS", arrayOf("-c", "pkill -KILL -f '^ssh .*tmux new -A -s phone\$' || am broadcast -n dev.neru.bare/.SessionReceiver"))
                .putExtra("$TERMUX.RUN_COMMAND_BACKGROUND", true)
            runCatching { startForegroundService(run) }
            closing = true
            getSystemService(NotificationManager::class.java).notify(1, note())
            return START_NOT_STICKY
        }
        intent?.getStringExtra("route")?.let {
            route = it
            start = System.currentTimeMillis()
            closing = false
        }
        startForeground(1, note(), ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        prefs.unregisterOnSharedPreferenceChangeListener(this)
    }

    override fun onSharedPreferenceChanged(prefs: SharedPreferences?, key: String?) {
        getSystemService(NotificationManager::class.java).notify(1, note())
    }

    private fun note(): Notification {
        val theme = JSONObject(prefs.getString(PREFS, null) ?: "{}")
        fun color(key: String, fallback: Int) = runCatching { Color.parseColor(theme.getString(key)) }.getOrDefault(fallback)
        val title = SpannableString("pc · ${if (closing) "disconnecting" else ROUTES[route]}").apply {
            setSpan(ForegroundColorSpan(color("accent", Color.WHITE)), 0, 2, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        val open = Intent().setClassName(TERMUX, "$TERMUX.app.TermuxActivity").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return Notification.Builder(this, CHANNEL)
            .setSmallIcon(glyph(theme.optString("font")))
            .setColor(color("bgDim", Color.BLACK))
            .setColorized(true)
            .setContentTitle(title)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setWhen(start)
            .setOngoing(true)
            .setContentIntent(PendingIntent.getActivity(this, 0, open, PendingIntent.FLAG_IMMUTABLE))
            .addAction(
                Notification.Action.Builder(
                    null,
                    "kill",
                    PendingIntent.getService(this, 0, Intent(this, Session::class.java).setAction("kill"), PendingIntent.FLAG_IMMUTABLE),
                ).build(),
            )
            .build()
    }

    private fun glyph(font: String): Icon {
        val size = (24 * resources.displayMetrics.density).toInt()
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = runCatching { Typeface.createFromAsset(assets, "fonts/$font.ttf") }.getOrDefault(Typeface.MONOSPACE)
            textSize = size * 0.6f
            textAlign = Paint.Align.CENTER
            color = Color.WHITE
        }
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        Canvas(bitmap).drawText(">_", size / 2f, size / 2f - (paint.ascent() + paint.descent()) / 2, paint)
        return Icon.createWithBitmap(bitmap)
    }
}
