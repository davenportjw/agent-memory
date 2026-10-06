package com.example.client

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.client/gemma_edge"
    private var llmInference: LlmInference? = null
    private var isModelLoaded = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkModelStatus" -> {
                    val defaultAvdPath = "/data/local/tmp/gemma-4-2b-it-int4.bin"
                    val legacyAvdPath = "/data/local/tmp/gemma-2b-it-int4.bin"
                    val internalFile = File(filesDir, "gemma-4-2b-it-int4.bin")
                    val avdFile = File(defaultAvdPath)
                    val legacyFile = File(legacyAvdPath)

                    val existingFile = when {
                        avdFile.exists() -> avdFile
                        internalFile.exists() -> internalFile
                        legacyFile.exists() -> legacyFile
                        else -> null
                    }
                    val exists = existingFile != null
                    val targetPath = existingFile?.absolutePath ?: defaultAvdPath
                    val fileSize = existingFile?.length() ?: 0L

                    result.success(mapOf(
                        "exists" to exists,
                        "path" to targetPath,
                        "fileSizeBytes" to fileSize,
                        "isLoaded" to isModelLoaded,
                        "adbCommand" to "adb push <local_weights_path> $defaultAvdPath"
                    ))
                }
                "loadModel" -> {
                    val customPath = call.argument<String>("path")
                    val defaultAvdPath = "/data/local/tmp/gemma-4-2b-it-int4.bin"
                    val legacyAvdPath = "/data/local/tmp/gemma-2b-it-int4.bin"
                    val internalFile = File(filesDir, "gemma-4-2b-it-int4.bin")

                    val targetFile = when {
                        customPath != null && File(customPath).exists() -> File(customPath)
                        File(defaultAvdPath).exists() -> File(defaultAvdPath)
                        internalFile.exists() -> internalFile
                        File(legacyAvdPath).exists() -> File(legacyAvdPath)
                        else -> null
                    }

                    if (targetFile == null) {
                        result.error(
                            "FILE_NOT_FOUND",
                            "Gemma 4 2B model file not found. Push model weights via ADB:\n\nadb push <path-to-gemma-4-2b-int4.bin> /data/local/tmp/gemma-4-2b-it-int4.bin",
                            mapOf("targetPath" to defaultAvdPath)
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val options = LlmInference.LlmInferenceOptions.builder()
                            .setModelPath(targetFile.absolutePath)
                            .setMaxTokens(1024)
                            .build()

                        llmInference = LlmInference.createFromOptions(context, options)
                        isModelLoaded = true

                        result.success(mapOf(
                            "status" to "ready",
                            "model" to "Gemma 4 2B int4 (LiteRT)",
                            "path" to targetFile.absolutePath,
                            "fileSizeBytes" to targetFile.length()
                        ))
                    } catch (e: Exception) {
                        isModelLoaded = false
                        result.error("LOAD_FAILED", "Failed to initialize LiteRT LlmInference: ${e.message}", null)
                    }
                }
                "unloadModel" -> {
                    isModelLoaded = false
                    llmInference = null
                    result.success(mapOf(
                        "isLoaded" to false,
                        "unloaded" to true,
                        "status" to "unloaded"
                    ))
                }
                else -> result.notImplemented()
            }
        }
    }
}
