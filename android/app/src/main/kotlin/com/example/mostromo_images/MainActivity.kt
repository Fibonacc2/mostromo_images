package com.example.mostromo_images

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import java.io.File
import java.io.InputStream
import java.io.FileOutputStream
import android.util.Log

class MainActivity: FlutterActivity() {
    private val CHANNEL = "mostromo_images/share"
    private var sharedUris: List<Uri> = emptyList()
    private var hasPendingShare = false
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedFiles" -> {
                    handleGetSharedFiles(call, result)
                }
                "clearSharedFiles" -> {
                    handleClearSharedFiles(call, result)
                }
                "hasPendingShare" -> {
                    result.success(hasPendingShare)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent, true)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent, false)
    }

    private fun handleIntent(intent: Intent, appAlreadyRunning: Boolean) {
        val action = intent.action
        val type = intent.type

        Log.d("ShareIntent", "Action: $action, Type: $type")

        // Intent'i temizle (tekrar kullanımı önlemek için)
        setIntent(Intent())

        // Tek dosya paylaşımı
        if (Intent.ACTION_SEND == action && type != null) {
            if (type.startsWith("image/") || type.startsWith("video/")) {
                val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                if (uri != null) {
                    Log.d("ShareIntent", "Single file URI: $uri")
                    sharedUris = listOf(uri)
                    hasPendingShare = true
                    
                    if (appAlreadyRunning) {
                        notifyFlutterToNavigate()
                    }
                }
            }
        } 
        // Çoklu dosya paylaşımı
        else if (Intent.ACTION_SEND_MULTIPLE == action && type != null) {
            if (type.startsWith("image/") || type.startsWith("video/")) {
                val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                if (uris != null) {
                    Log.d("ShareIntent", "Multiple files: ${uris.size}")
                    sharedUris = uris
                    hasPendingShare = true
                    
                    if (appAlreadyRunning) {
                        notifyFlutterToNavigate()
                    }
                }
            }
        }
    }

    private fun notifyFlutterToNavigate() {
        try {
            methodChannel?.invokeMethod("navigateToUpload", null)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun handleGetSharedFiles(call: MethodCall, result: MethodChannel.Result) {
        try {
            val filePaths = mutableListOf<String>()
            
            Log.d("ShareIntent", "Processing ${sharedUris.size} shared files")
            
            for (uri in sharedUris) {
                val filePath = getFilePathFromUri(uri)
                if (filePath != null) {
                    Log.d("ShareIntent", "File path: $filePath")
                    filePaths.add(filePath)
                } else {
                    Log.e("ShareIntent", "Failed to get path for URI: $uri")
                }
            }
            
            result.success(filePaths)
            hasPendingShare = false
            
            // ❌❌❌ BURAYI KALDIR - DOSYALARI HEMEN SİLME! ❌❌❌
            // clearCacheFiles() // BU SATIRI YORUM YAP VEYA SİL
            
        } catch (e: Exception) {
            Log.e("ShareIntent", "Error getting shared files: ${e.message}")
            result.error("SHARED_FILES_ERROR", "Dosyalar alınamadı: ${e.message}", null)
        }
    }

    // ✅ YENİ METHOD: URI'den dosya yolunu al
    private fun getFilePathFromUri(uri: Uri): String? {
        return try {
            when {
                // Content URI (galeri, dosya yöneticisi)
                uri.scheme == "content" -> {
                    getFileFromContentUri(uri)
                }
                // File URI (direkt dosya yolu)
                uri.scheme == "file" -> {
                    uri.path
                }
                // Diğer URI'ler için cache'e kopyala
                else -> {
                    copyFileToCache(uri)
                }
            }
        } catch (e: Exception) {
            Log.e("ShareIntent", "Error getting file path: ${e.message}")
            null
        }
    }

    // ✅ YENİ METHOD: Content URI'den dosya al
    private fun getFileFromContentUri(uri: Uri): String? {
        return try {
            val inputStream: InputStream? = contentResolver.openInputStream(uri)
            if (inputStream != null) {
                val cacheDir = applicationContext.cacheDir
                val fileName = "shared_${System.currentTimeMillis()}.${getFileExtension(uri)}"
                val outputFile = File(cacheDir, fileName)
                
                FileOutputStream(outputFile).use { outputStream ->
                    inputStream.copyTo(outputStream)
                }
                inputStream.close()
                
                Log.d("ShareIntent", "File copied to: ${outputFile.absolutePath}")
                outputFile.absolutePath
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e("ShareIntent", "Error copying content URI: ${e.message}")
            null
        }
    }

    // ✅ YENİ METHOD: Dosya uzantısını al
    private fun getFileExtension(uri: Uri): String {
        return try {
            val mimeType = contentResolver.getType(uri)
            when {
                mimeType?.startsWith("image/") == true -> {
                    when (mimeType) {
                        "image/jpeg", "image/jpg" -> "jpg"
                        "image/png" -> "png"
                        "image/gif" -> "gif"
                        "image/webp" -> "webp"
                        else -> "jpg"
                    }
                }
                mimeType?.startsWith("video/") == true -> {
                    when (mimeType) {
                        "video/mp4" -> "mp4"
                        "video/3gpp" -> "3gp"
                        "video/webm" -> "webm"
                        else -> "mp4"
                    }
                }
                else -> "file"
            }
        } catch (e: Exception) {
            "file"
        }
    }

    private fun copyFileToCache(uri: Uri): String? {
        return try {
            val inputStream: InputStream? = contentResolver.openInputStream(uri)
            if (inputStream != null) {
                val cacheDir = applicationContext.cacheDir
                val originalFileName = getFileName(uri)
                val fileName = "shared_${System.currentTimeMillis()}_$originalFileName"
                val outputFile = File(cacheDir, fileName)
                
                FileOutputStream(outputFile).use { outputStream ->
                    inputStream.copyTo(outputStream)
                }
                inputStream.close()
                
                Log.d("ShareIntent", "File copied to cache: ${outputFile.absolutePath}")
                outputFile.absolutePath
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e("ShareIntent", "Error copying to cache: ${e.message}")
            null
        }
    }

    private fun handleClearSharedFiles(call: MethodCall, result: MethodChannel.Result) {
        sharedUris = emptyList()
        hasPendingShare = false
        clearCacheFiles() // ✅ BU SADECE MANUEL TEMİZLİK İÇİN
        result.success(null)
    }

    private fun getFileName(uri: Uri): String {
        return try {
            var result: String? = null
            if (uri.scheme == "content") {
                val cursor = contentResolver.query(uri, null, null, null, null)
                cursor.use { cursor ->
                    if (cursor != null && cursor.moveToFirst()) {
                        val displayNameIndex = cursor.getColumnIndex("_display_name")
                        if (displayNameIndex != -1) {
                            result = cursor.getString(displayNameIndex)
                        }
                    }
                }
            }
            if (result == null) {
                result = uri.path
                val cut = result?.lastIndexOf('/')
                if (cut != -1 && cut != null) {
                    result = result?.substring(cut + 1)
                }
            }
            result ?: "unknown_file"
        } catch (e: Exception) {
            "unknown_file"
        }
    }

    private fun clearCacheFiles() {
        try {
            val cacheDir = applicationContext.cacheDir
            if (cacheDir.exists() && cacheDir.isDirectory) {
                val files = cacheDir.listFiles()
                files?.forEach { file ->
                    if (file.name.startsWith("shared_")) {
                        val deleted = file.delete()
                        Log.d("ShareIntent", "Deleted ${file.name}: $deleted")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("ShareIntent", "Error clearing cache: ${e.message}")
        }
    }
}