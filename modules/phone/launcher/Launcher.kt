package dev.neru.bare

import android.Manifest
import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.animation.StateListAnimator
import android.animation.ValueAnimator
import android.app.Activity
import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Insets
import android.graphics.PorterDuff
import android.graphics.Typeface
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.BatteryManager
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.os.SystemClock
import android.provider.AlarmClock
import android.provider.Settings
import android.text.Editable
import android.text.InputType
import android.text.SpannableStringBuilder
import android.text.TextUtils
import android.text.TextWatcher
import android.text.format.DateFormat
import android.text.style.ForegroundColorSpan
import android.util.Base64
import android.util.TypedValue
import android.view.GestureDetector
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.animation.DecelerateInterpolator
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
import android.window.BackEvent
import android.window.OnBackAnimationCallback
import android.window.OnBackInvokedDispatcher
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.Inet4Address
import java.net.NetworkInterface
import java.net.URL
import java.time.LocalDate
import kotlin.math.abs
import kotlin.math.roundToInt

const val PREFS = "theme"
private const val STATE = "state"
private const val GRID = 48
const val TERMUX = "com.termux"
const val PLACE = "porto"
private const val FORECAST =
    "https://api.open-meteo.com/v1/forecast?latitude=41.15&longitude=-8.61&timezone=auto&forecast_days=7&forecast_hours=24" +
        "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day" +
        "&hourly=temperature_2m,weather_code,precipitation_probability,is_day" +
        "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
const val GB = 1073741824.0
val SWATCHES = listOf("red", "green", "yellow", "blue", "magenta", "cyan")
private val COLORS = listOf("bgDim", "bgAlt", "border", "fg", "fgDim", "fgMuted", "accent", "error", "success") + SWATCHES
private val HEX = Regex("#[0-9a-fA-F]{6}")
const val WALLS = "walls"
private val ID = Regex("[A-Za-z0-9._+-]+")

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

class Screen(val key: String, val view: View, val update: () -> Unit = {}, val swipe: ((Int) -> Unit)? = null, val beat: () -> Unit = {})

class Home : Activity(), SharedPreferences.OnSharedPreferenceChangeListener {
    private class App(val label: String, val component: ComponentName, val pixels: Bitmap) {
        val id: String = component.flattenToString()
    }

    class Stats(val memory: Long, val memoryTotal: Long, val disk: Long, val diskTotal: Long, val battery: Int, val charging: Boolean)

    private lateinit var prefs: SharedPreferences
    private lateinit var state: SharedPreferences
    lateinit var walls: SharedPreferences
    private lateinit var gestures: GestureDetector
    private lateinit var root: FrameLayout
    private lateinit var home: LinearLayout
    private lateinit var pins: FrameLayout
    private var carrying = false
    private lateinit var sheet: FrameLayout
    private lateinit var options: LinearLayout
    private lateinit var drawer: LinearLayout
    private lateinit var grid: GridView
    private lateinit var query: EditText
    private lateinit var sky: ImageView
    private lateinit var degrees: TextView
    private lateinit var spread: TextView
    private lateinit var power: ImageView
    private lateinit var meters: List<Pair<FrameLayout, TextView>>
    private lateinit var agenda: LinearLayout
    private lateinit var cover: ImageView
    private lateinit var note: ImageView
    private lateinit var track: TextView
    private lateinit var artist: TextView
    private lateinit var toggle: ImageView
    private lateinit var keys: List<ImageView>
    private lateinit var progress: FrameLayout
    private lateinit var terminal: ImageView
    private lateinit var link: FrameLayout
    private lateinit var way: TextView
    private lateinit var preview: ImageView
    private lateinit var picture: ImageView
    private lateinit var scheme: TextView
    private lateinit var chips: LinearLayout
    val stack = mutableListOf<Screen>()
    private var bars = Insets.NONE
    var controller: MediaController? = null
        private set
    var day: LocalDate = LocalDate.now()
    var shift = 0
    var tab = 0
    var fetching = false
        private set
    private var switching: String? = null
    private var switchedAt = 0L
    private val thumbs = HashMap<String, Pair<Long, Bitmap?>>()
    private val fonts = HashMap<String, Typeface>()
    private val shelved = SharedPreferences.OnSharedPreferenceChangeListener { _, _ ->
        wallTile()
        stack.lastOrNull()?.takeIf { it.key == "appearance" }?.update?.invoke()
    }
    private val handler = Handler(Looper.getMainLooper())
    private val ease = DecelerateInterpolator(2f)
    private var apps = listOf<App>()
    private var shown = listOf<App>()
    private var colors = mapOf<String, Int>()
    var name = ""
        private set
    var face: Typeface = Typeface.MONOSPACE
        private set
    private val symbols by lazy { Typeface.createFromAsset(assets, "icons.ttf") }

    private val minute = object : Runnable {
        override fun run() {
            refresh()
            handler.postDelayed(this, 60_000)
        }
    }

    private val second = object : Runnable {
        override fun run() {
            beat()
            if (playing()) handler.postDelayed(this, 1000)
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
                stateListAnimator = bounce(0.9f)
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
                    if (from == null || carrying || sheet.visibility == View.VISIBLE) return false
                    val dx = to.x - from.x
                    val dy = to.y - from.y
                    val top = stack.lastOrNull()
                    if (top != null) {
                        val swipe = top.swipe ?: return false
                        if (abs(dx) < dp(80) || abs(velocityX) < abs(velocityY)) return false
                        swipe(if (dx < 0) 1 else -1)
                        return true
                    }
                    if (abs(dy) < dp(80) || abs(velocityY) < abs(velocityX)) return false
                    val open = drawer.visibility == View.VISIBLE
                    when {
                        dy < 0 && !open -> open()
                        dy > 0 && open && !grid.canScrollVertically(-1) -> close()
                        dy > 0 && !open -> shade()
                        else -> return false
                    }
                    return true
                }
            },
        )
        window.setDecorFitsSystemWindows(false)
        onBackInvokedDispatcher.registerOnBackInvokedCallback(
            OnBackInvokedDispatcher.PRIORITY_DEFAULT,
            object : OnBackAnimationCallback {
                override fun onBackProgressed(event: BackEvent) = lean(event.progress)

                override fun onBackCancelled() = lean(0f, true)

                override fun onBackInvoked() = back()
            },
        )
        prefs.registerOnSharedPreferenceChangeListener(this)
        walls.registerOnSharedPreferenceChangeListener(shelved)
        build()
    }

    override fun onStart() {
        super.onStart()
        Listener.changed = ::live
        handler.post(minute)
        reload()
        serve()
        if (stack.isEmpty()) rise(home)
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

    override fun onRequestPermissionsResult(code: Int, permissions: Array<String>, results: IntArray) {
        refresh()
        if (code == 1 && results.firstOrNull() == PackageManager.PERMISSION_GRANTED) go("agenda")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        land()
    }

    override fun onStop() {
        super.onStop()
        Listener.changed = null
        handler.removeCallbacks(minute)
        handler.removeCallbacks(second)
        close(false)
        hide(false)
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

    fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    fun sp(value: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, value, resources.displayMetrics)

    fun color(key: String) = colors.getValue(key)

    fun fill(key: String, alpha: Int) = color(key) and 0xffffff or (alpha shl 24)

    fun font(family: String): Typeface =
        fonts.getOrPut(family) { runCatching { Typeface.createFromAsset(assets, "fonts/$family.ttf") }.getOrDefault(Typeface.MONOSPACE) }

    fun text(size: Float, key: String, value: CharSequence = "") = TextView(this).apply {
        textSize = size
        typeface = face
        setTextColor(color(key))
        text = value
    }

    fun line(size: Float, key: String, value: CharSequence = "") = text(size, key, value).apply {
        maxLines = 1
        ellipsize = TextUtils.TruncateAt.END
    }

    private fun clock(format: String, size: Float, key: String) = TextClock(this).apply {
        format12Hour = format
        format24Hour = format
        textSize = size
        typeface = face
        setTextColor(color(key))
    }

    fun span(vararg parts: Pair<String, String>): CharSequence {
        val out = SpannableStringBuilder()
        for ((value, key) in parts) out.append(value, ForegroundColorSpan(color(key)), 0)
        return out
    }

    fun frame() = GradientDrawable().apply {
        setColor(fill("bgDim", 0xe0))
        setStroke(dp(2), color("border"))
    }

    fun tile(vararg children: View) = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        background = frame()
        setPadding(dp(14), dp(12), dp(14), dp(12))
        children.forEach(::addView)
    }

    private fun quick(badge: View, title: View, detail: View) =
        tile(strip(badge, column(title, detail).apply { layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f).apply { marginStart = dp(12) } }))

    fun row(vararg children: Pair<View, Float>) = LinearLayout(this).apply {
        isBaselineAligned = false
        setPadding(0, 0, 0, dp(8))
        children.forEachIndexed { i, (child, weight) ->
            addView(child, LinearLayout.LayoutParams(0, MATCH_PARENT, weight).apply { marginStart = if (i == 0) 0 else dp(8) })
        }
    }

    fun strip(vararg children: View) = LinearLayout(this).apply {
        gravity = Gravity.CENTER_VERTICAL
        children.forEach(::addView)
    }

    fun column(vararg children: View) = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        children.forEach(::addView)
    }

    fun space() = View(this).apply { layoutParams = LinearLayout.LayoutParams(0, 0, 1f) }

    fun scroll(content: View) = ScrollView(this).apply {
        isVerticalScrollBarEnabled = false
        addView(content)
    }

    private fun View.params() =
        layoutParams as? LinearLayout.LayoutParams ?: LinearLayout.LayoutParams(layoutParams ?: ViewGroup.LayoutParams(WRAP_CONTENT, WRAP_CONTENT))

    fun <T : View> T.after(space: Int): T = apply { layoutParams = params().apply { marginStart = dp(space) } }

    fun <T : View> T.below(space: Int): T = apply { layoutParams = params().apply { topMargin = dp(space) } }

    fun FrameLayout.put(view: View, where: Int = Gravity.CENTER) =
        addView(view, FrameLayout.LayoutParams(view.layoutParams ?: ViewGroup.LayoutParams(WRAP_CONTENT, WRAP_CONTENT)).apply { gravity = where })

    fun glyph(name: String, key: String, size: Int = 20) = glyph(name, color(key), size)

    fun glyph(name: String, tint: Int, size: Int = 20) = ImageView(this).apply {
        layoutParams = LinearLayout.LayoutParams(dp(size), dp(size))
        scaleType = ImageView.ScaleType.FIT_XY
        mark(this, name, tint)
    }

    fun mark(view: ImageView, name: String, key: String) = mark(view, name, color(key))

    fun mark(view: ImageView, name: String, tint: Int): Boolean {
        view.setColorFilter(tint, PorterDuff.Mode.SRC_IN)
        if (view.contentDescription == name) return false
        view.contentDescription = name
        view.setImageDrawable(Glyph(name, symbols))
        return true
    }

    fun glide(view: View, time: Long = 260) = view.animate().setStartDelay(0).setDuration(time).setInterpolator(ease)

    private fun scale(to: Float, time: Long) = AnimatorSet().apply {
        playTogether(ObjectAnimator.ofFloat(null, View.SCALE_X, to), ObjectAnimator.ofFloat(null, View.SCALE_Y, to))
        duration = time
        interpolator = ease
    }

    fun bounce(amount: Float) = StateListAnimator().apply {
        addState(intArrayOf(android.R.attr.state_pressed), scale(amount, 90))
        addState(intArrayOf(), scale(1f, 200))
    }

    fun <T : View> press(view: T, amount: Float = 0.96f, act: () -> Unit): T = view.apply {
        stateListAnimator = bounce(amount)
        setOnClickListener {
            it.performHapticFeedback(HapticFeedbackConstants.CONTEXT_CLICK)
            act()
        }
    }

    fun button(view: View, act: () -> Unit) = press(
        FrameLayout(this).apply {
            minimumWidth = dp(44)
            minimumHeight = dp(44)
            put(view)
        },
        0.8f,
        act,
    )

    fun meter() = FrameLayout(this).apply {
        setBackgroundColor(fill("fgMuted", 0x33))
        addView(View(this@Home).apply { pivotX = 0f; scaleX = 0f; setBackgroundColor(color("accent")) }, MATCH_PARENT, MATCH_PARENT)
    }

    fun level(meter: FrameLayout, fraction: Float, key: String = "accent") {
        val bar = meter.getChildAt(0)
        bar.setBackgroundColor(color(key))
        glide(bar, 600).scaleX(fraction.coerceIn(0f, 1f)).start()
    }

    fun busy(view: View, on: Boolean) {
        val running = view.tag as? ValueAnimator
        if (on == (running != null)) return
        if (on) {
            view.tag = ObjectAnimator.ofFloat(view, View.ALPHA, 1f, 0.3f).apply {
                duration = 700
                repeatMode = ValueAnimator.REVERSE
                repeatCount = ValueAnimator.INFINITE
                start()
            }
        } else {
            running?.cancel()
            view.tag = null
            view.alpha = 1f
        }
    }

    private fun bump(view: View) {
        view.scaleX = 0.6f
        view.scaleY = 0.6f
        glide(view, 220).scaleX(1f).scaleY(1f).start()
    }

    private fun rise(group: ViewGroup) {
        for (i in 0 until group.childCount) {
            val child = group.getChildAt(i)
            child.alpha = 0f
            child.translationY = dp(20).toFloat()
            glide(child, 360).setStartDelay(i * 40L).alpha(1f).translationY(0f).start()
        }
    }

    fun empty(icon: String, label: String) = column(
        glyph(icon, "fgMuted", 48).apply { alpha = 0.6f },
        text(13f, "fgMuted", label).below(12),
    ).apply {
        gravity = Gravity.CENTER_HORIZONTAL
        setPadding(0, dp(56), 0, 0)
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
        face = font(theme.optString("font"))
        val open = stack.map { it.key }
        stack.clear()

        val time = press(tile(clock("HH:mm", 54f, "fg"), clock("EEE d MMMM", 14f, "fgMuted")), 0.97f) {
            runCatching { startActivity(Intent(AlarmClock.ACTION_SHOW_ALARMS)) }
        }
        sky = glyph("cloud", "fgMuted", 36)
        degrees = text(24f, "fg", "--").below(6)
        spread = text(11f, "fgMuted")
        val weather = press(tile(sky, degrees, spread).apply { gravity = Gravity.CENTER }, 0.97f) { go("weather") }

        power = glyph("battery-medium", "accent", 14)
        meters = List(3) { meter() to text(11f, "fgMuted").after(6) }
        val system = press(
            tile(
                LinearLayout(this).apply {
                    for ((i, icon) in listOf(power, glyph("memory-stick", "accent", 14), glyph("hard-drive", "accent", 14)).withIndex()) {
                        val (bar, value) = meters[i]
                        addView(
                            column(strip(icon, value), bar.apply { layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(3)) }.below(8)),
                            LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f).apply { if (i > 0) marginStart = dp(16) },
                        )
                    }
                },
            ),
            0.97f,
        ) { go("system") }

        agenda = LinearLayout(this).apply { gravity = Gravity.CENTER_VERTICAL }
        val plans = press(tile(agenda), 0.97f) {
            if (checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED) {
                day = LocalDate.now()
                go("agenda")
            } else {
                requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), 1)
            }
        }

        cover = ImageView(this).apply { scaleType = ImageView.ScaleType.CENTER_CROP }
        note = glyph("music", "fgMuted", 20)
        track = line(14f, "fg")
        artist = line(12f, "fgMuted")
        toggle = glyph("play", "accent", 20)
        val prev = glyph("skip-back", "accent", 20)
        val next = glyph("skip-forward", "accent", 20)
        keys = listOf(prev, toggle, next)
        progress = meter()
        val playing = press(
            tile(
                strip(
                    FrameLayout(this).apply {
                        setBackgroundColor(color("bgAlt"))
                        layoutParams = LinearLayout.LayoutParams(dp(44), dp(44))
                        addView(cover, MATCH_PARENT, MATCH_PARENT)
                        put(note)
                    },
                    column(track, artist).apply { layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f).apply { marginStart = dp(12) } },
                    button(prev) { transport { it.skipToPrevious() } },
                    button(toggle) { playPause() },
                    button(next) { transport { it.skipToNext() } },
                ),
                progress.apply { layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(2)) }.below(10),
            ),
            0.97f,
        ) { if (granted()) go("player") else startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)) }

        terminal = glyph("square-terminal", "fgMuted", 22)
        link = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(40), dp(40))
            put(terminal)
        }
        way = line(12f, "fgMuted")
        val pc = press(quick(link, line(15f, "fg", "pc"), way), 0.96f) { connect() }
        preview = ImageView(this).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            layoutParams = ViewGroup.LayoutParams(MATCH_PARENT, MATCH_PARENT)
        }
        picture = glyph("image", "fgMuted", 20)
        scheme = line(15f, "fg")
        chips = strip().apply {
            for (key in listOf("accent") + SWATCHES) addView(View(this@Home).apply { setBackgroundColor(color(key)) }, LinearLayout.LayoutParams(dp(8), dp(8)).apply { marginEnd = dp(3) })
        }
        val look = press(
            quick(
                FrameLayout(this).apply {
                    setBackgroundColor(color("bgAlt"))
                    layoutParams = LinearLayout.LayoutParams(dp(40), dp(40))
                    put(preview)
                    put(picture)
                },
                scheme,
                chips.below(6),
            ),
            0.96f,
        ) { look(0) }

        pins = FrameLayout(this)
        val bar = press(tile(strip(glyph("search", "fgMuted", 16), text(15f, "fgMuted", "search").after(10))), 0.98f) { open() }
        home = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(row(time to 1.75f, weather to 1f))
            addView(row(system to 1f))
            addView(row(plans to 1f))
            addView(row(playing to 1f))
            addView(row(pc to 1f, look to 1f))
            addView(pins, LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f))
            addView(bar)
        }

        val clear = button(glyph("x", "fgMuted", 14)) { query.text.clear() }.apply { visibility = View.GONE }
        query = EditText(this).apply {
            background = null
            hint = "search"
            textSize = 16f
            typeface = face
            setTextColor(color("fg"))
            setHintTextColor(color("fgMuted"))
            textCursorDrawable = GradientDrawable().apply {
                setColor(color("accent"))
                setSize(dp(2), 0)
            }
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
            imeOptions = EditorInfo.IME_ACTION_GO
            setPadding(dp(10), dp(12), dp(10), dp(12))
            setOnEditorActionListener { _, _, _ ->
                shown.firstOrNull()?.let(::launch)
                true
            }
            addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}

                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}

                override fun afterTextChanged(s: Editable?) {
                    clear.visibility = if (s.isNullOrEmpty()) View.GONE else View.VISIBLE
                    filter()
                }
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
            setOnItemLongClickListener { view, _, i, _ ->
                view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                menu(shown[i])
                true
            }
        }
        drawer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.GONE
            isClickable = true
            setBackgroundColor(fill("bgDim", 0xf0))
            addView(
                strip(glyph("search", "fgMuted", 16), query.apply { layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f) }, clear).apply {
                    background = frame()
                    setPadding(dp(14), 0, dp(4), 0)
                },
                MATCH_PARENT,
                WRAP_CONTENT,
            )
            addView(grid, LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f))
        }

        options = tile().apply { isClickable = true }
        sheet = FrameLayout(this).apply {
            visibility = View.GONE
            setBackgroundColor(fill("bgDim", 0x99))
            setOnClickListener { hide() }
            addView(options, FrameLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT, Gravity.BOTTOM))
        }

        root = FrameLayout(this).apply {
            addView(home)
            addView(drawer)
            addView(sheet)
            setOnApplyWindowInsetsListener { _, insets ->
                bars = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.ime() or WindowInsets.Type.displayCutout())
                (listOf(home, drawer, sheet) + stack.map { it.view }).forEach(::pad)
                insets
            }
        }
        setContentView(root)
        val light = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
        window.insetsController?.setSystemBarsAppearance(if (Color.luminance(color("bgDim")) > 0.5f) light else 0, light)
        pin()
        refresh()
        for (key in open) screen(key)?.let { push(it, false) }
    }

    private fun pad(view: View) = view.setPadding(bars.left + dp(12), bars.top + dp(12), bars.right + dp(12), bars.bottom + dp(12))

    private fun screen(key: String): Screen? =
        when (key) {
            "weather" -> weatherScreen()
            "system" -> systemScreen()
            "agenda" -> agendaScreen()
            "week" -> weekScreen()
            "player" -> playerScreen()
            "appearance" -> appearanceScreen()
            else -> null
        }

    fun go(key: String) {
        if (stack.lastOrNull()?.key != key) screen(key)?.let(::push)
    }

    private fun push(screen: Screen, animate: Boolean = true) {
        val below = stack.lastOrNull()?.view ?: home
        stack += screen
        pad(screen.view)
        root.addView(screen.view, root.indexOfChild(sheet))
        if (screen.key == "week") requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
        if (!animate) {
            below.visibility = View.INVISIBLE
            return
        }
        val width = root.width.toFloat()
        if (screen.key == "week") {
            screen.view.alpha = 0f
            glide(screen.view).alpha(1f).start()
        } else {
            screen.view.translationX = width
            glide(screen.view, 300).translationX(0f).start()
        }
        glide(below, 300).translationX(-width / 4).alpha(0f).withEndAction { below.visibility = View.INVISIBLE }.start()
    }

    fun pop() {
        val top = stack.removeLastOrNull() ?: return
        val below = stack.lastOrNull()?.view ?: home
        below.visibility = View.VISIBLE
        glide(below, 300).translationX(0f).alpha(1f).start()
        if (top.key == "week") {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            glide(top.view, 180).alpha(0f).withEndAction { root.removeView(top.view) }.start()
        } else {
            glide(top.view, 260).translationX(root.width.toFloat()).withEndAction { root.removeView(top.view) }.start()
        }
        if (stack.isEmpty()) refresh() else stack.last().update()
    }

    fun back() {
        when {
            sheet.visibility == View.VISIBLE -> hide()
            stack.isNotEmpty() -> pop()
            drawer.visibility == View.VISIBLE -> close()
        }
    }

    private fun lean(progress: Float, settle: Boolean = false) {
        val view = when {
            sheet.visibility == View.VISIBLE -> options
            stack.isNotEmpty() -> stack.last().view
            drawer.visibility == View.VISIBLE -> drawer
            else -> return
        }
        when {
            settle -> glide(view, 180).translationX(0f).translationY(0f).scaleX(1f).scaleY(1f).start()
            view === stack.lastOrNull()?.view -> {
                view.translationX = progress * dp(56)
                view.scaleX = 1 - progress * 0.05f
                view.scaleY = view.scaleX
            }
            else -> view.translationY = progress * dp(80)
        }
    }

    fun land() {
        hide()
        close()
        if (stack.isEmpty()) return
        while (stack.size > 1) root.removeView(stack.removeAt(stack.lastIndex).view)
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        pop()
    }

    fun refresh() {
        val stats = stats()
        val key = when {
            stats.charging -> "success"
            stats.battery <= 15 -> "error"
            else -> "accent"
        }
        mark(
            power,
            when {
                stats.charging -> "battery-charging"
                stats.battery <= 15 -> "battery-warning"
                stats.battery <= 40 -> "battery-low"
                stats.battery <= 80 -> "battery-medium"
                else -> "battery-full"
            },
            key,
        )
        val fractions = listOf(stats.battery / 100f, stats.memory.toFloat() / stats.memoryTotal, stats.disk.toFloat() / stats.diskTotal)
        for ((i, fraction) in fractions.withIndex()) {
            val (bar, value) = meters[i]
            level(bar, fraction, if (i == 0) key else "accent")
            value.text = "${(fraction * 100).roundToInt()}%"
        }
        agendaTile()
        weatherTile()
        val waiting = pending()
        scheme.text = waiting?.let { "$it\u2026" } ?: name
        scheme.setTextColor(color(if (waiting == null) "fg" else "fgMuted"))
        busy(chips, waiting != null)
        wallTile()
        live()
        stack.lastOrNull()?.update?.invoke()
        Thread {
            val route = when {
                tether().isNotEmpty() -> "usb tether"
                online() -> "tailnet"
                else -> null
            }
            runOnUiThread {
                link.setBackgroundColor(if (route == null) fill("fgMuted", 0x26) else color(if (route == "usb tether") "success" else "accent"))
                mark(terminal, "square-terminal", if (route == null) "fgMuted" else "bgDim")
                way.text = route ?: "offline"
            }
        }.start()
        weather(false)
    }

    fun stats(): Stats {
        val memory = ActivityManager.MemoryInfo().also { getSystemService(ActivityManager::class.java).getMemoryInfo(it) }
        val disk = StatFs(Environment.getDataDirectory().path)
        val battery = getSystemService(BatteryManager::class.java)
        return Stats(
            memory.totalMem - memory.availMem,
            memory.totalMem,
            disk.totalBytes - disk.availableBytes,
            disk.totalBytes,
            battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY),
            battery.isCharging,
        )
    }

    fun installed() = apps.size

    private fun agendaTile() {
        agenda.removeAllViews()
        if (checkSelfPermission(Manifest.permission.READ_CALENDAR) != PackageManager.PERMISSION_GRANTED) {
            agenda.addView(glyph("calendar", "fgMuted", 18))
            agenda.addView(text(14f, "fgMuted", "allow calendar").after(12))
            return
        }
        val now = System.currentTimeMillis()
        val found = events(now, now + 7 * 86_400_000L).filter { it.end > now }
        val next = found.firstOrNull { !it.allDay } ?: found.firstOrNull()
        if (next == null) {
            agenda.addView(glyph("calendar", "fgMuted", 18))
            agenda.addView(text(14f, "fgMuted", "free this week").after(12))
            return
        }
        val today = LocalDate.now()
        val running = next.begin <= now
        val more = found.count { it !== next && !it.allDay && it.on(today) }
        val tint = if (running) "success" else "accent"
        val bar = View(this).apply { setBackgroundColor(color(tint)) }
        agenda.addView(bar, LinearLayout.LayoutParams(dp(3), MATCH_PARENT).apply { marginEnd = dp(12) })
        if (running) busy(bar, true)
        val where = next.where()
        agenda.addView(
            column(line(15f, "fg", next.label()), strip(glyph("map-pin", "fgMuted", 12), line(12f, "fgDim", where).after(6)).below(4).apply { if (where.isBlank()) visibility = View.GONE }),
            LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f),
        )
        agenda.addView(
            column(text(14f, tint, until(next, now)), text(11f, "fgMuted", if (more > 0) "+$more today" else "").below(2)).apply { gravity = Gravity.END },
            LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply { marginStart = dp(8) },
        )
    }

    private fun until(event: Event, now: Long): String {
        val minutes = (event.begin - now) / 60_000
        return when {
            event.begin <= now -> "now"
            minutes < 60 -> "in ${minutes}m"
            event.on(LocalDate.now()) -> DateFormat.format("HH:mm", event.begin).toString()
            else -> DateFormat.format("EEE", event.begin).toString().lowercase()
        }
    }

    fun forecast(): JSONObject? = runCatching { JSONObject(state.getString("forecast", null)!!) }.getOrNull()

    fun updated() = state.getLong("forecastAt", 0)

    fun weather(force: Boolean) {
        if (fetching || !force && System.currentTimeMillis() - updated() < 1_800_000) return
        fetching = true
        stack.lastOrNull()?.takeIf { it.key == "weather" }?.update?.invoke()
        Thread {
            val body = runCatching { URL(FORECAST).readText() }.getOrNull()
            runOnUiThread {
                fetching = false
                if (body != null) state.edit().putString("forecast", body).putLong("forecastAt", System.currentTimeMillis()).apply()
                weatherTile()
                stack.lastOrNull()?.takeIf { it.key == "weather" }?.update?.invoke()
            }
        }.start()
    }

    fun sky(code: Int, day: Boolean = true) =
        when (code) {
            0, 1 -> if (day) "sun" else "moon"
            2 -> if (day) "cloud-sun" else "cloud-moon"
            3 -> "cloud"
            45, 48 -> "cloud-fog"
            in 51..57 -> "cloud-drizzle"
            in 61..67, in 80..82 -> "cloud-rain"
            in 71..77, 85, 86 -> "cloud-snow"
            else -> "cloud-lightning"
        }

    private fun weatherTile() {
        runCatching {
            val data = forecast()!!
            val now = data.getJSONObject("current")
            val daily = data.getJSONObject("daily")
            mark(sky, sky(now.getInt("weather_code"), now.optInt("is_day", 1) == 1), "accent")
            degrees.text = "${now.getDouble("temperature_2m").roundToInt()}°"
            spread.text = span(
                "${daily.getJSONArray("temperature_2m_max").getDouble(0).roundToInt()}° " to "fgDim",
                "${daily.getJSONArray("temperature_2m_min").getDouble(0).roundToInt()}°" to "fgMuted",
            )
        }.onFailure {
            mark(sky, "cloud", "fgMuted")
            degrees.text = "--"
            spread.text = ""
        }
    }

    private fun granted() =
        Settings.Secure.getString(contentResolver, "enabled_notification_listeners").orEmpty().contains(packageName)

    private fun player(): MediaController? =
        runCatching {
            val sessions = getSystemService(MediaSessionManager::class.java).getActiveSessions(ComponentName(this, Listener::class.java))
            sessions.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING } ?: sessions.firstOrNull { it.packageName == music() } ?: sessions.firstOrNull()
        }.getOrNull()

    fun music() = state.getString("music", "").orEmpty()

    fun label(pkg: String) =
        runCatching { packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString().lowercase() }.getOrNull()

    fun start(pkg: String) {
        if (pkg.isEmpty()) tunes() else packageManager.getLaunchIntentForPackage(pkg)?.let(::startActivity)
    }

    fun playPause() {
        val pkg = music()
        when {
            controller != null -> transport { if (playing()) it.pause() else it.play() }
            pkg.isEmpty() -> tunes()
            else -> resume(pkg)
        }
    }

    private fun resume(pkg: String) {
        val audio = getSystemService(AudioManager::class.java)
        for (action in listOf(KeyEvent.ACTION_DOWN, KeyEvent.ACTION_UP)) audio.dispatchMediaKeyEvent(KeyEvent(action, KeyEvent.KEYCODE_MEDIA_PLAY))
        await(pkg, 16)
    }

    private fun await(pkg: String, tries: Int) {
        handler.postDelayed({
            live()
            val mine = controller?.packageName == pkg
            val empty = mine && controller?.playbackState?.state == PlaybackState.STATE_STOPPED && controller?.metadata == null
            when {
                playing() && mine -> Unit
                playing() -> {
                    controller?.transportControls?.pause()
                    bounce(pkg)
                }
                tries == 0 || empty && tries <= 10 -> bounce(pkg)
                else -> await(pkg, tries - 1)
            }
        }, 500)
    }

    private fun bounce(pkg: String) {
        start(pkg)
        settle(pkg, 30)
    }

    private fun settle(pkg: String, tries: Int) {
        handler.postDelayed({
            val session = runCatching {
                getSystemService(MediaSessionManager::class.java).getActiveSessions(ComponentName(this, Listener::class.java)).firstOrNull { it.packageName == pkg }
            }.getOrNull()
            val state = session?.playbackState?.state
            when {
                state == PlaybackState.STATE_PLAYING -> startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                tries == 0 -> Unit
                else -> {
                    if (session?.metadata != null && state != PlaybackState.STATE_BUFFERING && state != PlaybackState.STATE_CONNECTING) session.transportControls.play()
                    settle(pkg, tries - 1)
                }
            }
        }, 500)
    }

    fun tunes() {
        val found = (
            packageManager.queryIntentServices(Intent("android.media.browse.MediaBrowserService"), 0).map { it.serviceInfo.packageName } +
                packageManager.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_APP_MUSIC), 0).map { it.activityInfo.packageName }
            ).toSet()
        val choices = apps.filter { it.component.packageName in found && it.component.packageName != packageName }.distinctBy { it.component.packageName }
        val current = music()
        options.removeAllViews()
        options.addView(strip(glyph("music", "accent", 22), line(16f, "fg", "default music app").after(14)).apply { setPadding(0, 0, 0, dp(10)) })
        val rows = column()
        for (app in choices) {
            val box = icon().apply {
                layoutParams = LinearLayout.LayoutParams(dp(36), dp(36))
                setPadding(dp(4), dp(4), dp(4), dp(4))
            }
            draw(box, app)
            rows.addView(
                press(
                    strip(
                        box,
                        line(15f, "fg", app.label).apply { layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f).apply { marginStart = dp(14) } },
                        glyph("check", "accent", 18).apply { if (app.component.packageName != current) visibility = View.INVISIBLE },
                    ).apply { setPadding(0, dp(8), 0, dp(8)) },
                    0.98f,
                ) {
                    state.edit().putString("music", app.component.packageName).apply()
                    hide()
                    live()
                },
                MATCH_PARENT,
                WRAP_CONTENT,
            )
        }
        if (choices.isEmpty()) rows.addView(text(14f, "fgMuted", "no music apps found"))
        options.addView(scroll(rows), MATCH_PARENT, WRAP_CONTENT)
        show()
    }

    fun playing() = controller?.playbackState?.state == PlaybackState.STATE_PLAYING

    fun artwork(meta: MediaMetadata?): Bitmap? =
        meta?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART) ?: meta?.getBitmap(MediaMetadata.METADATA_KEY_ART)

    fun position(): Pair<Long, Long> {
        val player = controller ?: return 0L to 0L
        val playback = player.playbackState ?: return 0L to 0L
        val total = player.metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L
        var at = playback.position
        if (playback.state == PlaybackState.STATE_PLAYING) at += ((SystemClock.elapsedRealtime() - playback.lastPositionUpdateTime) * playback.playbackSpeed).toLong()
        return at.coerceIn(0L, maxOf(total, 0L)) to total
    }

    fun transport(act: (MediaController.TransportControls) -> Unit) {
        controller?.transportControls?.let(act)
        handler.postDelayed(::live, 300)
    }

    private fun beat() {
        val (at, total) = position()
        level(progress, if (total > 0) at.toFloat() / total else 0f)
        stack.lastOrNull()?.beat?.invoke()
    }

    fun live() {
        val allowed = granted()
        val player = if (allowed) player() else null
        controller = player
        val meta = player?.metadata
        val fallback = if (player == null) label(music()) else null
        track.text = when {
            !allowed -> "allow access"
            meta == null -> "nothing playing"
            else -> meta.getString(MediaMetadata.METADATA_KEY_TITLE).orEmpty()
        }
        track.setTextColor(color(if (meta == null) "fgMuted" else "fg"))
        artist.text = meta?.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: fallback.orEmpty()
        artist.visibility = if (artist.text.isEmpty()) View.GONE else View.VISIBLE
        val art = artwork(meta)
        cover.setImageBitmap(art)
        note.visibility = if (art == null) View.VISIBLE else View.GONE
        if (mark(toggle, if (playing()) "pause" else "play", "accent")) bump(toggle)
        keys.forEach { it.alpha = if (player == null && (it !== toggle || !allowed)) 0.35f else 1f }
        beat()
        handler.removeCallbacks(second)
        if (playing()) handler.postDelayed(second, 1000)
        stack.lastOrNull()?.takeIf { it.key == "player" }?.update?.invoke()
    }

    fun pending() = switching?.takeIf { System.currentTimeMillis() - switchedAt < 90_000 }

    fun thumb(id: String): Bitmap? {
        val file = File(File(filesDir, WALLS), id)
        if (!file.exists()) return null
        val cached = thumbs[id]?.takeIf { it.first == file.lastModified() }
        return cached?.second ?: BitmapFactory.decodeFile(file.path).also { thumbs[id] = file.lastModified() to it }
    }

    fun wallName() = walls.getString("current", "").orEmpty().removePrefix("plates+").substringBeforeLast('.')

    private fun wallTile() {
        val current = walls.getString("current", "").orEmpty()
        val bitmap = if (current.isEmpty()) null else thumb(current)
        preview.setImageBitmap(bitmap)
        picture.visibility = if (bitmap == null) View.VISIBLE else View.GONE
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
            glide(box, 160).scaleX(1.15f).scaleY(1.15f).alpha(0.85f).start()
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
                    glide(view, 90).scaleX(0.9f).scaleY(0.9f).start()
                    handler.postDelayed(lift, 350)
                }
                MotionEvent.ACTION_MOVE -> {
                    if (abs(dx) + abs(dy) > dp(12) && !far) {
                        far = true
                        if (!carrying) {
                            handler.removeCallbacks(lift)
                            glide(view).scaleX(1f).scaleY(1f).start()
                        }
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
                    glide(view).scaleX(1f).scaleY(1f).alpha(1f).translationX(0f).translationY(0f).start()
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
        val items = listOf<Triple<String, String, () -> Unit>>(
            Triple(if (app.id in pinned) "pin-off" else "pin", if (app.id in pinned) "unpin" else "pin") {
                val spots = JSONObject(state.getString("spots", "{}")).apply { remove(app.id) }
                state.edit()
                    .putString("pins", JSONArray(if (app.id in pinned) pinned - app.id else pinned + app.id).toString())
                    .putString("spots", spots.toString())
                    .apply()
                pin()
            },
            Triple("info", "app info") { startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, target)) },
            Triple("trash-2", "uninstall") { startActivity(Intent(Intent.ACTION_DELETE, target)) },
        )
        options.removeAllViews()
        val box = icon().apply { layoutParams = LinearLayout.LayoutParams(dp(44), dp(44)) }
        draw(box, app)
        options.addView(strip(box, line(16f, "fg", app.label).after(14)).apply { setPadding(0, 0, 0, dp(6)) })
        for ((glyph, label, act) in items) {
            options.addView(
                press(strip(glyph(glyph, "accent", 18), text(16f, "fg", label).after(16)).apply { setPadding(dp(13), dp(14), 0, dp(14)) }, 0.98f) {
                    hide()
                    act()
                },
                MATCH_PARENT,
                WRAP_CONTENT,
            )
        }
        show()
    }

    private fun show() {
        sheet.visibility = View.VISIBLE
        sheet.alpha = 0f
        glide(sheet, 200).alpha(1f).start()
        options.translationY = dp(320).toFloat()
        glide(options, 320).translationY(0f).start()
    }

    private fun hide(animate: Boolean = true) {
        if (sheet.visibility != View.VISIBLE) return
        if (!animate) {
            sheet.animate().cancel()
            sheet.visibility = View.GONE
            return
        }
        glide(sheet, 200).alpha(0f).withEndAction { sheet.visibility = View.GONE }.start()
        glide(options, 200).translationY(options.height.toFloat()).start()
    }

    private fun switch(theme: String) {
        if (theme == name) return
        termux("pc", tether(), "theme", theme)
        switching = theme
        switchedAt = System.currentTimeMillis()
        refresh()
    }

    fun choose(theme: String) = switch(theme)

    fun wallpapers() {
        val have = File(filesDir, WALLS).list().orEmpty().filter(ID::matches)
        walls.edit().putString("status", "syncing").apply()
        termux("pc", tether(), "walls", *have.toTypedArray())
    }

    fun look(page: Int) {
        tab = page
        wallpapers()
        go("appearance")
    }

    fun pick(id: String) {
        termux("pc", tether(), "wall", id)
        walls.edit().putString("current", id).apply()
        if (stack.lastOrNull()?.key == "appearance") pop()
    }

    private fun termux(script: String, vararg args: String, session: Boolean = false) {
        val run = Intent("com.termux.RUN_COMMAND")
            .setClassName(TERMUX, "$TERMUX.app.RunCommandService")
            .putExtra("$TERMUX.RUN_COMMAND_PATH", "/data/data/$TERMUX/files/usr/bin/bash")
            .putExtra("$TERMUX.RUN_COMMAND_ARGUMENTS", arrayOf("-c", assets.open(script).bufferedReader().use { it.readText() }, script, *args))
            .putExtra("$TERMUX.RUN_COMMAND_BACKGROUND", !session)
        if (session) run.putExtra("$TERMUX.RUN_COMMAND_SESSION_ACTION", "0")
        runCatching { startForegroundService(run) }
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
        termux("pc", tether(), session = true)
        packageManager.getLaunchIntentForPackage(TERMUX)?.let(::startActivity)
    }

    private fun serve() {
        for (daemon in listOf("sshd", "tailscaled")) termux("serve", daemon)
    }

    fun open() {
        if (drawer.visibility == View.VISIBLE) return
        drawer.visibility = View.VISIBLE
        drawer.alpha = 0f
        drawer.translationY = dp(64).toFloat()
        glide(drawer, 300).alpha(1f).translationY(0f).start()
        glide(home, 200).alpha(0f).withEndAction { home.visibility = View.INVISIBLE }.start()
        query.requestFocus()
        query.post { getSystemService(InputMethodManager::class.java).showSoftInput(query, 0) }
    }

    private fun close(animate: Boolean = true) {
        if (drawer.visibility != View.VISIBLE) return
        query.text.clear()
        query.clearFocus()
        getSystemService(InputMethodManager::class.java).hideSoftInputFromWindow(query.windowToken, 0)
        home.visibility = View.VISIBLE
        if (!animate) {
            drawer.animate().cancel()
            home.animate().cancel()
            drawer.visibility = View.GONE
            home.alpha = 1f
            grid.setSelection(0)
            return
        }
        glide(home).alpha(1f).start()
        glide(drawer, 220).alpha(0f).translationY(dp(64).toFloat()).withEndAction {
            drawer.visibility = View.GONE
            grid.setSelection(0)
        }.start()
    }

    private fun shade() {
        runCatching { Class.forName("android.app.StatusBarManager").getMethod("expandNotificationsPanel").invoke(getSystemService("statusbar")) }
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
}
