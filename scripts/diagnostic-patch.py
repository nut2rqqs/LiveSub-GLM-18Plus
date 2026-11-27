#!/usr/bin/env python3
from pathlib import Path
import re

p = Path("app/src/main/java/com/livesub/glm/service/LiveSubCaptureService.kt")
s = p.read_text()

old = 'overlay?.updateTranslatedText("พร้อมแปลซับไตเติลสด เปิดวิดีโอ MP4 ได้เลย")'
if old not in s:
    raise SystemExit("PATCH_FAIL: overlay placeholder anchor not found")
s = s.replace(old, 'overlay?.updateTranslatedText("")')

start = s.find("    private suspend fun processAudioChunk(wavBytes: ByteArray) {")
end = s.find("\n    private fun stopCaptureAndSelf()", start)
if start < 0 or end < 0:
    raise SystemExit("PATCH_FAIL: processAudioChunk boundaries not found")

new_method = '''    private suspend fun processAudioChunk(wavBytes: ByteArray) {
        val chunkReceivedAt = android.os.SystemClock.elapsedRealtime()
        overlay?.updateStatus("เสียงเข้าแล้ว · WAV ${wavBytes.size / 1024} KB")
        overlay?.updateStatus("Groq Whisper: กำลังส่งเสียง...")
        val groqStartedAt = android.os.SystemClock.elapsedRealtime()
        val sttResult = groqClient.transcribeZhJa(wavBytes, prefs.groqApiKey)
        val groqElapsed = android.os.SystemClock.elapsedRealtime() - groqStartedAt

        sttResult.fold(
            onSuccess = { cleanText ->
                if (cleanText.isNullOrBlank()) {
                    overlay?.updateStatus("Whisper ตอบกลับ ${groqElapsed}ms · ไม่พบข้อความ ZH/JA")
                    return
                }
                overlay?.updateStatus("Whisper สำเร็จ · ${groqElapsed}ms")
                overlay?.updateSourceText(cleanText)
                overlay?.updateStatus("GLM: กำลังแปล...")

                val glmStartedAt = android.os.SystemClock.elapsedRealtime()
                numesClient.streamTranslateToThai(
                    sourceText = cleanText,
                    numesApiKey = prefs.numesApiKey,
                    modelName = prefs.modelName,
                    onStreamingUpdate = { partialThai -> overlay?.updateTranslatedText(partialThai) }
                ).onFailure { err ->
                    val glmElapsed = android.os.SystemClock.elapsedRealtime() - glmStartedAt
                    overlay?.updateStatus("GLM Error · ${glmElapsed}ms · ${err.message?.take(35)}")
                }.onSuccess {
                    val glmElapsed = android.os.SystemClock.elapsedRealtime() - glmStartedAt
                    val totalElapsed = android.os.SystemClock.elapsedRealtime() - chunkReceivedAt
                    overlay?.updateStatus("เสร็จ · Whisper ${groqElapsed}ms / GLM ${glmElapsed}ms / รวม ${totalElapsed}ms")
                }
            },
            onFailure = { err ->
                overlay?.updateStatus("Groq Error · ${groqElapsed}ms · ${err.message?.take(50)}")
            }
        )
    }
'''
s = s[:start] + new_method + s[end:]
p.write_text(s)
print("PATCH_OK: service stage timing + remove misleading placeholder")


# Diagnose the pre-Groq gate: RMS levels, threshold crossing and VAD segment emission.
v = Path("app/src/main/java/com/livesub/glm/audio/InternalAudioVadRecorder.kt")
vs = v.read_text()
vs = vs.replace(
    "    private val onError: (String) -> Unit\n)",
    "    private val onError: (String) -> Unit,\n    private val onDebug: (String) -> Unit\n)"
)
if "private val onDebug: (String) -> Unit" not in vs:
    raise SystemExit("PATCH_FAIL: recorder constructor anchor missing")
vs = vs.replace("private const val VAD_RMS_THRESHOLD = 300.0", "private const val VAD_RMS_THRESHOLD = 180.0")
vs = vs.replace(
    "            var voicedFramesMs = 0\n\n            try {",
    "            var voicedFramesMs = 0\n            var meterFrames = 0\n\n            try {"
)
vs = vs.replace(
    "                    val isVoiceFrame = rms >= VAD_RMS_THRESHOLD\n",
    "                    val isVoiceFrame = rms >= VAD_RMS_THRESHOLD\n                    meterFrames++\n                    if (meterFrames >= 50) { meterFrames = 0; if (!isSpeaking) onDebug(\"Audio monitor · RMS \${rms.toInt()} / threshold \${VAD_RMS_THRESHOLD.toInt()}\") else onDebug(\"VAD กำลังจับเสียง · RMS \${rms.toInt()}\") }\n"
)
vs = vs.replace(
    "                                wavChannel.send(wavBytes)",
    "                                onDebug(\"VAD ส่ง segment · \${wavBytes.size / 1024} KB\")\n                                wavChannel.send(wavBytes)"
)
v.write_text(vs)

service = Path("app/src/main/java/com/livesub/glm/service/LiveSubCaptureService.kt")
ss = service.read_text()
ss = ss.replace(
    "            onError = { errMsg -> overlay?.updateStatus(\"Audio Error: $errMsg\") }\n        ).also",
    "            onError = { errMsg -> overlay?.updateStatus(\"Audio Error: $errMsg\") },\n            onDebug = { msg -> overlay?.updateStatus(msg) }\n        ).also"
)
if "onDebug = { msg -> overlay?.updateStatus(msg) }" not in ss:
    raise SystemExit("PATCH_FAIL: recorder debug callback anchor missing")
service.write_text(ss)
print("PATCH_OK: VAD meter, lower threshold, segment emission status")
