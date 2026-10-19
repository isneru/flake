package dev.neru.bare

import android.app.ActivityOptions
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.drawable.GradientDrawable
import android.media.MediaMetadata
import android.os.Build
import android.os.SystemClock
import android.provider.CalendarContract
import android.provider.Settings
import android.text.TextUtils
import android.text.format.DateFormat
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.ImageView
import android.widget.LinearLayout
import org.json.JSONArray
import org.json.JSONObject
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.time.temporal.ChronoUnit
import java.util.Locale
import kotlin.math.roundToInt
import kotlin.math.sign

private val MONTH = DateTimeFormatter.ofPattern("MMMM yyyy")
private val DAY = DateTimeFormatter.ofPattern("EEEE d")

fun Home.surface(title: View, body: View, vararg actions: View) = LinearLayout(this).apply {
    orientation = LinearLayout.VERTICAL
    isClickable = true
    setBackgroundColor(fill("bgDim", 0xf0))
    addView(
        strip(
            button(glyph("arrow-left", "fg", 22)) { back() }.apply { layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply { marginStart = -dp(11) } },
            title.apply { layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f).apply { marginStart = dp(6) } },
            *actions,
        ).apply { actions.lastOrNull()?.layoutParams = LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply { marginEnd = -dp(12) } },
    )
    addView(body, LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f).apply { topMargin = dp(8) })
}

fun Home.heading(value: String) = line(20f, "fg", value)

private fun Home.section(label: String, first: Boolean = false) = text(12f, "fgMuted", label).apply {
    letterSpacing = 0.06f
    setPadding(dp(2), if (first) dp(4) else dp(20), 0, dp(8))
}

private fun Home.degrees(value: Double) = "${value.roundToInt()}°"

private fun Home.full(view: View) = view.apply { layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT) }

private fun Home.centred(size: Float, key: String, value: CharSequence = "") = text(size, key, value).apply {
    gravity = Gravity.CENTER
    layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT)
}

fun Home.skyName(code: Int) =
    when (code) {
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

private fun Home.stat(icon: String, value: String, label: String) =
    tile(
        glyph(icon, "accent", 20),
        text(15f, "fg", value).below(8),
        text(11f, "fgMuted", label).below(2),
    ).apply { gravity = Gravity.CENTER_HORIZONTAL }

private fun Home.range(from: Float, to: Float) = object : View(this) {
    private val paint = Paint()

    override fun onDraw(canvas: Canvas) {
        val y = height / 2f
        val thick = dp(2).toFloat()
        paint.color = fill("fgMuted", 0x33)
        canvas.drawRect(0f, y - thick, width.toFloat(), y + thick, paint)
        paint.color = color("accent")
        canvas.drawRect(width * from, y - thick, maxOf(width * to, width * from + thick * 2), y + thick, paint)
    }
}

private fun Home.forecastBody(body: LinearLayout, data: JSONObject) {
    val now = data.getJSONObject("current")
    val hourly = data.getJSONObject("hourly")
    val daily = data.getJSONObject("daily")
    val code = now.getInt("weather_code")
    val highs = daily.getJSONArray("temperature_2m_max")
    val lows = daily.getJSONArray("temperature_2m_min")
    body.addView(
        column(
            strip(
                glyph(sky(code, now.optInt("is_day", 1) == 1), "accent", 64),
                text(64f, "fg", degrees(now.getDouble("temperature_2m"))).apply { includeFontPadding = false }.after(16),
            ).apply { gravity = Gravity.CENTER },
            centred(15f, "fgDim", skyName(code)).below(10),
            centred(13f, "fgMuted", "${degrees(highs.getDouble(0))} / ${degrees(lows.getDouble(0))}").below(2),
        ).apply { setPadding(0, dp(16), 0, dp(24)) },
        LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT),
    )
    body.addView(
        row(
            stat("thermometer", degrees(now.getDouble("apparent_temperature")), "feels like") to 1f,
            stat("droplet", "${now.optInt("relative_humidity_2m")}%", "humidity") to 1f,
            stat("wind", "${now.optDouble("wind_speed_10m").roundToInt()} km/h", "wind") to 1f,
        ).apply { setPadding(0, 0, 0, 0) },
    )
    body.addView(section("next 24 hours"))
    val times = hourly.getJSONArray("time")
    val hours = LinearLayout(this)
    for (i in 0 until times.length()) {
        val rain = hourly.getJSONArray("precipitation_probability").optInt(i)
        hours.addView(
            column(
                text(11f, if (i == 0) "accent" else "fgMuted", if (i == 0) "now" else times.getString(i).substring(11, 16)),
                glyph(sky(hourly.getJSONArray("weather_code").getInt(i), hourly.getJSONArray("is_day").optInt(i, 1) == 1), "accent", 22).below(10),
                text(15f, "fg", degrees(hourly.getJSONArray("temperature_2m").getDouble(i))).below(10),
                text(11f, "accent", if (rain >= 20) "$rain%" else " ").below(2),
            ).apply { gravity = Gravity.CENTER_HORIZONTAL },
            LinearLayout.LayoutParams(dp(56), WRAP_CONTENT),
        )
    }
    body.addView(
        full(
            tile(
                HorizontalScrollView(this).apply {
                    isHorizontalScrollBarEnabled = false
                    addView(hours)
                },
            ).apply { setPadding(dp(4), dp(14), dp(4), dp(14)) },
        ),
    )
    body.addView(section("7 days"))
    val days = daily.getJSONArray("time")
    val floor = (0 until days.length()).minOf { lows.getDouble(it) }.toFloat()
    val ceiling = (0 until days.length()).maxOf { highs.getDouble(it) }.toFloat()
    val spanned = maxOf(1f, ceiling - floor)
    val week = tile().apply { setPadding(dp(14), dp(4), dp(14), dp(4)) }
    for (i in 0 until days.length()) {
        val low = lows.getDouble(i).toFloat()
        val high = highs.getDouble(i).toFloat()
        val rain = daily.getJSONArray("precipitation_probability_max").optInt(i)
        val name = if (i == 0) "today" else LocalDate.parse(days.getString(i)).dayOfWeek.getDisplayName(TextStyle.SHORT, Locale.getDefault()).lowercase()
        week.addView(
            strip(
                text(15f, if (i == 0) "accent" else "fg", name).apply { width = dp(56) },
                glyph(sky(daily.getJSONArray("weather_code").getInt(i)), "accent", 22),
                text(11f, "accent", if (rain >= 20) "$rain%" else "").apply { width = dp(36) }.after(8),
                text(15f, "fgMuted", degrees(low.toDouble())).apply {
                    width = dp(40)
                    gravity = Gravity.END
                },
                range((low - floor) / spanned, (high - floor) / spanned).apply { layoutParams = LinearLayout.LayoutParams(0, dp(12), 1f).apply { marginStart = dp(12); marginEnd = dp(12) } },
                text(15f, "fg", degrees(high.toDouble())).apply { width = dp(40) },
            ).apply { setPadding(0, dp(10), 0, dp(10)) },
        )
    }
    body.addView(full(week))
    body.addView(centred(11f, "fgMuted", "updated ${DateFormat.format("HH:mm", updated())}").apply { setPadding(0, dp(16), 0, dp(8)) })
}

fun Home.weatherScreen(): Screen {
    val body = column()
    val reload = glyph("refresh-cw", "accent", 20)
    fun fill() {
        body.removeAllViews()
        busy(reload, fetching)
        val data = forecast()
        if (data == null || runCatching { forecastBody(body, data) }.isFailure) {
            body.removeAllViews()
            body.addView(full(empty("cloud", if (fetching) "fetching" else "no forecast")))
        }
    }
    fill()
    return Screen("weather", surface(heading(PLACE), scroll(body), button(reload) { weather(true) }), ::fill)
}

private fun Home.fact(icon: String, label: String, value: String, act: (() -> Unit)? = null) =
    strip(
        glyph(icon, "accent", 20),
        text(15f, "fg", label).after(14),
        space(),
        line(13f, "fgMuted", value).after(12),
        glyph("chevron-right", "fgMuted", 16).after(6).apply { if (act == null) visibility = View.GONE },
    ).apply {
        setPadding(0, dp(12), 0, dp(12))
        if (act != null) press(this, 0.98f, act)
    }

private fun Home.gauge(icon: String, label: String, value: String, fraction: Float, key: String, act: (() -> Unit)? = null): View {
    val bar = meter().apply { layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(4)) }
    bar.post { level(bar, fraction, key) }
    return column(fact(icon, label, value, act), bar).apply { setPadding(0, 0, 0, dp(10)) }
}

fun Home.systemScreen(): Screen {
    val body = column()
    fun fill() {
        body.removeAllViews()
        val stats = stats()
        val up = SystemClock.elapsedRealtime() / 60_000
        body.addView(
            full(
                tile(
                    strip(
                        glyph("smartphone", "accent", 40),
                        column(line(18f, "fg", Build.MODEL), text(13f, "fgMuted", "android ${Build.VERSION.RELEASE}").below(2)).after(14),
                    ),
                    strip().apply {
                        for (key in listOf("accent") + SWATCHES) addView(View(this@systemScreen).apply { setBackgroundColor(color(key)) }, LinearLayout.LayoutParams(0, dp(10), 1f).apply { marginEnd = dp(4) })
                    }.below(16),
                ),
            ),
        )
        body.addView(section("device"))
        body.addView(
            full(
                tile(
                    fact("cpu", "kernel", System.getProperty("os.version").orEmpty().substringBefore('-')),
                    fact("clock-3", "uptime", "${up / 1440}d ${up / 60 % 24}h ${up % 60}m"),
                    fact("layout-grid", "apps", installed().toString()) {
                        land()
                        open()
                    },
                ).apply { setPadding(dp(14), dp(2), dp(14), dp(2)) },
            ),
        )
        body.addView(section("appearance"))
        body.addView(
            full(
                tile(
                    fact("palette", "theme", name) { look(0) },
                    fact("image", "wallpaper", wallName().ifEmpty { "none" }) { look(1) },
                ).apply { setPadding(dp(14), dp(2), dp(14), dp(2)) },
            ),
        )
        val charge = when {
            stats.charging -> "success"
            stats.battery <= 15 -> "error"
            else -> "accent"
        }
        body.addView(section("usage"))
        body.addView(
            full(
                tile(
                    gauge("memory-stick", "memory", "%.1f / %.0f G".format(stats.memory / GB, stats.memoryTotal / GB), stats.memory.toFloat() / stats.memoryTotal, "accent"),
                    gauge("hard-drive", "storage", "%.0f / %.0f G".format(stats.disk / GB, stats.diskTotal / GB), stats.disk.toFloat() / stats.diskTotal, "accent") {
                        startActivity(Intent(Settings.ACTION_INTERNAL_STORAGE_SETTINGS))
                    },
                    gauge(if (stats.charging) "battery-charging" else "battery-medium", "battery", "${stats.battery}%" + if (stats.charging) " charging" else "", stats.battery / 100f, charge) {
                        startActivity(Intent(Intent.ACTION_POWER_USAGE_SUMMARY))
                    },
                ).apply { setPadding(dp(14), dp(2), dp(14), dp(6)) },
            ),
        )
    }
    fill()
    return Screen("system", surface(heading("system"), scroll(body), button(glyph("settings", "accent", 20)) { startActivity(Intent(Settings.ACTION_SETTINGS)) }), ::fill)
}

private fun Home.card(event: Event, now: Long): View {
    val over = event.end <= now
    val running = !over && event.begin <= now
    val key = if (over) "fgMuted" else if (running) "success" else "accent"
    val time = if (event.allDay) {
        column(glyph("calendar", key, 18), text(11f, "fgMuted", "all day").below(4))
    } else {
        column(text(15f, "fg", DateFormat.format("HH:mm", event.begin)), text(12f, "fgMuted", DateFormat.format("HH:mm", event.end)).below(2))
    }
    val bar = View(this).apply { setBackgroundColor(color(key)) }
    val where = event.where()
    val card = LinearLayout(this).apply {
        background = frame()
        setPadding(dp(14), dp(12), dp(14), dp(12))
        addView(time, LinearLayout.LayoutParams(dp(52), WRAP_CONTENT))
        addView(bar, LinearLayout.LayoutParams(dp(3), MATCH_PARENT).apply { marginStart = dp(6); marginEnd = dp(14) })
        addView(
            column(
                text(15f, "fg", event.label()).apply { maxLines = 2; ellipsize = TextUtils.TruncateAt.END },
                strip(glyph("map-pin", "fgMuted", 14), line(13f, "fgDim", where).after(6)).below(6).apply { if (where.isBlank()) visibility = View.GONE },
            ),
            LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f),
        )
    }
    if (over) card.alpha = 0.55f
    if (running) busy(bar, true)
    return press(card, 0.98f) { visit(event) }
}

fun Home.agendaScreen(): Screen {
    val title = heading("")
    val days = LinearLayout(this)
    val label = section("", true)
    val list = column()
    val body = column(full(days), full(label), scroll(list).apply { layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f) })
    fun fill(direction: Int) {
        val zone = ZoneId.systemDefault()
        val today = LocalDate.now()
        val monday = day.with(DayOfWeek.MONDAY)
        val start = monday.atStartOfDay(zone).toInstant().toEpochMilli()
        val found = events(start - 86_400_000L, start + 8 * 86_400_000L)
        title.text = day.format(MONTH).lowercase()
        label.text = when (day) {
            today -> "today"
            today.plusDays(1) -> "tomorrow"
            today.minusDays(1) -> "yesterday"
            else -> day.format(DAY).lowercase()
        }
        label.setPadding(dp(2), dp(20), 0, dp(0))
        days.removeAllViews()
        for (i in 0..6) {
            val date = monday.plusDays(i.toLong())
            val chosen = date == day
            val cell = column(
                text(11f, if (chosen) "accent" else "fgMuted", date.dayOfWeek.getDisplayName(TextStyle.NARROW, Locale.getDefault())),
                text(18f, if (date == today || chosen) "accent" else "fg", date.dayOfMonth.toString()).below(4),
                View(this).apply {
                    layoutParams = LinearLayout.LayoutParams(dp(4), dp(4)).apply { topMargin = dp(6) }
                    setBackgroundColor(if (found.any { it.on(date) }) color(if (chosen) "accent" else "fgMuted") else Color.TRANSPARENT)
                },
            ).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                setPadding(0, dp(10), 0, dp(10))
                background = GradientDrawable().apply {
                    setColor(if (chosen) fill("accent", 0x26) else fill("bgDim", 0xe0))
                    setStroke(dp(2), color(if (chosen) "accent" else "border"))
                }
            }
            press(cell, 0.9f) {
                val step = date.compareTo(day).sign
                day = date
                fill(step)
            }
            days.addView(cell, LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f).apply { if (i > 0) marginStart = dp(6) })
        }
        list.removeAllViews()
        val now = System.currentTimeMillis()
        val those = found.filter { it.on(day) }.sortedWith(compareBy<Event> { !it.allDay }.thenBy { it.begin })
        if (those.isEmpty()) list.addView(full(empty("calendar", "nothing planned")))
        for (event in those) list.addView(card(event, now), LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { topMargin = dp(8) })
        if (direction == 0) return
        list.translationX = direction * dp(48).toFloat()
        list.alpha = 0f
        glide(list).translationX(0f).alpha(1f).start()
    }
    fill(0)
    val insert = button(glyph("calendar-plus", "accent", 20)) {
        val begin = day.atTime(9, 0).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        runCatching {
            startActivity(
                Intent(Intent.ACTION_INSERT, CalendarContract.Events.CONTENT_URI)
                    .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, begin)
                    .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, begin + 3_600_000L),
            )
        }
    }
    val grid = button(glyph("calendar-range", "accent", 20)) {
        shift = ChronoUnit.WEEKS.between(LocalDate.now().with(DayOfWeek.MONDAY), day.with(DayOfWeek.MONDAY)).toInt()
        go("week")
    }
    return Screen(
        "agenda",
        surface(title, body, insert, grid),
        { fill(0) },
        {
            day = day.plusDays(it.toLong())
            fill(it)
        },
    )
}

class Seek(private val home: Home) : View(home) {
    private var at = 0L
    private var length = 0L
    private var drag: Float? = null
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)

    fun set(at: Long, length: Long) {
        this.at = at
        this.length = length
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        val fraction = drag ?: if (length > 0) at.toFloat() / length else 0f
        val y = height / 2f
        val thick = home.dp(2).toFloat()
        val knob = home.dp(if (drag == null) 6 else 9).toFloat()
        val x = knob + (width - 2 * knob) * fraction
        paint.color = home.fill("fgMuted", 0x33)
        canvas.drawRect(0f, y - thick, width.toFloat(), y + thick, paint)
        paint.color = home.color("accent")
        canvas.drawRect(0f, y - thick, x, y + thick, paint)
        canvas.drawRect(x - knob, y - knob, x + knob, y + knob, paint)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (length <= 0) return false
        val fraction = (event.x / width).coerceIn(0f, 1f)
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                parent.requestDisallowInterceptTouchEvent(true)
                drag = fraction
            }
            MotionEvent.ACTION_UP -> {
                drag = null
                at = (fraction * length).toLong()
                home.controller?.transportControls?.seekTo(at)
            }
            MotionEvent.ACTION_CANCEL -> drag = null
        }
        invalidate()
        return true
    }
}

private fun minutes(ms: Long) = "%d:%02d".format(ms / 60_000, ms / 1000 % 60)

private fun Home.reveal() {
    val player = controller ?: return start(music())
    val options = ActivityOptions.makeBasic()
        .setPendingIntentBackgroundActivityStartMode(ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED)
        .toBundle()
    val sent = player.sessionActivity?.let { runCatching { it.send(this, 0, null, null, null, null, options) }.isSuccess } == true
    if (!sent) start(player.packageName)
}

fun Home.playerScreen(): Screen {
    val title = heading("")
    val cover = ImageView(this).apply { scaleType = ImageView.ScaleType.CENTER_CROP }
    val note = glyph("music", "fgMuted", 96)
    val art = object : FrameLayout(this) {
        override fun onMeasure(width: Int, height: Int) = super.onMeasure(width, width)
    }.apply {
        background = frame()
        setPadding(dp(2), dp(2), dp(2), dp(2))
        addView(cover, MATCH_PARENT, MATCH_PARENT)
        put(note)
    }
    val track = centred(20f, "fg").apply {
        isSingleLine = true
        ellipsize = TextUtils.TruncateAt.MARQUEE
        marqueeRepeatLimit = -1
        isSelected = true
    }
    val artist = centred(15f, "fgMuted").apply {
        maxLines = 1
        ellipsize = TextUtils.TruncateAt.END
    }
    val seek = Seek(this)
    val elapsed = text(12f, "fgMuted")
    val total = text(12f, "fgMuted")
    val toggle = glyph("play", "bgDim", 32)
    val play = press(
        FrameLayout(this).apply {
            setBackgroundColor(color("accent"))
            put(toggle)
        },
        0.9f,
    ) { playPause() }
    val prev = button(glyph("skip-back", "fg", 28)) { transport { it.skipToPrevious() } }
    val next = button(glyph("skip-forward", "fg", 28)) { transport { it.skipToNext() } }
    val controls = strip(
        prev,
        play.apply { layoutParams = LinearLayout.LayoutParams(dp(72), dp(72)).apply { marginStart = dp(36); marginEnd = dp(36) } },
        next,
    ).apply { gravity = Gravity.CENTER }
    val body = column(
        full(art).apply { layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { setMargins(dp(16), dp(8), dp(16), 0) } },
        track.below(28),
        artist.below(6),
        seek.apply { layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, dp(32)).apply { topMargin = dp(20) } },
        full(strip(elapsed, space(), total)),
        full(controls).below(20),
    ).apply { setPadding(0, 0, 0, dp(16)) }
    fun beat() {
        val (at, length) = position()
        seek.set(at, length)
        elapsed.text = minutes(at)
        total.text = if (length > 0) minutes(length) else ""
    }
    fun fill() {
        val player = controller
        val meta = player?.metadata
        val fallback = music()
        title.text = label(player?.packageName ?: fallback) ?: "music"
        val name = meta?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: if (fallback.isEmpty()) "pick a music app" else "nothing playing"
        if (track.text.toString() != name) track.text = name
        track.setTextColor(color(if (meta == null) "fgMuted" else "fg"))
        artist.text = meta?.getString(MediaMetadata.METADATA_KEY_ARTIST).orEmpty()
        val picture = artwork(meta)
        cover.setImageBitmap(picture)
        note.visibility = if (picture == null) View.VISIBLE else View.GONE
        mark(toggle, if (playing()) "pause" else "play", "bgDim")
        prev.alpha = if (player == null) 0.35f else 1f
        next.alpha = prev.alpha
        beat()
    }
    fill()
    return Screen(
        "player",
        surface(title, scroll(body), button(glyph("settings", "accent", 20)) { tunes() }, button(glyph("external-link", "accent", 20)) { reveal() }),
        ::fill,
        beat = ::beat,
    )
}

private fun Home.sample(theme: JSONObject, current: Boolean): View {
    val id = theme.getString("name")
    fun of(key: String) = Color.parseColor(theme.getString(key))
    val face = font(theme.optString("font"))
    fun ink(size: Float, key: String, value: String) = line(size, key, value).apply {
        setTextColor(of(key))
        typeface = face
    }
    val swatches = strip().apply {
        for (key in listOf("accent") + SWATCHES) addView(View(this@sample).apply { setBackgroundColor(of(key)) }, LinearLayout.LayoutParams(0, dp(10), 1f))
    }
    val card = column(
        strip(
            ink(15f, "fg", id).apply { layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f) },
            glyph("check", of("accent"), 18).apply { if (!current) visibility = View.INVISIBLE },
        ),
        ink(12f, "fgMuted", "Aa 0123").below(4),
        swatches.below(14),
    ).apply {
        background = GradientDrawable().apply {
            setColor(of("bgDim"))
            setStroke(dp(2), of(if (current) "accent" else "border"))
        }
        setPadding(dp(14), dp(12), dp(14), dp(14))
    }
    return press(card, 0.95f) { choose(id) }
}

fun Home.appearanceScreen(): Screen {
    val list = JSONArray(assets.open("themes.json").bufferedReader().use { it.readText() })
    val cards = HashMap<String, View>()
    val themes = column()
    for (pair in (0 until list.length()).map(list::getJSONObject).chunked(2)) {
        val views = pair.map { sample(it, it.getString("name") == name).also { card -> cards[it.getString("name")] = card } }
        themes.addView(row(*views.map { it to 1f }.toTypedArray(), *(if (views.size == 1) arrayOf(View(this) to 1f) else emptyArray())))
    }

    val sync = glyph("refresh-cw", "accent", 20)
    val syncing = button(sync) { wallpapers() }
    val note = text(13f, "error")
    val warn = strip(glyph("triangle-alert", "error", 16), note.after(8)).apply {
        visibility = View.GONE
        setPadding(dp(2), 0, 0, dp(8))
    }
    val rows = column()
    val cells = HashMap<String, ImageView>()
    var order = listOf<String>()
    val width = (resources.displayMetrics.widthPixels - dp(40)) / 3

    val pages = listOf(scroll(themes), column(warn, scroll(rows).apply { layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f) }))
    val holder = FrameLayout(this).apply { pages.forEach { addView(it, MATCH_PARENT, MATCH_PARENT) } }
    val tabs = LinearLayout(this)
    val labels = listOf("palette" to "theme", "image" to "wallpaper").map { (icon, label) ->
        Triple(column(), glyph(icon, "fgMuted", 18), text(13f, "fgMuted", label))
    }

    fun walls() {
        val saved = JSONArray(walls.getString("list", "[]"))
        val ids = List(saved.length(), saved::getString)
        val current = walls.getString("current", "")
        val status = walls.getString("status", "").orEmpty()
        busy(sync, status == "syncing")
        warn.visibility = if (status.isEmpty() || status == "syncing") View.GONE else View.VISIBLE
        note.text = status
        if (ids != order || ids.isEmpty()) {
            order = ids
            cells.clear()
            rows.removeAllViews()
            if (ids.isEmpty()) rows.addView(full(empty("image", if (status == "syncing") "fetching wallpapers" else "no wallpapers")))
            for (line in ids.chunked(3)) {
                rows.addView(
                    LinearLayout(this).apply {
                        for ((i, id) in line.withIndex()) {
                            val image = ImageView(this@appearanceScreen).apply { scaleType = ImageView.ScaleType.CENTER_CROP }
                            val badge = FrameLayout(this@appearanceScreen).apply {
                                setBackgroundColor(color("accent"))
                                setPadding(dp(3), dp(3), dp(3), dp(3))
                                put(glyph("check", "bgDim", 14))
                            }
                            val cell = FrameLayout(this@appearanceScreen).apply {
                                background = GradientDrawable().apply { setColor(color("bgAlt")) }
                                setPadding(dp(2), dp(2), dp(2), dp(2))
                                addView(image, MATCH_PARENT, MATCH_PARENT)
                                addView(badge, FrameLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT, Gravity.TOP or Gravity.END).apply { setMargins(0, dp(8), dp(8), 0) })
                            }
                            press(cell, 0.95f) { pick(id) }
                            cells[id] = image
                            addView(cell, LinearLayout.LayoutParams(width, width * 13 / 6).apply { if (i < 2) marginEnd = dp(8) })
                        }
                    },
                    LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { bottomMargin = dp(8) },
                )
            }
        }
        for (id in ids) {
            val image = cells[id] ?: continue
            val cell = image.parent as FrameLayout
            (cell.background as GradientDrawable).setStroke(dp(2), color(if (id == current) "accent" else "border"))
            cell.getChildAt(1).visibility = if (id == current) View.VISIBLE else View.GONE
            if (image.drawable == null) {
                val bitmap = thumb(id) ?: continue
                image.setImageBitmap(bitmap)
                image.alpha = 0f
                glide(image, 400).alpha(1f).start()
            }
        }
    }

    fun select(page: Int, direction: Int) {
        tab = page.coerceIn(0, 1)
        for ((i, view) in pages.withIndex()) view.visibility = if (i == tab) View.VISIBLE else View.GONE
        syncing.visibility = if (tab == 1) View.VISIBLE else View.INVISIBLE
        for ((i, parts) in labels.withIndex()) {
            val (cell, icon, label) = parts
            val on = i == tab
            mark(icon, if (i == 0) "palette" else "image", if (on) "accent" else "fgMuted")
            label.setTextColor(color(if (on) "accent" else "fgMuted"))
            cell.background = GradientDrawable().apply {
                setColor(if (on) fill("accent", 0x26) else fill("bgDim", 0xe0))
                setStroke(dp(2), color(if (on) "accent" else "border"))
            }
        }
        if (direction == 0) return
        val shown = pages[tab]
        shown.translationX = direction * dp(48).toFloat()
        shown.alpha = 0f
        glide(shown).translationX(0f).alpha(1f).start()
    }

    for ((i, parts) in labels.withIndex()) {
        val (cell, icon, label) = parts
        cell.addView(strip(icon, label.after(8)).apply { gravity = Gravity.CENTER })
        cell.setPadding(0, dp(10), 0, dp(10))
        press(cell, 0.96f) { if (tab != i) select(i, i - tab) }
        tabs.addView(cell, LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f).apply { if (i > 0) marginStart = dp(8) })
    }

    fun fill() {
        val waiting = pending()
        for ((id, card) in cards) busy(card, id == waiting)
        walls()
    }
    fill()
    select(tab, 0)
    return Screen(
        "appearance",
        surface(heading("appearance"), column(full(tabs), holder.apply { layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f).apply { topMargin = dp(12) } }), syncing),
        ::fill,
        { if (tab + it in 0..1) select(tab + it, it) },
    )
}
