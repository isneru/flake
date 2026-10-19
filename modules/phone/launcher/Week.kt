package dev.neru.bare

import android.Manifest
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.provider.CalendarContract
import android.text.TextPaint
import android.text.TextUtils
import android.text.format.DateFormat
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import kotlin.math.ceil
import kotlin.math.sign

private val LECTURE = Regex("^(PL|TP|T) - (\\S+) - (.+)$")
private val HEAD = DateTimeFormatter.ofPattern("EEE d")
private val SHORT = DateTimeFormatter.ofPattern("d MMM")

private fun utc(ms: Long) = Instant.ofEpochMilli(ms).atZone(ZoneOffset.UTC).toLocalDate()

class Event(val id: Long, val begin: Long, val end: Long, val title: String, val place: String, val note: String, val allDay: Boolean) {
    var lane = 0
    var lanes = 1

    fun label(): String {
        val (kind, code) = LECTURE.find(title)?.destructured ?: return title
        return "$code · $kind"
    }

    fun where(): String {
        val lecture = LECTURE.find(title) ?: return place
        return listOf(place.ifBlank { lecture.groupValues[3] }, note.lineSequence().first().trim()).filter(String::isNotBlank).joinToString(" · ")
    }

    fun on(day: LocalDate) =
        if (allDay) utc(begin) <= day && day < maxOf(utc(end), utc(begin).plusDays(1)) else Instant.ofEpochMilli(begin).atZone(ZoneId.systemDefault()).toLocalDate() == day
}

fun Home.events(from: Long, to: Long): List<Event> {
    if (checkSelfPermission(Manifest.permission.READ_CALENDAR) != PackageManager.PERMISSION_GRANTED) return emptyList()
    val range = CalendarContract.Instances.CONTENT_URI.buildUpon()
    ContentUris.appendId(range, from)
    ContentUris.appendId(range, to)
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
    return found
}

fun Home.visit(event: Event) {
    startActivity(
        Intent(Intent.ACTION_VIEW, ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, event.id))
            .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, event.begin)
            .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, event.end),
    )
}

class Week(private val home: Home) : View(home) {
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
        home,
        object : GestureDetector.SimpleOnGestureListener() {
            override fun onDown(e: MotionEvent) = true

            override fun onSingleTapUp(e: MotionEvent): Boolean {
                hits.lastOrNull { it.first.contains(e.x, e.y) }?.let { home.visit(it.second) }
                return true
            }
        },
    )

    override fun onTouchEvent(event: MotionEvent) = taps.onTouchEvent(event)

    fun show(start: LocalDate, events: List<Event>) {
        monday = start
        val days = List(7) { start.plusDays(it.toLong()) }
        timed = days.map { day -> events.filter { !it.allDay && it.on(day) }.also(::lanes) }
        whole = days.map { day -> events.filter { it.allDay && it.on(day) } }
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
        val span = "${DateFormat.format("HH:mm", event.begin)}–${DateFormat.format("HH:mm", event.end)}"
        return listOf(event.label() to "fg", event.where() to "fgDim", span to "fgMuted")
    }

    private fun block(canvas: Canvas, box: RectF, event: Event, text: List<Pair<String, String>>, now: Long) {
        val over = event.end <= now
        val tint = home.color(if (over) "fgMuted" else if (event.begin <= now) "success" else "accent")
        val fade = if (over) 0x99 else 0xff
        paint.color = tint and 0xffffff or (0x2e * fade / 0xff shl 24)
        canvas.drawRect(box, paint)
        paint.color = tint and 0xffffff or (fade shl 24)
        canvas.drawRect(box.left, box.top, box.left + home.dp(3), box.bottom, paint)
        canvas.save()
        canvas.clipRect(box)
        var y = box.top + home.dp(3)
        for ((i, line) in text.filter { it.first.isNotBlank() }.withIndex()) {
            paint.textSize = home.sp(if (i == 2) 9f else 10f)
            paint.isFakeBoldText = i == 0
            val height = paint.descent() - paint.ascent()
            if (i > 0 && y + height > box.bottom) break
            paint.color = home.color(line.second) and 0xffffff or (fade shl 24)
            val fit = TextUtils.ellipsize(line.first, paint, box.width() - home.dp(9), TextUtils.TruncateAt.END)
            canvas.drawText(fit.toString(), box.left + home.dp(6), y - paint.ascent(), paint)
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
        val gutter = home.dp(36).toFloat()
        val header = home.dp(24).toFloat()
        val stacked = (0 until count).maxOf { whole[it].size }
        val top = header + stacked * home.dp(18) + if (stacked > 0) home.dp(4) else 0
        val column = (width - gutter) / count
        val hour = (height - top - home.dp(8)) / (last - first)
        paint.typeface = home.face
        paint.textAlign = Paint.Align.LEFT
        paint.textSize = home.sp(10f)
        for (h in first..last) {
            val y = top + (h - first) * hour
            paint.color = home.fill("border", 0x99)
            canvas.drawRect(gutter, y, width.toFloat(), y + 1, paint)
            paint.color = home.color("fgMuted")
            canvas.drawText("%02d:00".format(h), 0f, y - (paint.ascent() + paint.descent()) / 2, paint)
        }
        for (i in 0 until count) {
            val day = monday.plusDays(i.toLong())
            val x = gutter + i * column
            val current = day == today
            if (current) {
                paint.color = home.fill("accent", 0x0d)
                canvas.drawRect(x, header, x + column, height.toFloat(), paint)
            }
            paint.textSize = home.sp(11f)
            paint.textAlign = Paint.Align.CENTER
            paint.isFakeBoldText = current
            paint.color = home.color(if (current) "accent" else "fgMuted")
            canvas.drawText(day.format(HEAD).lowercase(), x + column / 2, header / 2 - (paint.ascent() + paint.descent()) / 2, paint)
            paint.textAlign = Paint.Align.LEFT
            paint.isFakeBoldText = false
            whole[i].forEachIndexed { k, event ->
                val y = header + k * home.dp(18)
                block(canvas, RectF(x + home.dp(2), y, x + column - home.dp(2), y + home.dp(16)), event, listOf(event.title to "fg"), now)
            }
            for (event in timed[i]) {
                val lane = (column - home.dp(4)) / event.lanes
                val left = x + home.dp(2) + event.lane * lane
                val y = top + (hours(event.begin, day) - first) * hour + home.dp(1)
                val tall = maxOf(home.dp(18).toFloat(), (hours(event.end, day) - hours(event.begin, day)) * hour - home.dp(2))
                val right = left + lane - if (event.lane < event.lanes - 1) home.dp(2) else 0
                block(canvas, RectF(left, y, right, y + tall), event, lines(event), now)
            }
            val at = hours(now, day)
            if (current && at >= first && at <= last) {
                val y = top + (at - first) * hour
                paint.color = home.color("error")
                canvas.drawRect(x, y, x + column, y + home.dp(2), paint)
            }
        }
    }
}

fun Home.weekScreen(): Screen {
    val planner = Week(this)
    val title = heading("")
    val today = glyph("locate-fixed", "accent", 20)
    fun page(target: Int, direction: Int) {
        shift = target
        val zone = ZoneId.systemDefault()
        val monday = LocalDate.now().with(DayOfWeek.MONDAY).plusWeeks(shift.toLong())
        planner.show(monday, events(monday.minusDays(1).atStartOfDay(zone).toInstant().toEpochMilli(), monday.plusDays(8).atStartOfDay(zone).toInstant().toEpochMilli()))
        title.text = "${monday.format(SHORT)} – ${monday.plusDays(planner.count - 1L).format(SHORT)}".lowercase()
        mark(today, "locate-fixed", if (shift == 0) "fgMuted" else "accent")
        if (direction == 0) return
        planner.translationX = direction * dp(64).toFloat()
        planner.alpha = 0f
        glide(planner).translationX(0f).alpha(1f).start()
    }
    page(shift, 0)
    return Screen(
        "week",
        surface(
            title,
            planner,
            button(glyph("chevron-left", "accent", 22)) { page(shift - 1, -1) },
            button(today) { if (shift != 0) page(0, -shift.sign) },
            button(glyph("chevron-right", "accent", 22)) { page(shift + 1, 1) },
        ),
        { planner.invalidate() },
        { page(shift + it, it) },
    )
}
