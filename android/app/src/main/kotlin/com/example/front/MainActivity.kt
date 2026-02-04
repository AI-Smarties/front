package com.example.front

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.front.cpp.Cpp

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.smarties.audio/lc3"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "decodeLc3" -> {
                    try {
                        val audioData = call.argument<ByteArray>("audioData")
                        if (audioData != null) {
                            val pcmData = Cpp.decodeLC3(audioData)
                            result.success(pcmData)
                        } else {
                            result.error("INVALID_ARGUMENT", "Audio data is null", null)
                        }
                    } catch (e: Exception) {
                        result.error("DECODE_ERROR", "Failed to decode LC3: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
