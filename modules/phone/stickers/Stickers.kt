package dev.neru.stickers

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.res.AssetFileDescriptor
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import org.json.JSONObject

const val AUTHORITY = "dev.neru.stickers.provider"

class Pack(val id: String, val name: String, val stickers: List<String>)

class Contents(val version: String, val packs: List<Pack>)

fun load(context: Context): Contents {
    val json = JSONObject(context.assets.open("contents.json").bufferedReader().use { it.readText() })
    val packs = json.getJSONArray("packs")
    return Contents(
        json.getString("version"),
        (0 until packs.length()).map { i ->
            val pack = packs.getJSONObject(i)
            val stickers = pack.getJSONArray("stickers")
            Pack(pack.getString("id"), pack.getString("name"), (0 until stickers.length()).map { stickers.getString(it) })
        },
    )
}

class Provider : ContentProvider() {
    private val contents by lazy { load(requireContext()) }

    override fun onCreate() = true

    private fun pack(id: String) = contents.packs.firstOrNull { it.id == id }

    override fun query(uri: Uri, projection: Array<String>?, selection: String?, args: Array<String>?, order: String?): Cursor? {
        val path = uri.pathSegments
        return when {
            path == listOf("metadata") -> metadata(contents.packs)
            path.size == 2 && path[0] == "metadata" -> metadata(listOfNotNull(pack(path[1])))
            path.size == 2 && path[0] == "stickers" -> stickers(pack(path[1]))
            else -> null
        }
    }

    private fun metadata(packs: List<Pack>) =
        MatrixCursor(
            arrayOf(
                "sticker_pack_identifier",
                "sticker_pack_name",
                "sticker_pack_publisher",
                "sticker_pack_icon",
                "android_play_store_link",
                "ios_app_download_link",
                "sticker_pack_publisher_email",
                "sticker_pack_publisher_website",
                "sticker_pack_privacy_policy_website",
                "sticker_pack_license_agreement_website",
                "image_data_version",
                "whatsapp_will_not_cache_stickers",
                "animated_sticker_pack",
            ),
        ).apply {
            packs.forEach { addRow(arrayOf<Any>(it.id, it.name, "neru", "tray.png", "", "", "", "", "", "", contents.version, 0, 1)) }
        }

    private fun stickers(pack: Pack?) =
        MatrixCursor(arrayOf("sticker_file_name", "sticker_emoji", "sticker_accessibility_text")).apply {
            pack?.stickers?.forEach { addRow(arrayOf<Any>(it, "⭐", "")) }
        }

    override fun openAssetFile(uri: Uri, mode: String): AssetFileDescriptor? {
        val path = uri.pathSegments
        if (path.size != 3 || path[0] != "stickers_asset") return null
        val pack = pack(path[1]) ?: return null
        if (path[2] != "tray.png" && path[2] !in pack.stickers) return null
        return requireContext().assets.openFd("${pack.id}/${path[2]}")
    }

    override fun getType(uri: Uri): String? {
        val path = uri.pathSegments
        return when (path.firstOrNull()) {
            "metadata" -> if (path.size == 1) "vnd.android.cursor.dir/vnd.$AUTHORITY.metadata" else "vnd.android.cursor.item/vnd.$AUTHORITY.metadata"
            "stickers" -> "vnd.android.cursor.dir/vnd.$AUTHORITY.stickers"
            "stickers_asset" -> if (path.last().endsWith(".png")) "image/png" else "image/webp"
            else -> null
        }
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = throw UnsupportedOperationException()

    override fun delete(uri: Uri, selection: String?, args: Array<String>?): Int = throw UnsupportedOperationException()

    override fun update(uri: Uri, values: ContentValues?, selection: String?, args: Array<String>?): Int = throw UnsupportedOperationException()
}

class Main : Activity() {
    private lateinit var status: TextView

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        status = TextView(this)
        val list = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 48, 48, 48)
            addView(status)
        }
        load(this).packs.forEach { pack ->
            list.addView(
                Button(this).apply {
                    text = "${pack.name} · ${pack.stickers.size}"
                    setOnClickListener { add(pack) }
                },
            )
        }
        setContentView(
            ScrollView(this).apply {
                fitsSystemWindows = true
                addView(list)
            },
        )
    }

    private fun add(pack: Pack) {
        val intent = Intent("com.whatsapp.intent.action.ENABLE_STICKER_PACK")
            .putExtra("sticker_pack_id", pack.id)
            .putExtra("sticker_pack_authority", AUTHORITY)
            .putExtra("sticker_pack_name", pack.name)
            .setPackage("com.whatsapp")
        try {
            startActivityForResult(intent, 1)
        } catch (e: ActivityNotFoundException) {
            status.text = "WhatsApp is not installed"
        }
    }

    override fun onActivityResult(request: Int, result: Int, data: Intent?) {
        status.text = if (result == RESULT_OK) "added" else data?.getStringExtra("validation_error") ?: "not added"
    }
}
