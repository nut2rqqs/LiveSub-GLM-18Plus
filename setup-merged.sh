#!/usr/bin/env bash
set -euo pipefail

echo "Deploying LiveSub GLM 18+ project files..."
mkdir -p "$(dirname .gitignore)"
cat << 'FILE_EOF' > .gitignore
.gradle/
build/
app/build/
local.properties
*.iml
.idea/
.DS_Store
*.apk
*.aab
FILE_EOF

mkdir -p "$(dirname .github/workflows/build.yml)"
cat << 'FILE_EOF' > .github/workflows/build.yml
name: Android CI Build APK

on:
  push:
    branches: [ "main", "master" ]
  pull_request:
    branches: [ "main", "master" ]
  workflow_dispatch:

jobs:
  build-debug-apk:
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - name: Checkout Source Code
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Set up Android SDK
        uses: android-actions/setup-android@v3

      - name: Accept Android SDK Licenses & Install SDK 34
        run: |
          yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses || true
          $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

      - name: Setup Gradle 8.7
        uses: gradle/actions/setup-gradle@v4
        with:
          gradle-version: '8.7'

      - name: Build Debug APK
        env:
          GROQ_API_KEY: ${{ secrets.GROQ_API_KEY }}
          NUMES_API_KEY: ${{ secrets.NUMES_API_KEY }}
        run: gradle assembleDebug --no-daemon --stacktrace

      - name: Upload app-debug.apk Artifact
        uses: actions/upload-artifact@v4
        with:
          name: app-debug
          path: app/build/outputs/apk/debug/app-debug.apk
          if-no-files-found: error
          retention-days: 14
FILE_EOF

mkdir -p "$(dirname settings.gradle.kts)"
cat << 'FILE_EOF' > settings.gradle.kts
pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "LiveSubGLM"
include(":app")
FILE_EOF

mkdir -p "$(dirname build.gradle.kts)"
cat << 'FILE_EOF' > build.gradle.kts
plugins {
    id("com.android.application") version "8.5.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}
FILE_EOF

mkdir -p "$(dirname gradle.properties)"
cat << 'FILE_EOF' > gradle.properties
org.gradle.jvmargs=-Xmx3072m -Dfile.encoding=UTF-8
org.gradle.parallel=true
org.gradle.caching=true
android.useAndroidX=true
android.nonTransitiveRClass=true
kotlin.code.style=official
FILE_EOF

mkdir -p "$(dirname app/build.gradle.kts)"
cat << 'FILE_EOF' > app/build.gradle.kts
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

fun escapeForBuildConfig(value: String?): String {
    val safe = (value ?: "").replace("\\", "\\\\").replace("\"", "\\\"")
    return "\"$safe\""
}

android {
    namespace = "com.livesub.glm"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.livesub.glm"
        minSdk = 29
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"

        buildConfigField("String", "DEFAULT_GROQ_API_KEY", escapeForBuildConfig(System.getenv("GROQ_API_KEY")))
        buildConfigField("String", "DEFAULT_NUMES_API_KEY", escapeForBuildConfig(System.getenv("NUMES_API_KEY")))
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        viewBinding = true
        buildConfig = true
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-ktx:1.9.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.4")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.google.code.gson:gson:2.11.0")
}
FILE_EOF

mkdir -p "$(dirname app/proguard-rules.pro)"
cat << 'FILE_EOF' > app/proguard-rules.pro
-keepattributes Signature, InnerClasses, EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class com.livesub.glm.network.** { *; }
FILE_EOF

mkdir -p "$(dirname app/src/main/AndroidManifest.xml)"
cat << 'FILE_EOF' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />

    <application
        android:allowBackup="false"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:supportsRtl="true"
        android:theme="@style/Theme.LiveSubGLM"
        android:usesCleartextTraffic="false">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service
            android:name=".service.LiveSubCaptureService"
            android:enabled="true"
            android:exported="false"
            android:foregroundServiceType="mediaProjection" />

    </application>

</manifest>
FILE_EOF

mkdir -p "$(dirname app/src/main/java/com/livesub/glm/audio/WavEncoder.kt)"
cat << 'FILE_EOF' > app/src/main/java/com/livesub/glm/audio/WavEncoder.kt
package com.livesub.glm.audio

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

object WavEncoder {
    private const val SAMPLE_RATE = 16000
    private const val CHANNELS = 1
    private const val BITS_PER_SAMPLE = 16

    fun pcmToWavBytes(pcmData: ByteArray): ByteArray {
        val byteRate = SAMPLE_RATE * CHANNELS * BITS_PER_SAMPLE / 8
        val blockAlign = (CHANNELS * BITS_PER_SAMPLE / 8).toShort()
        val dataSize = pcmData.size
        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN).apply {
            put("RIFF".toByteArray(Charsets.US_ASCII))
            putInt(36 + dataSize)
            put("WAVE".toByteArray(Charsets.US_ASCII))
            put("fmt ".toByteArray(Charsets.US_ASCII))
            putInt(16)
            putShort(1)
            putShort(CHANNELS.toShort())
            putInt(SAMPLE_RATE)
            putInt(byteRate)
            putShort(blockAlign)
            putShort(BITS_PER_SAMPLE.toShort())
            put("data".toByteArray(Charsets.US_ASCII))
            putInt(dataSize)
        }.array()

        return ByteArrayOutputStream(44 + dataSize).use { out ->
            out.write(header)
            out.write(pcmData)
            out.toByteArray()
        }
    }
}
FILE_EOF

mkdir -p "$(dirname app/src/main/java/com/livesub/glm/audio/InternalAudioVadRecorder.kt)"
cat << 'FILE_EOF' > app/src/main/java/com/livesub/glm/audio/InternalAudioVadRecorder.kt
package com.livesub.glm.audio

import android.annotation.SuppressLint
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.ByteArrayOutputStream
import kotlin.math.sqrt

class InternalAudioVadRecorder(
    private val mediaProjection: MediaProjection,
    private val scope: CoroutineScope,
    private val onWavChunkReady: suspend (ByteArray) -> Unit,
    private val onError: (String) -> Unit
) {
    companion object {
        private const val SAMPLE_RATE = 16000
        private const val FRAME_MS = 20
        private const val SAMPLES_PER_FRAME = (SAMPLE_RATE * FRAME_MS) / 1000
        private const val BYTES_PER_FRAME = SAMPLES_PER_FRAME * 2
        private const val MAX_SILENCE_MS = 500
        private const val MAX_SPEECH_MS = 6000
        private const val MIN_VALID_VOICE_MS = 140
        private const val PRE_ROLL_FRAMES = 12
        private const val VAD_RMS_THRESHOLD = 300.0
    }

    private var audioRecord: AudioRecord? = null
    private var captureJob: Job? = null
    private var consumerJob: Job? = null
    private val wavChannel = Channel<ByteArray>(capacity = 6)

    @SuppressLint("MissingPermission")
    fun start() {
        if (captureJob?.isActive == true) return

        val captureConfig = AudioPlaybackCaptureConfiguration.Builder(mediaProjection)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
            .build()

        val audioFormat = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .setSampleRate(SAMPLE_RATE)
            .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
            .build()

        val minBufSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        ).coerceAtLeast(BYTES_PER_FRAME * 8)

        val record = try {
            AudioRecord.Builder()
                .setAudioFormat(audioFormat)
                .setBufferSizeInBytes(minBufSize * 2)
                .setAudioPlaybackCaptureConfig(captureConfig)
                .build()
        } catch (e: Exception) {
            onError("สร้าง AudioPlaybackCapture ไม่สำเร็จ: ${e.message}")
            return
        }

        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            onError("AudioRecord ไม่พร้อมทำงาน กรุณาตรวจสอบสิทธิ์เสียง")
            return
        }

        audioRecord = record
        record.startRecording()

        consumerJob = scope.launch(Dispatchers.IO) {
            for (wavBytes in wavChannel) {
                if (!isActive) break
                onWavChunkReady(wavBytes)
            }
        }

        captureJob = scope.launch(Dispatchers.Default) {
            val shortBuffer = ShortArray(SAMPLES_PER_FRAME)
            val preRollQueue = ArrayDeque<ByteArray>(PRE_ROLL_FRAMES)
            val activeSpeechStream = ByteArrayOutputStream()
            var isSpeaking = false
            var silenceDurationMs = 0
            var speechDurationMs = 0
            var voicedFramesMs = 0

            try {
                while (isActive) {
                    val readCount = record.read(shortBuffer, 0, SAMPLES_PER_FRAME)
                    if (readCount <= 0) continue

                    val rms = calculateRms(shortBuffer, readCount)
                    val frameBytes = shortsToLittleEndianBytes(shortBuffer, readCount)
                    val isVoiceFrame = rms >= VAD_RMS_THRESHOLD

                    if (!isSpeaking) {
                        if (preRollQueue.size >= PRE_ROLL_FRAMES) preRollQueue.removeFirst()
                        preRollQueue.addLast(frameBytes)

                        if (isVoiceFrame) {
                            isSpeaking = true
                            silenceDurationMs = 0
                            speechDurationMs = FRAME_MS
                            voicedFramesMs = FRAME_MS
                            activeSpeechStream.reset()
                            for (preFrame in preRollQueue) activeSpeechStream.write(preFrame)
                            preRollQueue.clear()
                        }
                    } else {
                        activeSpeechStream.write(frameBytes)
                        speechDurationMs += FRAME_MS

                        if (isVoiceFrame) {
                            silenceDurationMs = 0
                            voicedFramesMs += FRAME_MS
                        } else {
                            silenceDurationMs += FRAME_MS
                        }

                        if (silenceDurationMs >= MAX_SILENCE_MS || speechDurationMs >= MAX_SPEECH_MS) {
                            if (voicedFramesMs >= MIN_VALID_VOICE_MS) {
                                val wavBytes = WavEncoder.pcmToWavBytes(activeSpeechStream.toByteArray())
                                wavChannel.trySend(wavBytes)
                            }
                            activeSpeechStream.reset()
                            isSpeaking = false
                            silenceDurationMs = 0
                            speechDurationMs = 0
                            voicedFramesMs = 0
                        }
                    }
                }
            } catch (e: Exception) {
                if (isActive) onError("อ่านเสียงผิดพลาด: ${e.message}")
            }
        }
    }

    fun stop() {
        captureJob?.cancel()
        consumerJob?.cancel()
        captureJob = null
        consumerJob = null
        try {
            audioRecord?.let { rec ->
                if (rec.recordingState == AudioRecord.RECORDSTATE_RECORDING) rec.stop()
                rec.release()
            }
        } catch (_: Exception) {
        } finally {
            audioRecord = null
        }
    }

    private fun calculateRms(buffer: ShortArray, length: Int): Double {
        var sumSquares = 0.0
        for (i in 0 until length) {
            val s = buffer[i].toDouble()
            sumSquares += s * s
        }
        return sqrt(sumSquares / length)
    }

    private fun shortsToLittleEndianBytes(buffer: ShortArray, length: Int): ByteArray {
        val out = ByteArray(length * 2)
        var idx = 0
        for (i in 0 until length) {
            val s = buffer[i].toInt()
            out[idx++] = (s and 0xFF).toByte()
            out[idx++] = ((s shr 8) and 0xFF).toByte()
        }
        return out
    }
}
FILE_EOF

mkdir -p "$(dirname app/src/main/java/com/livesub/glm/network/GroqWhisperClient.kt)"
cat << 'FILE_EOF' > app/src/main/java/com/livesub/glm/network/GroqWhisperClient.kt
package com.livesub.glm.network

import com.google.gson.JsonParser
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

class GroqWhisperClient {
    companion object {
        private const val GROQ_TRANSCRIPTION_URL = "https://api.groq.com/openai/v1/audio/transcriptions"
        private const val WHISPER_MODEL = "whisper-large-v3-turbo"
        private const val CONTEXT_PROMPT = "简体中文对话，日本語の会話セリフ。"
        private val HALLUCINATION_BLACKLIST = listOf(
            "ご視聴ありがとうございました", "チャンネル登録", "高評価",
            "字幕由", "字幕制作", "請不吝點贊", "请不吝点赞",
            "优优独播剧场", "Amara.org", "Thank you for watching"
        )
    }

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(12, TimeUnit.SECONDS)
        .writeTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build()

    suspend fun transcribeZhJa(wavBytes: ByteArray, groqApiKey: String): Result<String?> =
        withContext(Dispatchers.IO) {
            if (groqApiKey.isBlank()) {
                return@withContext Result.failure(IllegalArgumentException("ยังไม่ได้ตั้งค่า Groq API Key"))
            }
            try {
                val wavBody = wavBytes.toRequestBody("audio/wav".toMediaType())
                val multipartBody = MultipartBody.Builder()
                    .setType(MultipartBody.FORM)
                    .addFormDataPart("file", "speech.wav", wavBody)
                    .addFormDataPart("model", WHISPER_MODEL)
                    .addFormDataPart("prompt", CONTEXT_PROMPT)
                    .addFormDataPart("temperature", "0.0")
                    .addFormDataPart("response_format", "verbose_json")
                    .build()

                val request = Request.Builder()
                    .url(GROQ_TRANSCRIPTION_URL)
                    .addHeader("Authorization", "Bearer ${groqApiKey.trim()}")
                    .post(multipartBody)
                    .build()

                httpClient.newCall(request).execute().use { response ->
                    val rawBody = response.body?.string().orEmpty()
                    if (!response.isSuccessful) {
                        return@withContext Result.failure(
                            RuntimeException("Groq HTTP ${response.code}: ${rawBody.take(150)}")
                        )
                    }
                    val json = JsonParser.parseString(rawBody).asJsonObject
                    val detectedLang = json.get("language")?.asString?.lowercase().orEmpty()
                    if (detectedLang.isNotEmpty() && detectedLang !in setOf("chinese", "zh", "japanese", "ja")) {
                        return@withContext Result.success(null)
                    }
                    val rawText = json.get("text")?.asString.orEmpty()
                    Result.success(filterStrictZhJaUnicode(rawText))
                }
            } catch (e: Exception) {
                Result.failure(e)
            }
        }

    private fun filterStrictZhJaUnicode(input: String): String? {
        if (input.isBlank()) return null
        for (blocked in HALLUCINATION_BLACKLIST) {
            if (input.contains(blocked, ignoreCase = true)) return null
        }

        val sb = StringBuilder()
        var validCoreCount = 0
        for (ch in input) {
            val code = ch.code
            val isHiragana = code in 0x3040..0x309F
            val isKatakana = code in 0x30A0..0x30FF || code in 0x31F0..0x31FF || code in 0xFF65..0xFF9F
            val isCjk = code in 0x4E00..0x9FFF || code in 0x3400..0x4DBF
            val isPunct = code in 0x3000..0x303F || ch in charArrayOf('！', '？', '，', '。', '…', '～', 'ー', '!', '?', ' ')

            if (isHiragana || isKatakana || isCjk) {
                sb.append(ch)
                validCoreCount++
            } else if (isPunct && sb.isNotEmpty()) {
                sb.append(ch)
            }
        }

        val cleaned = sb.toString().trim()
        if (validCoreCount == 0 || cleaned.isEmpty()) return null
        if (cleaned.length >= 8 && cleaned.toSet().size == 1) return null
        return cleaned
    }
}
FILE_EOF

mkdir -p "$(dirname app/src/main/java/com/livesub/glm/network/NumesTranslationClient.kt)"
cat << 'FILE_EOF' > app/src/main/java/com/livesub/glm/network/NumesTranslationClient.kt
package com.livesub.glm.network

import com.google.gson.JsonArray
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

class NumesTranslationClient {
    data class DialogueTurn(val sourceText: String, val translatedThai: String)

    companion object {
        private const val NUMES_CHAT_URL = "https://api.numes.ai/api/v1/chat/completions"
        const val DEFAULT_MODEL = "glm-5.3-flash-uncensored"
        private const val MAX_HISTORY_TURNS = 4
        private const val TEMPERATURE = 0.65

        private const val SYSTEM_PROMPT = """คุณคือนักแปลซับไตเติลภาพยนตร์และวิดีโอผู้ใหญ่ (18+) มืออาชีพ แปลจากภาษาจีนและภาษาญี่ปุ่นเป็นภาษาไทยแบบไม่เซ็นเซอร์
กฎการแปล:
1. แปลเป็นภาษาพูดธรรมชาติตามอารมณ์ตัวละครจริง คงบริบทผู้ใหญ่ 18+ และคำอุทานครบถ้วนโดยไม่เซ็นเซอร์หรือลดทอนคำ
2. อ้างอิงประวัติบทสนทนาก่อนหน้าเพื่อใช้สรรพนามแทนตัวละครและหางเสียงให้ต่อเนื่องกัน
3. ตอบกลับเฉพาะข้อความซับไตเติลภาษาไทยที่แปลแล้วเท่านั้น ห้ามใส่คำอธิบายหรือทวนข้อความต้นฉบับ"""
    }

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(12, TimeUnit.SECONDS)
        .writeTimeout(12, TimeUnit.SECONDS)
        .readTimeout(35, TimeUnit.SECONDS)
        .build()

    private val historyMutex = Mutex()
    private val recentTurns = ArrayDeque<DialogueTurn>(MAX_HISTORY_TURNS)

    suspend fun clearHistory() {
        historyMutex.withLock { recentTurns.clear() }
    }

    suspend fun streamTranslateToThai(
        sourceText: String,
        numesApiKey: String,
        modelName: String,
        onStreamingUpdate: (String) -> Unit
    ): Result<String> = withContext(Dispatchers.IO) {
        if (numesApiKey.isBlank()) {
            return@withContext Result.failure(IllegalArgumentException("ยังไม่ได้ตั้งค่า Numes API Key"))
        }

        val activeModel = modelName.trim().ifEmpty { DEFAULT_MODEL }
        val snapshotHistory = historyMutex.withLock { recentTurns.toList() }

        val messagesArray = JsonArray().apply {
            add(JsonObject().apply {
                addProperty("role", "system")
                addProperty("content", SYSTEM_PROMPT)
            })
            for (turn in snapshotHistory) {
                add(JsonObject().apply {
                    addProperty("role", "user")
                    addProperty("content", turn.sourceText)
                })
                add(JsonObject().apply {
                    addProperty("role", "assistant")
                    addProperty("content", turn.translatedThai)
                })
            }
            add(JsonObject().apply {
                addProperty("role", "user")
                addProperty("content", sourceText)
            })
        }

        val payload = JsonObject().apply {
            addProperty("model", activeModel)
            add("messages", messagesArray)
            addProperty("stream", true)
            addProperty("temperature", TEMPERATURE)
            addProperty("max_tokens", 256)
        }

        val request = Request.Builder()
            .url(NUMES_CHAT_URL)
            .addHeader("Authorization", "Bearer ${numesApiKey.trim()}")
            .addHeader("Content-Type", "application/json")
            .addHeader("Accept", "text/event-stream")
            .post(payload.toString().toRequestBody("application/json; charset=utf-8".toMediaType()))
            .build()

        try {
            val builder = StringBuilder()
            httpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    val errBody = response.body?.string().orEmpty()
                    return@withContext Result.failure(
                        RuntimeException("Numes HTTP ${response.code}: ${errBody.take(150)}")
                    )
                }
                val source = response.body?.source()
                    ?: return@withContext Result.failure(RuntimeException("ไม่พบ Stream จาก Numes API"))

                while (!source.exhausted()) {
                    val line = source.readUtf8Line() ?: break
                    val trimmed = line.trim()
                    if (!trimmed.startsWith("data:")) continue
                    val dataPayload = trimmed.removePrefix("data:").trim()
                    if (dataPayload == "[DONE]") break
                    if (dataPayload.isEmpty()) continue

                    try {
                        val choices = JsonParser.parseString(dataPayload).asJsonObject.getAsJsonArray("choices")
                        if (choices != null && choices.size() > 0) {
                            val delta = choices[0].asJsonObject.getAsJsonObject("delta")
                            val contentPiece = delta?.get("content")?.takeIf { !it.isJsonNull }?.asString
                            if (!contentPiece.isNullOrEmpty()) {
                                builder.append(contentPiece)
                                val cleanPartial = stripThinkTags(builder.toString())
                                if (cleanPartial.isNotEmpty()) onStreamingUpdate(cleanPartial)
                            }
                        }
                    } catch (_: Exception) {
                    }
                }
            }

            val finalThai = stripThinkTags(builder.toString()).trim()
            if (finalThai.isNotEmpty()) {
                historyMutex.withLock {
                    if (recentTurns.size >= MAX_HISTORY_TURNS) recentTurns.removeFirst()
                    recentTurns.addLast(DialogueTurn(sourceText, finalThai))
                }
                onStreamingUpdate(finalThai)
            }
            Result.success(finalThai)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    private fun stripThinkTags(raw: String): String {
        val removed = raw.replace(Regex("<think>[\\s\\S]*?</think>"), "")
        val idx = removed.indexOf("<think>")
        return if (idx != -1) removed.substring(0, idx).trim() else removed.trim()
    }
}
FILE_EOF

mkdir -p "$(dirname app/src/main/java/com/livesub/glm/storage/SecurePrefs.kt)"
cat << 'FILE_EOF' > app/src/main/java/com/livesub/glm/storage/SecurePrefs.kt
package com.livesub.glm.storage

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.livesub.glm.BuildConfig
import com.livesub.glm.network.NumesTranslationClient

class SecurePrefs(context: Context) {
    companion object {
        private const val PREF_FILE = "livesub_glm_secure_prefs"
        private const val KEY_GROQ = "groq_api_key"
        private const val KEY_NUMES = "numes_api_key"
        private const val KEY_MODEL = "numes_model_name"
        private const val KEY_FONT_SP = "overlay_font_sp"
    }

    private val prefs: SharedPreferences = try {
        val masterKey = MasterKey.Builder(context.applicationContext)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context.applicationContext,
            PREF_FILE,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    } catch (_: Exception) {
        context.applicationContext.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
    }

    var groqApiKey: String
        get() = prefs.getString(KEY_GROQ, null)?.takeIf { it.isNotBlank() } ?: BuildConfig.DEFAULT_GROQ_API_KEY
        set(value) = prefs.edit().putString(KEY_GROQ, value.trim()).apply()

    var numesApiKey: String
        get() = prefs.getString(KEY_NUMES, null)?.takeIf { it.isNotBlank() } ?: BuildConfig.DEFAULT_NUMES_API_KEY
        set(value) = prefs.edit().putString(KEY_NUMES, value.trim()).apply()

    var modelName: String
        get() = prefs.getString(KEY_MODEL, null)?.takeIf { it.isNotBlank() } ?: NumesTranslationClient.DEFAULT_MODEL
        set(value) = prefs.edit().putString(KEY_MODEL, value.trim()).apply()

    var fontSizeSp: Float
        get() = prefs.getFloat(KEY_FONT_SP, 20f).coerceIn(14f, 36f)
        set(value) = prefs.edit().putFloat(KEY_FONT_SP, value.coerceIn(14f, 36f)).apply()
}
FILE_EOF

mkdir -p "$(dirname app/src/main/java/com/livesub/glm/overlay/FloatingSubtitleOverlay.kt)"
cat << 'FILE_EOF' > app/src/main/java/com/livesub/glm/overlay/FloatingSubtitleOverlay.kt
package com.livesub.glm.overlay

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.WindowManager
import com.livesub.glm.R
import com.livesub.glm.databinding.OverlaySubtitleBinding
import com.livesub.glm.storage.SecurePrefs
import kotlin.math.abs

class FloatingSubtitleOverlay(
    context: Context,
    private val prefs: SecurePrefs,
    private val onCloseRequested: () -> Unit
) {
    private val appContext = context.applicationContext
    private val windowManager = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var binding: OverlaySubtitleBinding? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var currentFontSp: Float = prefs.fontSizeSp
    private var isAttached = false

    @SuppressLint("ClickableViewAccessibility")
    fun show() {
        mainHandler.post {
            if (isAttached) return@post
            val themedContext = ContextThemeWrapper(appContext, R.style.Theme_LiveSubGLM)
            val vb = OverlaySubtitleBinding.inflate(LayoutInflater.from(themedContext))
            binding = vb

            val overlayWidth = (appContext.resources.displayMetrics.widthPixels * 0.90f).toInt()
            val params = WindowManager.LayoutParams(
                overlayWidth,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                x = 0
                y = (appContext.resources.displayMetrics.heightPixels * 0.68f).toInt()
            }
            layoutParams = params
            applyFontSize(currentFontSp)

            vb.btnFontMinus.setOnClickListener {
                currentFontSp = (currentFontSp - 2f).coerceAtLeast(14f)
                prefs.fontSizeSp = currentFontSp
                applyFontSize(currentFontSp)
            }
            vb.btnFontPlus.setOnClickListener {
                currentFontSp = (currentFontSp + 2f).coerceAtMost(36f)
                prefs.fontSizeSp = currentFontSp
                applyFontSize(currentFontSp)
            }
            vb.btnCloseOverlay.setOnClickListener { onCloseRequested() }

            var initialX = 0
            var initialY = 0
            var initialTouchX = 0f
            var initialTouchY = 0f
            var dragging = false

            vb.overlayRoot.setOnTouchListener { _, event ->
                val lp = layoutParams ?: return@setOnTouchListener false
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = lp.x
                        initialY = lp.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        dragging = false
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()
                        if (abs(dx) > 6 || abs(dy) > 6) dragging = true
                        if (dragging && isAttached) {
                            lp.x = initialX + dx
                            lp.y = initialY + dy
                            try {
                                windowManager.updateViewLayout(vb.root, lp)
                            } catch (_: Exception) {
                            }
                        }
                        true
                    }
                    else -> false
                }
            }

            try {
                windowManager.addView(vb.root, params)
                isAttached = true
            } catch (_: Exception) {
                isAttached = false
            }
        }
    }

    fun updateStatus(statusText: String) {
        mainHandler.post { binding?.tvStatusBadge?.text = statusText }
    }

    fun updateSourceText(source: String) {
        mainHandler.post { binding?.tvSourceText?.text = source }
    }

    fun updateTranslatedText(thaiText: String) {
        mainHandler.post { binding?.tvSubtitleThai?.text = thaiText }
    }

    fun hide() {
        mainHandler.post {
            val vb = binding
            if (isAttached && vb != null) {
                try {
                    windowManager.removeView(vb.root)
                } catch (_: Exception) {
                }
            }
            isAttached = false
            binding = null
            layoutParams = null
        }
    }

    private fun applyFontSize(sizeSp: Float) {
        binding?.let { vb ->
            vb.tvSubtitleThai.setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
            vb.tvSourceText.setTextSize(TypedValue.COMPLEX_UNIT_SP, (sizeSp * 0.65f).coerceAtLeast(11f))
            vb.tvStatusBadge.text = "LiveSub 18+ (${sizeSp.toInt()}sp)"
        }
    }
}
FILE_EOF

mkdir -p "$(dirname app/src/main/java/com/livesub/glm/service/LiveSubCaptureService.kt)"
cat << 'FILE_EOF' > app/src/main/java/com/livesub/glm/service/LiveSubCaptureService.kt
package com.livesub.glm.service

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.livesub.glm.MainActivity
import com.livesub.glm.R
import com.livesub.glm.audio.InternalAudioVadRecorder
import com.livesub.glm.network.GroqWhisperClient
import com.livesub.glm.network.NumesTranslationClient
import com.livesub.glm.overlay.FloatingSubtitleOverlay
import com.livesub.glm.storage.SecurePrefs
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class LiveSubCaptureService : Service() {
    companion object {
        const val ACTION_START = "com.livesub.glm.action.START"
        const val ACTION_STOP = "com.livesub.glm.action.STOP"
        const val EXTRA_RESULT_CODE = "extra_result_code"
        const val EXTRA_RESULT_DATA = "extra_result_data"
        private const val CHANNEL_ID = "livesub_capture_channel"
        private const val NOTIFICATION_ID = 1018

        private val _isRunning = MutableStateFlow(false)
        val isRunning: StateFlow<Boolean> = _isRunning
    }

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private lateinit var prefs: SecurePrefs
    private val groqClient = GroqWhisperClient()
    private val numesClient = NumesTranslationClient()

    private var mediaProjection: MediaProjection? = null
    private var vadRecorder: InternalAudioVadRecorder? = null
    private var overlay: FloatingSubtitleOverlay? = null

    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() = stopCaptureAndSelf()
    }

    override fun onCreate() {
        super.onCreate()
        prefs = SecurePrefs(this)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopCaptureAndSelf()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
                val resultData: Intent? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(EXTRA_RESULT_DATA)
                }

                if (resultCode != Activity.RESULT_OK || resultData == null) {
                    stopCaptureAndSelf()
                    return START_NOT_STICKY
                }

                startForeground(
                    NOTIFICATION_ID,
                    buildNotification(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                )
                startCapturePipeline(resultCode, resultData)
            }
        }
        return START_NOT_STICKY
    }

    private fun startCapturePipeline(resultCode: Int, resultData: Intent) {
        vadRecorder?.stop()
        mediaProjection?.unregisterCallback(projectionCallback)
        mediaProjection?.stop()

        serviceScope.launch { numesClient.clearHistory() }

        val mpManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val projection = try {
            mpManager.getMediaProjection(resultCode, resultData)
        } catch (_: Exception) {
            null
        } ?: run {
            stopCaptureAndSelf()
            return
        }

        projection.registerCallback(projectionCallback, Handler(Looper.getMainLooper()))
        mediaProjection = projection

        if (overlay == null) {
            overlay = FloatingSubtitleOverlay(this, prefs) { stopCaptureAndSelf() }
        }
        overlay?.show()
        overlay?.updateStatus("กำลังฟังเสียงวิดีโอ (ZH/JA)...")
        overlay?.updateTranslatedText("พร้อมแปลซับไตเติลสด เปิดวิดีโอ MP4 ได้เลย")

        vadRecorder = InternalAudioVadRecorder(
            mediaProjection = projection,
            scope = serviceScope,
            onWavChunkReady = { wavBytes -> processAudioChunk(wavBytes) },
            onError = { errMsg -> overlay?.updateStatus("Audio Error: $errMsg") }
        ).also { it.start() }

        _isRunning.value = true
    }

    private suspend fun processAudioChunk(wavBytes: ByteArray) {
        overlay?.updateStatus("กำลังถอดเสียง...")
        val sttResult = groqClient.transcribeZhJa(wavBytes, prefs.groqApiKey)

        sttResult.fold(
            onSuccess = { cleanText ->
                if (cleanText.isNullOrBlank()) {
                    overlay?.updateStatus("กำลังฟังเสียงวิดีโอ (ZH/JA)...")
                    return
                }
                overlay?.updateSourceText(cleanText)
                overlay?.updateStatus("กำลังแปล GLM 18+...")

                numesClient.streamTranslateToThai(
                    sourceText = cleanText,
                    numesApiKey = prefs.numesApiKey,
                    modelName = prefs.modelName,
                    onStreamingUpdate = { partialThai -> overlay?.updateTranslatedText(partialThai) }
                ).onFailure { err ->
                    overlay?.updateStatus("แปลผิดพลาด: ${err.message?.take(45)}")
                }.onSuccess {
                    overlay?.updateStatus("LiveSub 18+ พร้อมฟังต่อ")
                }
            },
            onFailure = { err ->
                overlay?.updateStatus("STT ผิดพลาด: ${err.message?.take(45)}")
            }
        )
    }

    private fun stopCaptureAndSelf() {
        _isRunning.value = false
        vadRecorder?.stop()
        vadRecorder = null
        try {
            mediaProjection?.unregisterCallback(projectionCallback)
            mediaProjection?.stop()
        } catch (_: Exception) {
        }
        mediaProjection = null
        overlay?.hide()
        overlay = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        stopCaptureAndSelf()
        serviceScope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "LiveSub Audio Capture",
            NotificationManager.IMPORTANCE_LOW
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val pendingOpen = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopIntent = Intent(this, LiveSubCaptureService::class.java).apply { action = ACTION_STOP }
        val pendingStop = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("LiveSub GLM 18+ กำลังทำงาน")
            .setContentText("กำลังดักจับเสียงวิดีโอเพื่อแปลซับไตเติลไทยสด")
            .setContentIntent(pendingOpen)
            .setOngoing(true)
            .addAction(0, "หยุดแปล", pendingStop)
            .build()
    }
}
FILE_EOF

mkdir -p "$(dirname app/src/main/java/com/livesub/glm/MainActivity.kt)"
cat << 'FILE_EOF' > app/src/main/java/com/livesub/glm/MainActivity.kt
package com.livesub.glm

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.livesub.glm.databinding.ActivityMainBinding
import com.livesub.glm.network.NumesTranslationClient
import com.livesub.glm.service.LiveSubCaptureService
import com.livesub.glm.storage.SecurePrefs
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding
    private lateinit var prefs: SecurePrefs

    private val runtimePermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { results ->
        val audioGranted = results[Manifest.permission.RECORD_AUDIO] == true ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        if (audioGranted) requestOverlayThenProjection()
        else toast("จำเป็นต้องอนุญาตสิทธิ์บันทึกเสียงเพื่อใช้ AudioPlaybackCapture")
    }

    private val overlaySettingsLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) {
        if (Settings.canDrawOverlays(this)) launchMediaProjectionPrompt()
        else toast("กรุณาเปิดสิทธิ์แสดงผลทับแอปอื่น (Floating Overlay)")
    }

    private val mediaProjectionLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK && result.data != null) {
            val serviceIntent = Intent(this, LiveSubCaptureService::class.java).apply {
                action = LiveSubCaptureService.ACTION_START
                putExtra(LiveSubCaptureService.EXTRA_RESULT_CODE, result.resultCode)
                putExtra(LiveSubCaptureService.EXTRA_RESULT_DATA, result.data)
            }
            ContextCompat.startForegroundService(this, serviceIntent)
            toast("เริ่มระบบแปลซับสดแล้ว สลับไปเปิดวิดีโอ MP4 ได้เลย")
        } else {
            toast("ยกเลิกการแชร์เสียงหน้าจอ")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        prefs = SecurePrefs(this)
        binding.etGroqKey.setText(prefs.groqApiKey)
        binding.etNumesKey.setText(prefs.numesApiKey)
        binding.etModelName.setText(prefs.modelName)

        binding.btnStartCapture.setOnClickListener {
            if (saveAndValidateInputs()) checkPermissionsAndStart()
        }

        binding.btnStopCapture.setOnClickListener {
            startService(Intent(this, LiveSubCaptureService::class.java).apply {
                action = LiveSubCaptureService.ACTION_STOP
            })
        }

        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                LiveSubCaptureService.isRunning.collect { running ->
                    binding.btnStartCapture.isEnabled = !running
                    binding.btnStopCapture.isEnabled = running
                    binding.tvServiceStatus.text = if (running) {
                        "สถานะ: กำลังดักเสียง Media และแปลซับลอยตัวอยู่"
                    } else {
                        "สถานะ: พร้อมทำงาน (หยุดอยู่)"
                    }
                }
            }
        }
    }

    private fun saveAndValidateInputs(): Boolean {
        val groq = binding.etGroqKey.text?.toString()?.trim().orEmpty()
        val numes = binding.etNumesKey.text?.toString()?.trim().orEmpty()
        val model = binding.etModelName.text?.toString()?.trim()
            .takeUnless { it.isNullOrEmpty() } ?: NumesTranslationClient.DEFAULT_MODEL

        if (groq.isEmpty()) {
            binding.etGroqKey.error = "กรุณาใส่ Groq API Key (gsk_...)"
            return false
        }
        if (numes.isEmpty()) {
            binding.etNumesKey.error = "กรุณาใส่ Numes.ai API Key"
            return false
        }

        prefs.groqApiKey = groq
        prefs.numesApiKey = numes
        prefs.modelName = model
        binding.etModelName.setText(model)
        return true
    }

    private fun checkPermissionsAndStart() {
        val needed = mutableListOf<String>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            needed.add(Manifest.permission.RECORD_AUDIO)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            needed.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        if (needed.isNotEmpty()) runtimePermissionLauncher.launch(needed.toTypedArray())
        else requestOverlayThenProjection()
    }

    private fun requestOverlayThenProjection() {
        if (!Settings.canDrawOverlays(this)) {
            overlaySettingsLauncher.launch(
                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
            )
        } else {
            launchMediaProjectionPrompt()
        }
    }

    private fun launchMediaProjectionPrompt() {
        val mpManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjectionLauncher.launch(mpManager.createScreenCaptureIntent())
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
}
FILE_EOF

mkdir -p "$(dirname app/src/main/res/values/strings.xml)"
cat << 'FILE_EOF' > app/src/main/res/values/strings.xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">LiveSub GLM 18+</string>
</resources>
FILE_EOF

mkdir -p "$(dirname app/src/main/res/values/colors.xml)"
cat << 'FILE_EOF' > app/src/main/res/values/colors.xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="bg_dark">#101218</color>
    <color name="surface_dark">#1C202B</color>
    <color name="primary_accent">#FF4D79</color>
    <color name="secondary_accent">#00E5FF</color>
    <color name="text_primary">#F8FAFC</color>
    <color name="text_secondary">#94A3B8</color>
    <color name="subtitle_yellow">#FFE66D</color>
</resources>
FILE_EOF

mkdir -p "$(dirname app/src/main/res/values/themes.xml)"
cat << 'FILE_EOF' > app/src/main/res/values/themes.xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.LiveSubGLM" parent="Theme.Material3.Dark.NoActionBar">
        <item name="colorPrimary">@color/primary_accent</item>
        <item name="colorSecondary">@color/secondary_accent</item>
        <item name="android:statusBarColor">@color/bg_dark</item>
        <item name="android:navigationBarColor">@color/bg_dark</item>
        <item name="android:windowBackground">@color/bg_dark</item>
    </style>
</resources>
FILE_EOF

mkdir -p "$(dirname app/src/main/res/drawable/bg_overlay_card.xml)"
cat << 'FILE_EOF' > app/src/main/res/drawable/bg_overlay_card.xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#CC0D0F14" />
    <corners android:radius="14dp" />
    <stroke android:width="1dp" android:color="#4DFF4D79" />
</shape>
FILE_EOF

mkdir -p "$(dirname app/src/main/res/drawable/bg_overlay_btn.xml)"
cat << 'FILE_EOF' > app/src/main/res/drawable/bg_overlay_btn.xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#33FFFFFF" />
    <corners android:radius="8dp" />
</shape>
FILE_EOF

mkdir -p "$(dirname app/src/main/res/drawable/ic_launcher_background.xml)"
cat << 'FILE_EOF' > app/src/main/res/drawable/ic_launcher_background.xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#161923" />
</shape>
FILE_EOF

mkdir -p "$(dirname app/src/main/res/drawable/ic_launcher_foreground.xml)"
cat << 'FILE_EOF' > app/src/main/res/drawable/ic_launcher_foreground.xml
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#FF4D79"
        android:pathData="M26,34h56c3.3,0 6,2.7 6,6v28c0,3.3 -2.7,6 -6,6H48l-12,10v-10H26c-3.3,0 -6,-2.7 -6,-6V40c0,-3.3 2.7,-6 6,-6z" />
    <path
        android:fillColor="#FFFFFF"
        android:pathData="M34,48h40v4H34zM34,56h28v4H34z" />
</vector>
FILE_EOF

mkdir -p "$(dirname app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml)"
cat << 'FILE_EOF' > app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
FILE_EOF

mkdir -p "$(dirname app/src/main/res/layout/overlay_subtitle.xml)"
cat << 'FILE_EOF' > app/src/main/res/layout/overlay_subtitle.xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/overlayRoot"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:background="@drawable/bg_overlay_card"
    android:orientation="vertical"
    android:padding="10dp">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:gravity="center_vertical"
        android:orientation="horizontal">

        <TextView
            android:id="@+id/tvStatusBadge"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:ellipsize="end"
            android:maxLines="1"
            android:text="LiveSub GLM 18+"
            android:textColor="@color/text_secondary"
            android:textSize="11sp" />

        <TextView
            android:id="@+id/btnFontMinus"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginEnd="6dp"
            android:background="@drawable/bg_overlay_btn"
            android:paddingHorizontal="9dp"
            android:paddingVertical="3dp"
            android:text="A-"
            android:textColor="@color/text_primary"
            android:textSize="12sp"
            android:textStyle="bold" />

        <TextView
            android:id="@+id/btnFontPlus"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginEnd="6dp"
            android:background="@drawable/bg_overlay_btn"
            android:paddingHorizontal="9dp"
            android:paddingVertical="3dp"
            android:text="A+"
            android:textColor="@color/text_primary"
            android:textSize="12sp"
            android:textStyle="bold" />

        <TextView
            android:id="@+id/btnCloseOverlay"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:background="@drawable/bg_overlay_btn"
            android:paddingHorizontal="9dp"
            android:paddingVertical="3dp"
            android:text="✕"
            android:textColor="#FF6B8B"
            android:textSize="12sp"
            android:textStyle="bold" />
    </LinearLayout>

    <TextView
        android:id="@+id/tvSourceText"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="4dp"
        android:gravity="center"
        android:maxLines="2"
        android:text=""
        android:textColor="#B3E2E8F0"
        android:textSize="13sp" />

    <TextView
        android:id="@+id/tvSubtitleThai"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="2dp"
        android:gravity="center"
        android:lineSpacingMultiplier="1.15"
        android:shadowColor="#FF000000"
        android:shadowDx="0"
        android:shadowDy="2"
        android:shadowRadius="6"
        android:text="พร้อมแปลซับไตเติลสด..."
        android:textColor="@color/subtitle_yellow"
        android:textSize="20sp"
        android:textStyle="bold" />
</LinearLayout>
FILE_EOF

mkdir -p "$(dirname app/src/main/res/layout/activity_main.xml)"
cat << 'FILE_EOF' > app/src/main/res/layout/activity_main.xml
<?xml version="1.0" encoding="utf-8"?>
<ScrollView xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:fillViewport="true">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="vertical"
        android:padding="20dp">

        <TextView
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:text="LiveSub GLM 18+"
            android:textColor="@color/primary_accent"
            android:textSize="26sp"
            android:textStyle="bold" />

        <TextView
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="4dp"
            android:text="ดักเสียงวิดีโอภายในเครื่อง (ZH/JA) แปลซับไทยสดแบบไม่เซ็นเซอร์"
            android:textColor="@color/text_secondary"
            android:textSize="13sp" />

        <TextView
            android:id="@+id/tvServiceStatus"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="16dp"
            android:background="@drawable/bg_overlay_card"
            android:padding="12dp"
            android:text="สถานะ: พร้อมทำงาน (หยุดอยู่)"
            android:textColor="@color/secondary_accent"
            android:textSize="14sp"
            android:textStyle="bold" />

        <com.google.android.material.textfield.TextInputLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="18dp"
            android:hint="Groq API Key (whisper-large-v3-turbo)"
            app:endIconMode="password_toggle">

            <com.google.android.material.textfield.TextInputEditText
                android:id="@+id/etGroqKey"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:inputType="textPassword"
                android:singleLine="true" />
        </com.google.android.material.textfield.TextInputLayout>

        <com.google.android.material.textfield.TextInputLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="12dp"
            android:hint="Numes.ai API Key"
            app:endIconMode="password_toggle">

            <com.google.android.material.textfield.TextInputEditText
                android:id="@+id/etNumesKey"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:inputType="textPassword"
                android:singleLine="true" />
        </com.google.android.material.textfield.TextInputLayout>

        <com.google.android.material.textfield.TextInputLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="12dp"
            android:hint="Translation Model Name">

            <com.google.android.material.textfield.TextInputEditText
                android:id="@+id/etModelName"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:inputType="text"
                android:singleLine="true" />
        </com.google.android.material.textfield.TextInputLayout>

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="24dp"
            android:orientation="horizontal">

            <com.google.android.material.button.MaterialButton
                android:id="@+id/btnStartCapture"
                android:layout_width="0dp"
                android:layout_height="54dp"
                android:layout_marginEnd="8dp"
                android:layout_weight="1"
                android:text="เริ่มดักเสียงแปลสด"
                android:textSize="15sp"
                android:textStyle="bold" />

            <com.google.android.material.button.MaterialButton
                android:id="@+id/btnStopCapture"
                style="@style/Widget.Material3.Button.OutlinedButton"
                android:layout_width="0dp"
                android:layout_height="54dp"
                android:layout_marginStart="8dp"
                android:layout_weight="1"
                android:enabled="false"
                android:text="หยุดทำงาน"
                android:textSize="15sp" />
        </LinearLayout>

        <TextView
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="18dp"
            android:lineSpacingMultiplier="1.25"
            android:text="วิธีใช้งาน:\n1. ใส่ Groq Key (gsk_...) และ Numes Key ครั้งแรก แอปจะเข้ารหัสจำไว้ในเครื่อง\n2. กดเริ่มดักเสียง อนุญาตสิทธิ์ Overlay และกดยอมรับแชร์หน้าจอ/เสียง\n3. เปิดไฟล์ MP4 ในแอปเล่นวิดีโอ (เช่น VLC / MX Player) ลากกล่องซับและกด A- / A+ ปรับขนาดได้ทันที"
            android:textColor="@color/text_secondary"
            android:textSize="12sp" />
    </LinearLayout>
</ScrollView>
FILE_EOF

echo "Files written. GitHub Actions workflow will build APK."