package dev.neru.bare

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.os.SystemClock
import android.provider.CalendarContract
import android.provider.Settings
import android.text.Editable
import android.text.InputType
import android.text.TextPaint
import android.text.SpannableStringBuilder
import android.text.TextUtils
import android.text.TextWatcher
import android.text.format.DateFormat
import android.text.style.ForegroundColorSpan
import android.view.GestureDetector
import android.util.Base64
import android.util.TypedValue
import android.view.HapticFeedbackConstants
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.BaseAdapter
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.GridView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextClock
import android.widget.TextView
import android.window.OnBackInvokedDispatcher
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.Inet4Address
import java.net.NetworkInterface
import java.net.URL
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale
import kotlin.math.abs
import kotlin.math.ceil

const val PREFS = "theme"
private const val STATE = "state"
private const val GRID = 48
private const val PAUSE = "\u258c\u258c"
const val TERMUX = "com.termux"
private const val PLACE = "porto"
private const val FORECAST =
    "https://api.open-meteo.com/v1/forecast?latitude=41.15&longitude=-8.61&timezone=auto&forecast_days=3" +
        "&current=temperature_2m,apparent_temperature,weather_code&daily=temperature_2m_max,temperature_2m_min"
private const val GB = 1073741824.0
private val SWATCHES = listOf("red", "green", "yellow", "blue", "magenta", "cyan")
private val COLORS = listOf("bgDim", "bgAlt", "border", "fg", "fgDim", "fgMuted", "accent", "error", "success") + SWATCHES
private val HEX = Regex("#[0-9a-fA-F]{6}")
private const val WALLS = "walls"
private val ID = Regex("[A-Za-z0-9._+-]+")
private val LECTURE = Regex("^(PL|TP|T) - (\\S+) - (.+)$")
private val HEAD = DateTimeFormatter.ofPattern("EEE d")
private val SHORT = DateTimeFormatter.ofPattern("d MMM")

class ThemeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val theme = runCatching { JSONObject(intent.getStringExtra("theme") ?: return) }.getOrNull() ?: return
        val clean = JSONObject()
        for (key in COLORS) {
            val value = theme.optString(key)
            if (!HEX.matches(value)) return
            clean.put(key, value)
        }
        clean.put("font", theme.optString("font").filter(Char::isLetterOrDigit))
        clean.put("name", theme.optString("name").filter { it.isLetterOrDigit() || it == '-' })
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(PREFS, clean.toString()).apply()
    }
}

class WallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val dir = File(context.filesDir, WALLS).apply { mkdirs() }
        val walls = context.getSharedPreferences(WALLS, Context.MODE_PRIVATE)
        val thumbs = intent.extras?.keySet().orEmpty().filter { it.startsWith("t:") && ID.matches(it.removePrefix("t:")) }
        val list = intent.getStringExtra("list")
        when {
            thumbs.isNotEmpty() -> {
                for (key in thumbs) {
                    val data = intent.getStringExtra(key)?.takeIf { it.length < 400_000 } ?: continue
                    val bytes = runCatching { Base64.decode(data, Base64.DEFAULT) }.getOrNull() ?: continue
                    File(dir, key.removePrefix("t:")).writeBytes(bytes)
                }
                walls.edit().putLong("at", System.currentTimeMillis()).apply()
            }
            list != null -> {
                val ids = list.lines().filter(ID::matches)
                dir.listFiles()?.filter { it.name !in ids }?.forEach { it.delete() }
                val current = intent.getStringExtra("current").orEmpty()
                walls.edit()
                    .putString("list", JSONArray(ids).toString())
                    .putString("current", if (ID.matches(current)) current else "")
                    .putString("status", "")
                    .apply()
            }
            else -> walls.edit().putString("status", intent.getStringExtra("status").orEmpty().filter { it.isLetter() || it == ' ' }).apply()
        }
    }
}

class Home : Activity(), SharedPreferences.OnSharedPreferenceChangeListener {
    private class App(val label: String, val component: ComponentName, val pixels: Bitmap) {
        val id: String = component.flattenToString()
    }

    private class Event(val id: Long, val begin: Long, val end: Long, val title: String, val place: String, val note: String, val allDay: Boolean) {
        var lane = 0
        var lanes = 1
    }

    private inner class Week : View(this@Home) {
        private val zone = ZoneId.systemDefault()
        private var monday = LocalDate.now()
        private var timed = List(7) { listOf<Event>() }
        private var whole = List(7) { listOf<Event>() }
        var count = 5
            private set
        private var first = 8
        private var last = 19
        private val hits = mutableListOf<Pair<RectF, Event>>()
        private val paint = TextPaint(Paint.ANTI_ALIAS_FLAG)
        private val taps = GestureDetector(
            this@Home,
            object : GestureDetector.SimpleOnGestureListener() {
                override fun onDown(e: MotionEvent) = true

                override fun onSingleTapUp(e: MotionEvent): Boolean {
                    hits.lastOrNull { it.first.contains(e.x, e.y) }?.let { visit(it.second) }
                    return true
                }
            },
        )

        override fun onTouchEvent(event: MotionEvent) = taps.onTouchEvent(event)

        fun show(start: LocalDate, events: List<Event>) {
            monday = start
            val days = List(7) { start.plusDays(it.toLong()) }
            fun utc(ms: Long) = Instant.ofEpochMilli(ms).atZone(ZoneOffset.UTC).toLocalDate()
            timed = days.map { day -> events.filter { !it.allDay && Instant.ofEpochMilli(it.begin).atZone(zone).toLocalDate() == day }.also(::lanes) }
            whole = days.map { day -> events.filter { it.allDay && utc(it.begin) <= day && day < maxOf(utc(it.end), utc(it.begin).plusDays(1)) } }
            count = if ((5..6).any { timed[it].isNotEmpty() || whole[it].isNotEmpty() }) 7 else 5
            val shown = (0 until count).flatMap { i -> timed[i].map { hours(it.begin, days[i]) to hours(it.end, days[i]) } }
            first = minOf(8, shown.minOfOrNull { it.first.toInt() } ?: 8)
            last = maxOf(19, shown.maxOfOrNull { ceil(it.second).toInt() } ?: 19)
            invalidate()
        }

        private fun hours(ms: Long, day: LocalDate): Float {
            val at = Instant.ofEpochMilli(ms).atZone(zone)
            return when {
                at.toLocalDate() > day -> 24f
                at.toLocalDate() < day -> 0f
                else -> at.hour + at.minute / 60f
            }
        }

        private fun lanes(list: List<Event>) {
            var group = mutableListOf<Event>()
            var end = 0L
            fun close() = group.forEach { it.lanes = group.maxOf { g -> g.lane } + 1 }
            for (event in list.sortedBy { it.begin }) {
                if (event.begin >= end) {
                    close()
                    group = mutableListOf()
                }
                val taken = group.filter { it.end > event.begin }.map { it.lane }
                event.lane = generateSequence(0) { it + 1 }.first { it !in taken }
                group += event
                end = maxOf(end, event.end)
            }
            close()
        }

        private fun lines(event: Event): List<Pair<String, String>> {
            val span = "${DateFormat.format("HH:mm", event.begin)}\u2013${DateFormat.format("HH:mm", event.end)}"
            val lecture = LECTURE.find(event.title) ?: return listOf(event.title to "fg", event.place to "fgDim", span to "fgMuted")
            val (kind, code, room) = lecture.destructured
            val where = listOf(event.place.ifBlank { room }, event.note.lineSequence().first().trim()).filter(String::isNotBlank)
            return listOf("$code \u00b7 $kind" to "fg", where.joinToString(" \u00b7 ") to "fgDim", span to "fgMuted")
        }

        private fun block(canvas: Canvas, box: RectF, event: Event, text: List<Pair<String, String>>, now: Long) {
            val over = event.end <= now
            val tint = color(if (over) "fgMuted" else if (event.begin <= now) "success" else "accent")
            val fade = if (over) 0x99 else 0xff
            paint.color = tint and 0xffffff or (0x2e * fade / 0xff shl 24)
            canvas.drawRect(box, paint)
            paint.color = tint and 0xffffff or (fade shl 24)
            canvas.drawRect(box.left, box.top, box.left + dp(3), box.bottom, paint)
            canvas.save()
            canvas.clipRect(box)
            var y = box.top + dp(3)
            for ((i, line) in text.filter { it.first.isNotBlank() }.withIndex()) {
                paint.textSize = sp(if (i == 2) 9f else 10f)
                paint.isFakeBoldText = i == 0
                val height = paint.descent() - paint.ascent()
                if (i > 0 && y + height > box.bottom) break
                paint.color = color(line.second) and 0xffffff or (fade shl 24)
                val fit = TextUtils.ellipsize(line.first, paint, box.width() - dp(9), TextUtils.TruncateAt.END)
                canvas.drawText(fit.toString(), box.left + dp(6), y - paint.ascent(), paint)
                y += height
            }
            paint.isFakeBoldText = false
            canvas.restore()
            hits += box to event
        }

        override fun onDraw(canvas: Canvas) {
            hits.clear()
            val now = System.currentTimeMillis()
            val today = LocalDate.now()
            val gutter = dp(36).toFloat()
            val header = dp(24).toFloat()
            val stacked = (0 until count).maxOf { whole[it].size }
            val top = header + stacked * dp(18) + if (stacked > 0) dp(4) else 0
            val column = (width - gutter) / count
            val hour = (height - top - dp(8)) / (last - first)
            paint.typeface = face
            paint.textAlign = Paint.Align.LEFT
            paint.textSize = sp(10f)
            for (h in first..last) {
                val y = top + (h - first) * hour
                paint.color = fill("border", 0x99)
                canvas.drawRect(gutter, y, width.toFloat(), y + 1, paint)
                paint.color = color("fgMuted")
                canvas.drawText("%02d:00".format(h), 0f, y - (paint.ascent() + paint.descent()) / 2, paint)
            }
            for (i in 0 until count) {
                val day = monday.plusDays(i.toLong())
                val x = gutter + i * column
                val current = day == today
                if (current) {
                    paint.color = fill("accent", 0x0d)
                    canvas.drawRect(x, header, x + column, height.toFloat(), paint)
                }
                paint.textSize = sp(11f)
                paint.textAlign = Paint.Align.CENTER
                paint.isFakeBoldText = current
                paint.color = color(if (current) "accent" else "fgMuted")
                canvas.drawText(day.format(HEAD).lowercase(), x + column / 2, header / 2 - (paint.ascent() + paint.descent()) / 2, paint)
                paint.textAlign = Paint.Align.LEFT
                paint.isFakeBoldText = false
                whole[i].forEachIndexed { k, event ->
                    val y = header + k * dp(18)
                    block(canvas, RectF(x + dp(2), y, x + column - dp(2), y + dp(16)), event, listOf(event.title to "fg"), now)
                }
                for (event in timed[i]) {
                    val lane = (column - dp(4)) / event.lanes
                    val left = x + dp(2) + event.lane * lane
                    val y = top + (hours(event.begin, day) - first) * hour + dp(1)
                    val tall = maxOf(dp(18).toFloat(), (hours(event.end, day) - hours(event.begin, day)) * hour - dp(2))
                    val right = left + lane - if (event.lane < event.lanes - 1) dp(2) else 0
                    block(canvas, RectF(left, y, right, y + tall), event, lines(event), now)
                }
                val at = hours(now, day)
                if (current && at >= first && at <= last) {
                    val y = top + (at - first) * hour
                    paint.color = color("error")
                    canvas.drawRect(x, y, x + column, y + dp(2), paint)
                }
            }
        }
    }

    private lateinit var prefs: SharedPreferences
    private lateinit var state: SharedPreferences
    private lateinit var gestures: GestureDetector
    private lateinit var home: LinearLayout
    private lateinit var pins: FrameLayout
    private var carrying = false
    private var play = ">"
    private lateinit var sheet: FrameLayout
    private lateinit var options: LinearLayout
    private lateinit var calendar: LinearLayout
    private lateinit var planner: Week
    private lateinit var dates: TextView
    private lateinit var jump: TextView
    private var shift = 0
    private lateinit var weather: TextView
    private lateinit var agenda: TextView
    private lateinit var media: TextView
    private lateinit var toggle: TextView
    private lateinit var pc: TextView
    private lateinit var scheme: TextView
    private lateinit var wall: TextView
    private lateinit var walls: SharedPreferences
    private var picking = false
    private val thumbs = HashMap<String, Pair<Long, Bitmap?>>()
    private val shelved = SharedPreferences.OnSharedPreferenceChangeListener { _, _ ->
        wall.text = wallText()
        if (picking && sheet.visibility == View.VISIBLE) gallery()
    }
    private var switching: String? = null
    private var switchedAt = 0L
    private lateinit var drawer: LinearLayout
    private lateinit var grid: GridView
    private lateinit var query: EditText
    private lateinit var fetch: TextView
    private val handler = Handler(Looper.getMainLooper())
    private var apps = listOf<App>()
    private var shown = listOf<App>()
    private var colors = mapOf<String, Int>()
    private var name = ""
    private var face = Typeface.MONOSPACE

    private val tick = object : Runnable {
        override fun run() {
            refresh()
            handler.postDelayed(this, 60_000)
        }
    }

    private val cells = object : BaseAdapter() {
        override fun getCount() = shown.size

        override fun getItem(i: Int) = shown[i]

        override fun getItemId(i: Int) = i.toLong()

        override fun getView(i: Int, old: View?, parent: ViewGroup): View {
            val cell = old as? LinearLayout ?: LinearLayout(this@Home).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                addView(icon(), dp(44), dp(44))
                addView(
                    text(11f, "fgDim").apply {
                        gravity = Gravity.CENTER
                        maxLines = 2
                        ellipsize = TextUtils.TruncateAt.END
                        setPadding(0, dp(6), 0, 0)
                    },
                )
            }
            draw(cell.getChildAt(0) as ImageView, shown[i])
            (cell.getChildAt(1) as TextView).text = shown[i].label
            return cell
        }
    }

    override fun onCreate(saved: Bundle?) {
        super.onCreate(saved)
        prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        state = getSharedPreferences(STATE, MODE_PRIVATE)
        walls = getSharedPreferences(WALLS, MODE_PRIVATE)
        gestures = GestureDetector(
            this,
            object : GestureDetector.SimpleOnGestureListener() {
                override fun onFling(from: MotionEvent?, to: MotionEvent, velocityX: Float, velocityY: Float): Boolean {
                    if (calendar.visibility == View.VISIBLE && from != null && abs(to.x - from.x) > dp(80) && abs(velocityX) > abs(velocityY)) {
                        page(if (to.x < from.x) shift + 1 else shift - 1)
                        return true
                    }
                    val moved = to.y - (from ?: return false).y
                    if (abs(moved) < dp(80) || abs(velocityY) < abs(velocityX)) return false
                    if (carrying || sheet.visibility == View.VISIBLE || calendar.visibility == View.VISIBLE) return false
                    val open = drawer.visibility == View.VISIBLE
                    when {
                        moved < 0 && !open -> open()
                        moved > 0 && open && !grid.canScrollVertically(-1) -> reset()
                        moved > 0 && !open -> shade()
                        else -> return false
                    }
                    return true
                }
            },
        )
        window.setDecorFitsSystemWindows(false)
        onBackInvokedDispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT) {
            if (sheet.visibility == View.VISIBLE) sheet.visibility = View.GONE else reset()
        }
        prefs.registerOnSharedPreferenceChangeListener(this)
        walls.registerOnSharedPreferenceChangeListener(shelved)
        build()
    }

    override fun onStart() {
        super.onStart()
        Listener.changed = ::live
        handler.post(tick)
        reload()
        serve()
    }

    private fun reload() {
        Thread {
            val found = load()
            runOnUiThread {
                apps = found
                filter()
                pin()
                refresh()
            }
        }.start()
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        gestures.onTouchEvent(event)
        return super.dispatchTouchEvent(event)
    }

    override fun onRequestPermissionsResult(code: Int, permissions: Array<String>, results: IntArray) = refresh()

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        reset()
    }

    override fun onStop() {
        super.onStop()
        Listener.changed = null
        handler.removeCallbacks(tick)
        reset()
    }

    override fun onDestroy() {
        super.onDestroy()
        prefs.unregisterOnSharedPreferenceChangeListener(this)
        walls.unregisterOnSharedPreferenceChangeListener(shelved)
    }

    override fun onSharedPreferenceChanged(prefs: SharedPreferences?, key: String?) {
        build()
        reload()
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    private fun sp(value: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, value, resources.displayMetrics)

    private fun color(key: String) = colors.getValue(key)

    private fun fill(key: String, alpha: Int) = color(key) and 0xffffff or (alpha shl 24)

    private fun text(size: Float, key: String) = TextView(this).apply {
        textSize = size
        typeface = face
        setTextColor(color(key))
    }

    private fun clock(format: String, size: Float, key: String) = TextClock(this).apply {
        format12Hour = format
        format24Hour = format
        textSize = size
        typeface = face
        setTextColor(color(key))
    }

    private fun native(vararg options: String): String {
        val paint = Paint().apply {
            typeface = face
            textSize = 100f
        }
        return options.firstOrNull { paint.measureText(it) == paint.measureText("M") } ?: options.last()
    }

    private fun frame() = GradientDrawable().apply {
        setColor(fill("bgDim", 0xe0))
        setStroke(dp(2), color("border"))
    }

    private fun tile(vararg children: View) = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        background = frame()
        setPadding(dp(14), dp(12), dp(14), dp(12))
        children.forEach(::addView)
    }

    private fun block(size: Float, key: String) = text(size, key).apply { setHorizontallyScrolling(true) }

    private fun row(vararg children: View) = LinearLayout(this).apply {
        isBaselineAligned = false
        setPadding(0, 0, 0, dp(8))
        children.forEachIndexed { i, child ->
            addView(child, LinearLayout.LayoutParams(0, MATCH_PARENT, 1f).apply { marginStart = if (i == 0) 0 else dp(8) })
        }
    }

    private fun icon() = ImageView(this).apply {
        scaleType = ImageView.ScaleType.FIT_XY
        setPadding(dp(6), dp(6), dp(6), dp(6))
    }

    private fun render(layer: Drawable, inset: Int): IntArray {
        val full = Bitmap.createBitmap(GRID, GRID, Bitmap.Config.ARGB_8888)
        layer.setBounds(-inset, -inset, GRID + inset, GRID + inset)
        layer.draw(Canvas(full))
        return IntArray(GRID * GRID).also { full.getPixels(it, 0, GRID, 0, 0, GRID, GRID) }
    }

    private fun far(a: Int, b: Int) =
        abs(Color.red(a) - Color.red(b)) + abs(Color.green(a) - Color.green(b)) + abs(Color.blue(a) - Color.blue(b)) > 96

    private fun pixels(icon: Drawable): Bitmap {
        val adaptive = icon as? AdaptiveIconDrawable
        val layer = render(adaptive?.monochrome ?: adaptive?.foreground ?: icon, if (adaptive == null) 0 else GRID / 4)
        val whole = layer.count { Color.alpha(it) > 127 } < layer.size * 0.03
        val top = if (whole) render(icon, 0) else layer
        val solid = BooleanArray(top.size) { Color.alpha(top[it]) > 127 }
        var shape = solid
        if (whole || adaptive?.monochrome == null) {
            val under = adaptive?.background?.takeIf { !whole && solid.count { it } < top.size * 0.85 }?.let { render(it, GRID / 4) }
            val common = top.filterIndexed { i, _ -> solid[i] }.groupingBy { it and 0xf0f0f0 }.eachCount().maxByOrNull { it.value }?.key ?: 0
            val cut = BooleanArray(top.size) { solid[it] && far(top[it], under?.get(it) ?: common) }
            if (cut.count { it } > top.size * 0.03) shape = cut
        }
        return Bitmap.createBitmap(IntArray(top.size) { if (shape[it]) Color.WHITE else Color.TRANSPARENT }, GRID, GRID, Bitmap.Config.ARGB_8888)
    }

    private fun draw(box: ImageView, app: App) {
        box.background = frame()
        box.setImageDrawable(BitmapDrawable(resources, app.pixels).apply { isFilterBitmap = false })
        box.setColorFilter(color("accent"), PorterDuff.Mode.SRC_IN)
    }

    private fun build() {
        val theme = JSONObject(prefs.getString(PREFS, null) ?: "{}")
        colors = COLORS.associateWith {
            val fallback = if (it.startsWith("bg")) Color.BLACK else if (it == "border") Color.DKGRAY else Color.WHITE
            runCatching { Color.parseColor(theme.getString(it)) }.getOrDefault(fallback)
        }
        name = theme.optString("name")
        if (name == switching) switching = null
        face = runCatching { Typeface.createFromAsset(assets, "fonts/${theme.getString("font")}.ttf") }.getOrDefault(Typeface.MONOSPACE)
        play = native("\u25b6\ufe0e", "\u25ba", "\u25b7", ">")
        val back = native("\u25c0\ufe0e", "\u25c4", "\u25c1", "<")
        fetch = block(12f, "fg")
        weather = block(13f, "fg").apply { setPadding(0, dp(10), 0, 0) }
        agenda = block(13f, "fg")
        media = block(14f, "fg")
        pc = block(13f, "fg")
        scheme = block(13f, "fg")
        wall = block(13f, "fg")
        toggle = text(18f, "accent")
        val keys = LinearLayout(this).apply {
            gravity = Gravity.CENTER_VERTICAL
            for ((glyph, act) in listOf<Pair<String, (MediaController.TransportControls) -> Unit>>(
                back + back to { it.skipToPrevious() },
                "" to { if (player()?.playbackState?.state == PlaybackState.STATE_PLAYING) it.pause() else it.play() },
                play + play to { it.skipToNext() },
            )) {
                val key = if (glyph.isEmpty()) toggle else text(18f, "accent").apply { text = glyph }
                key.setPadding(dp(12), 0, dp(12), 0)
                key.setOnClickListener { player()?.transportControls?.let(act) }
                addView(key)
            }
        }
        val today = tile(clock("HH:mm", 44f, "fg"), clock("EEEE", 16f, "accent"), clock("d MMMM yyyy", 14f, "fgMuted"), weather)
        val playing = tile(
            LinearLayout(this).apply {
                gravity = Gravity.CENTER_VERTICAL
                addView(media, LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f))
                addView(keys)
            },
        ).apply { setOnClickListener { if (!granted()) startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)) } }
        pins = FrameLayout(this)
        val bar = tile(text(16f, "fgMuted").apply { text = "search apps" }).apply { setOnClickListener { open() } }
        home = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(row(today, tile(fetch)))
            addView(
                row(
                    tile(agenda).apply {
                        setOnClickListener {
                            if (checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED) {
                                week()
                            } else {
                                requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), 0)
                            }
                        }
                    },
                ),
            )
            addView(row(playing))
            addView(
                row(
                    tile(pc).apply { setOnClickListener { connect() } },
                    tile(scheme).apply { setOnClickListener { themes() } },
                    tile(wall).apply { setOnClickListener { wallpapers() } },
                ),
            )
            addView(pins, LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f))
            addView(bar)
        }

        query = EditText(this).apply {
            setBackgroundColor(color("bgAlt"))
            hint = "search apps"
            textSize = 16f
            typeface = face
            setTextColor(color("fg"))
            setHintTextColor(color("fgMuted"))
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
            imeOptions = EditorInfo.IME_ACTION_GO
            setPadding(dp(14), dp(12), dp(14), dp(12))
            setOnEditorActionListener { _, _, _ ->
                shown.firstOrNull()?.let(::launch)
                true
            }
            addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}

                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}

                override fun afterTextChanged(s: Editable?) = filter()
            })
        }
        grid = GridView(this).apply {
            adapter = cells
            numColumns = 4
            verticalSpacing = dp(16)
            selector = ColorDrawable(Color.TRANSPARENT)
            isVerticalScrollBarEnabled = false
            setPadding(0, dp(18), 0, 0)
            clipToPadding = false
            setOnItemClickListener { _, _, i, _ -> launch(shown[i]) }
            setOnItemLongClickListener { _, _, i, _ ->
                menu(shown[i])
                true
            }
        }
        drawer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.GONE
            isClickable = true
            setBackgroundColor(fill("bgDim", 0xf0))
            addView(query, MATCH_PARENT, WRAP_CONTENT)
            addView(grid, LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f))
        }

        options = tile().apply { isClickable = true }
        sheet = FrameLayout(this).apply {
            visibility = View.GONE
            setBackgroundColor(fill("bgDim", 0x99))
            setOnClickListener { visibility = View.GONE }
            addView(options, FrameLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT, Gravity.BOTTOM))
        }
        planner = Week()
        dates = text(12f, "fgMuted").apply {
            background = GradientDrawable().apply { setColor(fill("fgMuted", 0x24)) }
            setPadding(dp(8), dp(2), dp(8), dp(2))
        }
        jump = text(13f, "accent").apply { text = "today" }
        val head = LinearLayout(this).apply {
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, dp(10))
            addView(text(22f, "accent").apply { text = "week" })
            addView(dates, LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply { marginStart = dp(10) })
            addView(View(this@Home), LinearLayout.LayoutParams(0, 0, 1f))
            for ((key, target) in listOf<Pair<TextView, () -> Int>>(
                text(18f, "accent").apply { text = back } to { shift - 1 },
                jump to { 0 },
                text(18f, "accent").apply { text = play } to { shift + 1 },
            )) {
                key.setPadding(dp(10), dp(4), dp(10), dp(4))
                key.setOnClickListener { page(target()) }
                addView(key)
            }
        }
        calendar = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.GONE
            isClickable = true
            setBackgroundColor(fill("bgDim", 0xf0))
            addView(head)
            addView(planner, LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f))
        }

        setContentView(
            FrameLayout(this).apply {
                addView(home)
                addView(drawer)
                addView(calendar)
                addView(sheet)
                setOnApplyWindowInsetsListener { _, insets ->
                    val inset = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.ime())
                    for (view in listOf(home, drawer, calendar, sheet)) {
                        view.setPadding(inset.left + dp(12), inset.top + dp(12), inset.right + dp(12), inset.bottom + dp(12))
                    }
                    insets
                }
            },
        )
        val light = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
        window.insetsController?.setSystemBarsAppearance(if (Color.luminance(color("bgDim")) > 0.5f) light else 0, light)
        pin()
        refresh()
    }

    private fun refresh() {
        fetch.text = fetchText()
        agenda.text = agendaText()
        weather.text = weatherText()
        val pending = switching?.takeIf { System.currentTimeMillis() - switchedAt < 90_000 }
        scheme.text = span("theme\n" to "accent", (pending?.let { "$it..." } ?: name) to (if (pending == null) "fg" else "fgMuted"))
        wall.text = wallText()
        if (calendar.visibility == View.VISIBLE) planner.invalidate()
        live()
        Thread {
            val route = when {
                tether().isNotEmpty() -> "usb tether"
                online() -> "tailnet"
                else -> null
            }
            runOnUiThread { pc.text = span("pc\n" to "accent", (route ?: "no network") to (if (route == null) "fgMuted" else "fg")) }
        }.start()
        if (System.currentTimeMillis() - state.getLong("weatherAt", 0) > 1_800_000) {
            Thread {
                val body = runCatching { URL(FORECAST).readText() }.getOrNull() ?: return@Thread
                state.edit().putString("weather", body).putLong("weatherAt", System.currentTimeMillis()).apply()
                runOnUiThread { weather.text = weatherText() }
            }.start()
        }
    }

    private fun span(vararg parts: Pair<String, String>): CharSequence {
        val out = SpannableStringBuilder()
        for ((value, key) in parts) out.append(value, ForegroundColorSpan(color(key)), 0)
        return out
    }

    private fun granted() =
        Settings.Secure.getString(contentResolver, "enabled_notification_listeners").orEmpty().contains(packageName)

    private fun player(): MediaController? =
        runCatching {
            getSystemService(MediaSessionManager::class.java).getActiveSessions(ComponentName(this, Listener::class.java)).firstOrNull()
        }.getOrNull()

    private fun live() {
        if (!granted()) {
            media.text = span("tap to allow notification access" to "fgMuted")
            return
        }
        val player = player()
        val track = player?.metadata
        media.text = span(
            (track?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: "nothing playing") + "\n" to "fg",
            (track?.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: "") to "fgMuted",
        )
        toggle.text = if (player?.playbackState?.state == PlaybackState.STATE_PLAYING) PAUSE else play
    }

    private fun agendaText(): CharSequence {
        if (checkSelfPermission(Manifest.permission.READ_CALENDAR) != PackageManager.PERMISSION_GRANTED) {
            return span("agenda\n" to "accent", "tap to allow calendar access" to "fgMuted")
        }
        val now = System.currentTimeMillis()
        val week = CalendarContract.Instances.CONTENT_URI.buildUpon()
        ContentUris.appendId(week, now)
        ContentUris.appendId(week, now + 7 * 86_400_000L)
        val columns = arrayOf(CalendarContract.Instances.BEGIN, CalendarContract.Instances.TITLE)
        val out = SpannableStringBuilder()
        var lines = 0
        contentResolver.query(week.build(), columns, null, null, CalendarContract.Instances.BEGIN + " ASC")?.use {
            while (lines < 4 && it.moveToNext()) {
                if (lines++ > 0) out.append("\n")
                out.append(span(DateFormat.format("EEE HH:mm ", it.getLong(0)).toString() to "accent", it.getString(1).orEmpty() to "fg"))
            }
        }
        return if (lines == 0) span("agenda\n" to "accent", "nothing this week" to "fgMuted") else out
    }

    private fun weatherText(): CharSequence {
        val waiting = span("weather\n" to "accent", PLACE to "fgMuted")
        return runCatching {
            val data = JSONObject(state.getString("weather", null) ?: return waiting)
            val now = data.getJSONObject("current")
            val days = data.getJSONObject("daily")
            val sky = when (now.getInt("weather_code")) {
                0 -> "clear"
                1 -> "mostly clear"
                2 -> "partly cloudy"
                3 -> "overcast"
                45, 48 -> "fog"
                in 51..57 -> "drizzle"
                in 61..67 -> "rain"
                in 71..77, 85, 86 -> "snow"
                in 80..82 -> "showers"
                else -> "storm"
            }
            val out = SpannableStringBuilder(
                span(
                    "${now.getDouble("temperature_2m").toInt()}\u00b0 " to "fg",
                    "$sky\n" to "accent",
                    "feels ${now.getDouble("apparent_temperature").toInt()}\u00b0 \u00b7 $PLACE" to "fgMuted",
                ),
            )
            for (i in 1 until days.getJSONArray("time").length()) {
                val day = LocalDate.parse(days.getJSONArray("time").getString(i)).dayOfWeek.getDisplayName(TextStyle.SHORT, Locale.getDefault()).lowercase()
                val high = days.getJSONArray("temperature_2m_max").getDouble(i).toInt()
                val low = days.getJSONArray("temperature_2m_min").getDouble(i).toInt()
                out.append(span("\n$day " to "accent", "$high\u00b0 $low\u00b0" to "fgDim"))
            }
            out
        }.getOrDefault(waiting)
    }

    private fun pinned(): List<String> {
        val saved = JSONArray(state.getString("pins", "[]"))
        return List(saved.length(), saved::getString)
    }

    private fun across() = maxOf(1, (resources.displayMetrics.widthPixels - dp(16)) / dp(52))

    private fun pin() {
        val kept = pinned().mapNotNull { id -> apps.firstOrNull { it.id == id } }
        val spots = JSONObject(state.getString("spots", "{}"))
        val taken = kept.map { spots.optString(it.id) }.filter(String::isNotEmpty).toMutableSet()
        pins.removeAllViews()
        for (app in kept) {
            if (spots.optString(app.id).isEmpty()) {
                val free = generateSequence(0) { it + 1 }.map { "${it % across()},${it / across()}" }.first { it !in taken }
                taken += free
                spots.put(app.id, free)
            }
            val (column, line) = spots.getString(app.id).split(',').map(String::toInt)
            val box = icon()
            draw(box, app)
            carry(box, app, column, line)
            pins.addView(
                box,
                FrameLayout.LayoutParams(dp(44), dp(44), Gravity.BOTTOM or Gravity.START).apply {
                    leftMargin = column * dp(52)
                    bottomMargin = line * dp(52) + dp(8)
                },
            )
        }
        state.edit().putString("spots", spots.toString()).apply()
    }

    private fun carry(box: View, app: App, column: Int, line: Int) {
        var fromX = 0f
        var fromY = 0f
        var far = false
        val lift = Runnable {
            carrying = true
            box.alpha = 0.6f
            box.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
        }
        box.setOnTouchListener { view, event ->
            val dx = event.rawX - fromX
            val dy = event.rawY - fromY
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    fromX = event.rawX
                    fromY = event.rawY
                    far = false
                    handler.postDelayed(lift, 350)
                }
                MotionEvent.ACTION_MOVE -> {
                    if (abs(dx) + abs(dy) > dp(12)) {
                        far = true
                        if (!carrying) handler.removeCallbacks(lift)
                    }
                    if (carrying) {
                        view.translationX = dx
                        view.translationY = dy
                    }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    val held = carrying
                    handler.removeCallbacks(lift)
                    carrying = false
                    view.alpha = 1f
                    view.translationX = 0f
                    view.translationY = 0f
                    when {
                        held && far -> move(app, column + Math.round(dx / dp(52)), line - Math.round(dy / dp(52)))
                        held -> menu(app)
                        !far && event.actionMasked == MotionEvent.ACTION_UP -> launch(app)
                    }
                }
            }
            true
        }
    }

    private fun move(app: App, column: Int, line: Int) {
        val spots = JSONObject(state.getString("spots", "{}"))
        val spot = "${column.coerceIn(0, across() - 1)},${line.coerceIn(0, maxOf(0, pins.height / dp(52) - 1))}"
        val other = pinned().firstOrNull { it != app.id && spots.optString(it) == spot }
        if (other != null) spots.put(other, spots.getString(app.id))
        spots.put(app.id, spot)
        state.edit().putString("spots", spots.toString()).apply()
        pin()
    }

    private fun menu(app: App) {
        val pinned = pinned()
        val target = Uri.fromParts("package", app.component.packageName, null)
        val items = listOf<Pair<String, () -> Unit>>(
            (if (app.id in pinned) "unpin" else "pin") to {
                val spots = JSONObject(state.getString("spots", "{}")).apply { remove(app.id) }
                state.edit()
                    .putString("pins", JSONArray(if (app.id in pinned) pinned - app.id else pinned + app.id).toString())
                    .putString("spots", spots.toString())
                    .apply()
                pin()
            },
            "app info" to { startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, target)) },
            "uninstall" to { startActivity(Intent(Intent.ACTION_DELETE, target)) },
        )
        picking = false
        options.removeAllViews()
        options.addView(text(14f, "accent").apply { text = app.label })
        for ((label, act) in items) {
            options.addView(
                text(17f, "fg").apply {
                    text = label
                    setPadding(0, dp(14), 0, dp(14))
                    setOnClickListener {
                        sheet.visibility = View.GONE
                        act()
                    }
                },
                MATCH_PARENT,
                WRAP_CONTENT,
            )
        }
        sheet.visibility = View.VISIBLE
    }

    private fun week() {
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
        page(0)
        home.visibility = View.INVISIBLE
        calendar.visibility = View.VISIBLE
    }

    private fun page(target: Int) {
        shift = target
        val zone = ZoneId.systemDefault()
        val monday = LocalDate.now().with(DayOfWeek.MONDAY).plusWeeks(shift.toLong())
        val range = CalendarContract.Instances.CONTENT_URI.buildUpon()
        ContentUris.appendId(range, monday.minusDays(1).atStartOfDay(zone).toInstant().toEpochMilli())
        ContentUris.appendId(range, monday.plusDays(8).atStartOfDay(zone).toInstant().toEpochMilli())
        val columns = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.EVENT_LOCATION,
            CalendarContract.Instances.DESCRIPTION,
            CalendarContract.Instances.ALL_DAY,
        )
        val found = mutableListOf<Event>()
        contentResolver.query(range.build(), columns, null, null, CalendarContract.Instances.BEGIN + " ASC")?.use {
            while (it.moveToNext()) {
                found += Event(it.getLong(0), it.getLong(1), it.getLong(2), it.getString(3).orEmpty(), it.getString(4).orEmpty(), it.getString(5).orEmpty(), it.getInt(6) == 1)
            }
        }
        planner.show(monday, found)
        dates.text = "${monday.format(SHORT)} - ${monday.plusDays(planner.count - 1L).format(SHORT)}".lowercase()
        jump.setTextColor(color(if (shift == 0) "accent" else "fgDim"))
    }

    private fun visit(event: Event) {
        startActivity(
            Intent(Intent.ACTION_VIEW, ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, event.id))
                .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, event.begin)
                .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, event.end),
        )
    }

    private fun themes() {
        val list = JSONArray(assets.open("themes.json").bufferedReader().use { it.readText() })
        val rows = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        for (i in 0 until list.length()) {
            val theme = list.getJSONObject(i)
            val id = theme.getString("name")
            fun of(key: String) = Color.parseColor(theme.getString(key))
            val swatches = SpannableStringBuilder()
            for (key in listOf("accent") + SWATCHES) swatches.append(" \u25a0", ForegroundColorSpan(of(key)), 0)
            rows.addView(
                text(14f, "fg").apply {
                    text = SpannableStringBuilder(id.padEnd(14)).append(swatches)
                    setTextColor(of("fg"))
                    background = GradientDrawable().apply {
                        setColor(of("bgDim"))
                        setStroke(dp(2), of(if (id == name) "accent" else "border"))
                    }
                    setPadding(dp(12), dp(10), dp(12), dp(10))
                    setOnClickListener {
                        sheet.visibility = View.GONE
                        switch(id)
                    }
                },
                LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { topMargin = dp(8) },
            )
        }
        picking = false
        options.removeAllViews()
        options.addView(text(14f, "accent").apply { text = "theme" })
        options.addView(ScrollView(this).apply { addView(rows) }, MATCH_PARENT, WRAP_CONTENT)
        sheet.visibility = View.VISIBLE
    }

    private fun wallText(): CharSequence {
        val current = walls.getString("current", "").orEmpty().removePrefix("plates+").substringBeforeLast('.')
        return span("wallpaper\n" to "accent", current.ifEmpty { "pick" } to (if (current.isEmpty()) "fgMuted" else "fg"))
    }

    private fun wallpapers() {
        val have = File(filesDir, WALLS).list().orEmpty().filter(ID::matches)
        walls.edit().putString("status", "syncing").apply()
        val script = assets.open("pc").bufferedReader().use { it.readText() }
        val run = Intent("com.termux.RUN_COMMAND")
            .setClassName(TERMUX, "$TERMUX.app.RunCommandService")
            .putExtra("$TERMUX.RUN_COMMAND_PATH", "/data/data/$TERMUX/files/usr/bin/bash")
            .putExtra("$TERMUX.RUN_COMMAND_ARGUMENTS", arrayOf("-c", script, "pc", tether(), "walls") + have)
            .putExtra("$TERMUX.RUN_COMMAND_BACKGROUND", true)
        runCatching { startForegroundService(run) }
        picking = true
        gallery()
        sheet.visibility = View.VISIBLE
    }

    private fun gallery() {
        val saved = JSONArray(walls.getString("list", "[]"))
        val ids = List(saved.length(), saved::getString)
        val current = walls.getString("current", "")
        val status = walls.getString("status", "").orEmpty()
        val dir = File(filesDir, WALLS)
        val scrolled = (options.getChildAt(1) as? ScrollView)?.scrollY ?: 0
        val width = (resources.displayMetrics.widthPixels - dp(68)) / 3
        val rows = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        for (line in ids.chunked(3)) {
            rows.addView(
                LinearLayout(this).apply {
                    for (id in line) {
                        addView(
                            ImageView(this@Home).apply {
                                scaleType = ImageView.ScaleType.CENTER_CROP
                                background = GradientDrawable().apply {
                                    setColor(color("bgAlt"))
                                    setStroke(dp(2), color(if (id == current) "accent" else "border"))
                                }
                                setPadding(dp(2), dp(2), dp(2), dp(2))
                                val file = File(dir, id)
                                val cached = thumbs[id]?.takeIf { it.first == file.lastModified() }
                                setImageBitmap(cached?.second ?: BitmapFactory.decodeFile(file.path).also { thumbs[id] = file.lastModified() to it })
                                setOnClickListener { pick(id) }
                            },
                            LinearLayout.LayoutParams(width, width * 13 / 6).apply { marginEnd = dp(8) },
                        )
                    }
                },
                LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { topMargin = dp(8) },
            )
        }
        options.removeAllViews()
        options.addView(
            span("wallpaper" to "accent", (if (status.isEmpty()) "" else "  $status") to "fgMuted").let { title ->
                text(14f, "accent").apply { text = title }
            },
        )
        options.addView(ScrollView(this).apply { addView(rows) }, MATCH_PARENT, WRAP_CONTENT)
        if (ids.isEmpty() && status.isEmpty()) options.addView(text(14f, "fgMuted").apply { text = "no wallpapers" })
        options.getChildAt(1).post { options.getChildAt(1)?.scrollTo(0, scrolled) }
    }

    private fun pick(id: String) {
        val script = assets.open("pc").bufferedReader().use { it.readText() }
        val run = Intent("com.termux.RUN_COMMAND")
            .setClassName(TERMUX, "$TERMUX.app.RunCommandService")
            .putExtra("$TERMUX.RUN_COMMAND_PATH", "/data/data/$TERMUX/files/usr/bin/bash")
            .putExtra("$TERMUX.RUN_COMMAND_ARGUMENTS", arrayOf("-c", script, "pc", tether(), "wall", id))
            .putExtra("$TERMUX.RUN_COMMAND_BACKGROUND", true)
        runCatching { startForegroundService(run) }
        picking = false
        sheet.visibility = View.GONE
        walls.edit().putString("current", id).apply()
    }

    private fun switch(theme: String) {
        if (theme == name) return
        val script = assets.open("pc").bufferedReader().use { it.readText() }
        val run = Intent("com.termux.RUN_COMMAND")
            .setClassName(TERMUX, "$TERMUX.app.RunCommandService")
            .putExtra("$TERMUX.RUN_COMMAND_PATH", "/data/data/$TERMUX/files/usr/bin/bash")
            .putExtra("$TERMUX.RUN_COMMAND_ARGUMENTS", arrayOf("-c", script, "pc", tether(), "theme", theme))
            .putExtra("$TERMUX.RUN_COMMAND_BACKGROUND", true)
        runCatching { startForegroundService(run) }
        switching = theme
        switchedAt = System.currentTimeMillis()
        refresh()
    }

    private fun tether(): String =
        runCatching {
            NetworkInterface.getNetworkInterfaces().asSequence()
                .filter { it.isUp && Regex("rndis|usb|ncm").containsMatchIn(it.name) }
                .flatMap { it.inetAddresses.asSequence() }
                .firstOrNull { it is Inet4Address }
                ?.hostAddress
        }.getOrNull().orEmpty()

    private fun online() =
        getSystemService(ConnectivityManager::class.java).run { getNetworkCapabilities(activeNetwork) }
            ?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true

    private fun connect() {
        val script = assets.open("pc").bufferedReader().use { it.readText() }
        val run = Intent("com.termux.RUN_COMMAND")
            .setClassName(TERMUX, "$TERMUX.app.RunCommandService")
            .putExtra("$TERMUX.RUN_COMMAND_PATH", "/data/data/$TERMUX/files/usr/bin/bash")
            .putExtra("$TERMUX.RUN_COMMAND_ARGUMENTS", arrayOf("-c", script, "pc", tether()))
            .putExtra("$TERMUX.RUN_COMMAND_BACKGROUND", false)
            .putExtra("$TERMUX.RUN_COMMAND_SESSION_ACTION", "0")
        runCatching { startForegroundService(run) }
        packageManager.getLaunchIntentForPackage(TERMUX)?.let(::startActivity)
    }

    private fun serve() {
        val script = assets.open("serve").bufferedReader().use { it.readText() }
        for (daemon in listOf("sshd", "tailscaled")) {
            val run = Intent("com.termux.RUN_COMMAND")
                .setClassName(TERMUX, "$TERMUX.app.RunCommandService")
                .putExtra("$TERMUX.RUN_COMMAND_PATH", "/data/data/$TERMUX/files/usr/bin/bash")
                .putExtra("$TERMUX.RUN_COMMAND_ARGUMENTS", arrayOf("-c", script, "serve", daemon))
                .putExtra("$TERMUX.RUN_COMMAND_BACKGROUND", true)
            runCatching { startForegroundService(run) }
        }
    }

    private fun open() {
        home.visibility = View.INVISIBLE
        drawer.visibility = View.VISIBLE
        query.requestFocus()
        query.post { getSystemService(InputMethodManager::class.java).showSoftInput(query, 0) }
    }

    private fun shade() {
        runCatching { Class.forName("android.app.StatusBarManager").getMethod("expandNotificationsPanel").invoke(getSystemService("statusbar")) }
    }

    private fun fetchText(): CharSequence {
        val memory = ActivityManager.MemoryInfo().also { getSystemService(ActivityManager::class.java).getMemoryInfo(it) }
        val disk = StatFs(Environment.getDataDirectory().path)
        val battery = getSystemService(BatteryManager::class.java)
        val up = SystemClock.elapsedRealtime() / 60_000
        val rows = listOf(
            "os" to "Android ${Build.VERSION.RELEASE}",
            "host" to Build.MODEL,
            "kernel" to System.getProperty("os.version").orEmpty().substringBefore('-'),
            "uptime" to "${up / 1440}d ${up / 60 % 24}h ${up % 60}m",
            "apps" to apps.size.toString(),
            "theme" to name,
            "memory" to "%.1f/%.0fG".format((memory.totalMem - memory.availMem) / GB, memory.totalMem / GB),
            "disk" to "%.0f/%.0fG".format((disk.totalBytes - disk.availableBytes) / GB, disk.totalBytes / GB),
            "battery" to "${battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)}%" + if (battery.isCharging) " +" else "",
        )
        val out = SpannableStringBuilder()
        for (key in SWATCHES) out.append("■ ", ForegroundColorSpan(color(key)), 0)
        for ((key, value) in rows) {
            out.append("\n" + key.padEnd(8), ForegroundColorSpan(color("accent")), 0)
            out.append(value)
        }
        return out
    }

    private fun load(): List<App> =
        packageManager
            .queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
            .map {
                val label = it.loadLabel(packageManager).toString()
                val info = it.activityInfo
                App(label, ComponentName(info.packageName, info.name), pixels(it.loadIcon(packageManager)))
            }
            .sortedBy { it.label.lowercase() }

    private fun launch(app: App) {
        val usage = JSONObject(state.getString("usage", "{}"))
        state.edit().putString("usage", usage.put(app.id, usage.optInt(app.id) + 1).toString()).apply()
        startActivity(
            Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER)
                .setComponent(app.component)
                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED),
        )
    }

    private fun filter() {
        val text = query.text.toString().trim()
        val usage = JSONObject(state.getString("usage", "{}"))
        shown = apps.filter { it.label.contains(text, true) }
            .sortedWith(compareBy<App> { text.isNotEmpty() && !it.label.startsWith(text, true) }.thenByDescending { usage.optInt(it.id) })
        cells.notifyDataSetChanged()
    }

    private fun reset() {
        query.text.clear()
        query.clearFocus()
        grid.setSelection(0)
        home.visibility = View.VISIBLE
        drawer.visibility = View.GONE
        calendar.visibility = View.GONE
        sheet.visibility = View.GONE
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        getSystemService(InputMethodManager::class.java).hideSoftInputFromWindow(query.windowToken, 0)
    }
}
