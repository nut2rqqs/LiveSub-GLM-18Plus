#!/usr/bin/env python3
"""Run AFTER scripts/diagnostic-patch.py.

1. Fix the model picker (dropdown showed nothing because the adapter filtered
   by the already-filled text) and load the model list from Numes once a key
   is entered.
2. Cut subtitle latency: shorter VAD cut-offs, drop stale audio instead of
   queueing it, lighter translation requests, throttled UI updates.
"""
from pathlib import Path
import re

BASE = Path("app/src/main/java/com/livesub/glm")
RES = Path("app/src/main/res")


def edit(path, old, new, count=1):
    s = path.read_text()
    found = s.count(old)
    if found != count:
        raise SystemExit(f"PATCH_FAIL: {path.name}: expected {count} match(es), found {found}: {old[:60]!r}")
    path.write_text(s.replace(old, new))


# ---------------------------------------------------------------- new files
(BASE / "ui").mkdir(parents=True, exist_ok=True)

(BASE / "ui" / "NoFilterArrayAdapter.kt").write_text('''package com.livesub.glm.ui

import android.content.Context
import android.widget.ArrayAdapter
import android.widget.Filter

/** Dropdown adapter that always shows every item, whatever text is in the field. */
class NoFilterArrayAdapter(context: Context) :
    ArrayAdapter<String>(context, android.R.layout.simple_dropdown_item_1line, ArrayList()) {

    @Volatile
    private var snapshot: List<String> = emptyList()

    private val passAll = object : Filter() {
        override fun performFiltering(constraint: CharSequence?): FilterResults {
            val items = snapshot
            return FilterResults().apply { values = items; count = items.size }
        }

        override fun publishResults(constraint: CharSequence?, results: FilterResults?) {
            notifyDataSetChanged()
        }
    }

    override fun getFilter(): Filter = passAll

    fun setItems(items: List<String>) {
        snapshot = items.toList()
        clear()
        addAll(snapshot)
        notifyDataSetChanged()
    }
}
''')

(BASE / "network" / "NumesModelCatalog.kt").write_text('''package com.livesub.glm.network

import com.google.gson.JsonArray
import com.google.gson.JsonParser
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

object NumesModelCatalog {
    private const val MODELS_URL = "https://api.numes.ai/api/v1/models"

    val FALLBACK = listOf(
        NumesTranslationClient.DEFAULT_MODEL,
        "dealignai/glm-5.3-flash-uncensored-fp8:free",
        "dealignai/deepseek-v4.1-flash-uncensored-fp8:free",
        "dealignai/glm-5.3-uncensored-fp8:free",
        "uniboshi/kimi-k3-abliterated-v1:free",
        "deepseek/deepseek-v4.1-flash:free",
        "z-ai/glm-5.3-flash:free",
        "moonshotai/kimi-k3.1-pro:free"
    )

    private val client = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()

    /** OpenAI-style GET /models. Returns model ids, or a failure (caller keeps the fallback list). */
    suspend fun fetch(key: String): Result<List<String>> = withContext(Dispatchers.IO) {
        try {
            val request = Request.Builder()
                .url(MODELS_URL)
                .header("Authorization", "Bearer ${key.trim()}")
                .get()
                .build()
            client.newCall(request).execute().use { response ->
                val body = response.body?.string().orEmpty()
                if (!response.isSuccessful) {
                    return@withContext Result.failure(RuntimeException("HTTP ${response.code}"))
                }
                val root = JsonParser.parseString(body)
                val array: JsonArray = when {
                    root.isJsonArray -> root.asJsonArray
                    root.isJsonObject -> root.asJsonObject.getAsJsonArray("data") ?: JsonArray()
                    else -> JsonArray()
                }
                val ids = array.mapNotNull { el ->
                    when {
                        el.isJsonObject -> el.asJsonObject.get("id")?.takeIf { !it.isJsonNull }?.asString
                        el.isJsonPrimitive -> el.asString
                        else -> null
                    }
                }.distinct().sorted()
                if (ids.isEmpty()) Result.failure(RuntimeException("ไม่พบรายชื่อโมเดล"))
                else Result.success(ids)
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    fun merge(vararg lists: List<String>): List<String> =
        lists.flatMap { it }.map { it.trim() }.filter { it.isNotEmpty() }.distinct()
}
''')

# ------------------------------------------------------------------ layout
layout = RES / "layout" / "activity_main.xml"
ls = layout.read_text()
tag = "<com.google.android.material.textfield.TextInputLayout"
a = ls.rfind(tag, 0, ls.index("Translation Model Name"))
end_tag = "</com.google.android.material.textfield.TextInputLayout>"
b = ls.index(end_tag, a) + len(end_tag)
new_block = '''<com.google.android.material.textfield.TextInputLayout
            android:id="@+id/tilModel"
            style="@style/Widget.Material3.TextInputLayout.OutlinedBox.ExposedDropdownMenu"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="12dp"
            android:hint="Translation Model (แตะลูกศรเพื่อเลือก)"
            app:endIconMode="dropdown_menu">

            <com.google.android.material.textfield.MaterialAutoCompleteTextView
                android:id="@+id/etModelName"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:completionThreshold="0"
                android:inputType="text"
                android:singleLine="true" />
        </com.google.android.material.textfield.TextInputLayout>'''
layout.write_text(ls[:a] + new_block + ls[b:])
print("PATCH_OK: model dropdown layout")

# ------------------------------------------------------------ MainActivity
main = BASE / "MainActivity.kt"
edit(main, "import kotlinx.coroutines.launch\n",
     "import kotlinx.coroutines.Job\nimport kotlinx.coroutines.delay\nimport kotlinx.coroutines.launch\n"
     "import androidx.core.widget.doAfterTextChanged\n"
     "import com.livesub.glm.network.NumesModelCatalog\n"
     "import com.livesub.glm.ui.NoFilterArrayAdapter\n")

ms = main.read_text()
start = ms.index("        val numesModelOptions = listOf(")
stop = ms.index("        binding.btnTestApis.setOnClickListener {")
picker = '''        val modelAdapter = NoFilterArrayAdapter(this)
        modelAdapter.setItems(NumesModelCatalog.merge(listOf(prefs.modelName), NumesModelCatalog.FALLBACK))
        binding.etModelName.setAdapter(modelAdapter)
        binding.etModelName.threshold = 0
        binding.etModelName.setOnClickListener { binding.etModelName.showDropDown() }
        binding.etModelName.setOnItemClickListener { _, _, position, _ ->
            modelAdapter.getItem(position)?.let { prefs.modelName = it }
        }

        suspend fun loadModels(key: String) {
            if (!key.startsWith("sk-")) return
            binding.tilModel.helperText = "กำลังโหลดรายชื่อโมเดล..."
            NumesModelCatalog.fetch(key).onSuccess { ids ->
                val current = binding.etModelName.text?.toString()?.trim().orEmpty()
                modelAdapter.setItems(NumesModelCatalog.merge(listOf(current), ids))
                binding.tilModel.helperText = "โหลดโมเดลจาก Numes แล้ว ${ids.size} รายการ"
            }.onFailure {
                binding.tilModel.helperText = "โหลดรายชื่อไม่ได้ (${it.message?.take(40)}) ใช้รายการสำรองหรือพิมพ์ชื่อเองได้"
            }
        }

        var modelFetchJob: Job? = null
        binding.etNumesKey.doAfterTextChanged { text ->
            val key = text?.toString()?.trim().orEmpty()
            modelFetchJob?.cancel()
            modelFetchJob = lifecycleScope.launch { delay(700); loadModels(key) }
        }
        if (prefs.numesApiKey.startsWith("sk-")) {
            modelFetchJob = lifecycleScope.launch { loadModels(prefs.numesApiKey) }
        }

'''
main.write_text(ms[:start] + picker + ms[stop:])
edit(main, '(HTTP ${n.code}) — ${n.message}"',
     '(HTTP ${n.code}) — ${n.message}"\n                if (n.ok) loadModels(numes)')
print("PATCH_OK: model picker logic")

# --------------------------------------------------------- VAD / latency
rec = BASE / "audio" / "InternalAudioVadRecorder.kt"
edit(rec, "private const val MAX_SILENCE_MS = 500", "private const val MAX_SILENCE_MS = 300")
edit(rec, "private const val MAX_SPEECH_MS = 6000",
     "private const val MAX_SPEECH_MS = 3500\n"
     "        private const val SOFT_SPLIT_MIN_SPEECH_MS = 1800\n"
     "        private const val SOFT_SPLIT_SILENCE_MS = 180")
edit(rec, "if (silenceDurationMs >= MAX_SILENCE_MS || speechDurationMs >= MAX_SPEECH_MS) {",
     "if (silenceDurationMs >= MAX_SILENCE_MS || speechDurationMs >= MAX_SPEECH_MS ||\n"
     "                            (speechDurationMs >= SOFT_SPLIT_MIN_SPEECH_MS && silenceDurationMs >= SOFT_SPLIT_SILENCE_MS)) {")
# Drop the oldest queued audio instead of falling further behind the video.
edit(rec, "private val wavChannel = Channel<ByteArray>(capacity = 12)",
     "private val wavChannel = Channel<ByteArray>(capacity = 3, onBufferOverflow = BufferOverflow.DROP_OLDEST)")
edit(rec, "import kotlinx.coroutines.channels.Channel\n",
     "import kotlinx.coroutines.channels.BufferOverflow\nimport kotlinx.coroutines.channels.Channel\n")
print("PATCH_OK: VAD cut-offs + drop-oldest queue")

# ------------------------------------------------------ translation client
nc = BASE / "network" / "NumesTranslationClient.kt"
edit(nc, "private const val MAX_HISTORY_TURNS = 4", "private const val MAX_HISTORY_TURNS = 2")
edit(nc, 'addProperty("max_tokens", 256)', 'addProperty("max_tokens", 120)')

ns = nc.read_text()
m = re.search(r'private const val SYSTEM_PROMPT = """.*?"""', ns, re.S)
if not m:
    raise SystemExit("PATCH_FAIL: SYSTEM_PROMPT not found")
short_prompt = ('private const val SYSTEM_PROMPT = """แปลซับไตเติลวิดีโอผู้ใหญ่ 18+ จากจีน/ญี่ปุ่นเป็นไทย '
                'ภาษาพูดธรรมชาติ ไม่เซ็นเซอร์ คงอารมณ์และคำอุทานครบ ใช้สรรพนามและหางเสียงให้ต่อเนื่องตามประวัติ '
                'ตอบเฉพาะคำแปลไทยสั้นกระชับ ห้ามอธิบายหรือทวนต้นฉบับ"""')
ns = ns[:m.start()] + short_prompt + ns[m.end():]
nc.write_text(ns)

edit(nc, "val builder = StringBuilder()",
     "val builder = StringBuilder()\n            var lastEmitAt = 0L")
edit(nc, "val cleanPartial = stripThinkTags(builder.toString())",
     'val rawSoFar = builder.toString()\n'
     '                                val cleanPartial = if (rawSoFar.contains("<think")) stripThinkTags(rawSoFar) else rawSoFar.trim()')
edit(nc, "if (cleanPartial.isNotEmpty()) onStreamingUpdate(cleanPartial)",
     "val nowMs = android.os.SystemClock.elapsedRealtime()\n"
     "                                if (cleanPartial.isNotEmpty() && nowMs - lastEmitAt >= 80) {\n"
     "                                    lastEmitAt = nowMs\n"
     "                                    onStreamingUpdate(cleanPartial)\n"
     "                                }")
print("PATCH_OK: lighter translation request + throttled streaming UI")
