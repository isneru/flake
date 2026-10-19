package dev.neru.bare

import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.Drawable

private val CODES = mapOf(
    "arrow-left" to 0xe048,
    "battery-charging" to 0xe054,
    "battery-full" to 0xe055,
    "battery-low" to 0xe056,
    "battery-medium" to 0xe057,
    "battery-warning" to 0xe3ac,
    "calendar" to 0xe063,
    "calendar-plus" to 0xe2bc,
    "calendar-range" to 0xe2bd,
    "check" to 0xe06c,
    "chevron-left" to 0xe06e,
    "chevron-right" to 0xe06f,
    "clock-3" to 0xe250,
    "cloud" to 0xe088,
    "cloud-drizzle" to 0xe08a,
    "cloud-fog" to 0xe214,
    "cloud-lightning" to 0xe08c,
    "cloud-moon" to 0xe215,
    "cloud-rain" to 0xe08e,
    "cloud-snow" to 0xe090,
    "cloud-sun" to 0xe216,
    "cpu" to 0xe0a9,
    "droplet" to 0xe0b4,
    "external-link" to 0xe0b9,
    "globe" to 0xe0e8,
    "hard-drive" to 0xe0ed,
    "image" to 0xe0f6,
    "info" to 0xe0f9,
    "layout-grid" to 0xe0ff,
    "locate-fixed" to 0xe1db,
    "map-pin" to 0xe111,
    "memory-stick" to 0xe445,
    "moon" to 0xe11e,
    "music" to 0xe122,
    "palette" to 0xe1dd,
    "pause" to 0xe12e,
    "pin" to 0xe259,
    "pin-off" to 0xe2b6,
    "play" to 0xe13c,
    "refresh-cw" to 0xe145,
    "search" to 0xe151,
    "settings" to 0xe154,
    "skip-back" to 0xe15f,
    "skip-forward" to 0xe160,
    "smartphone" to 0xe163,
    "square-terminal" to 0xe20a,
    "sun" to 0xe178,
    "thermometer" to 0xe186,
    "trash-2" to 0xe18e,
    "triangle-alert" to 0xe193,
    "usb" to 0xe356,
    "wind" to 0xe1b0,
    "x" to 0xe1b2,
)

class Glyph(name: String, face: Typeface) : Drawable() {
    private val code = String(Character.toChars(CODES.getValue(name)))
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = face
        textAlign = Paint.Align.CENTER
    }

    override fun draw(canvas: Canvas) {
        paint.textSize = minOf(bounds.width(), bounds.height()).toFloat()
        val metrics = paint.fontMetrics
        canvas.drawText(code, bounds.exactCenterX(), bounds.exactCenterY() - (metrics.ascent + metrics.descent) / 2, paint)
    }

    override fun setAlpha(alpha: Int) {
        paint.alpha = alpha
    }

    override fun setColorFilter(filter: ColorFilter?) {
        paint.colorFilter = filter
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity() = PixelFormat.TRANSLUCENT
}
