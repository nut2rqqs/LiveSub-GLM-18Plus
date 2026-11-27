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
