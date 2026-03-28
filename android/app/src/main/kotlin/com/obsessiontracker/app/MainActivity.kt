package com.obsessiontracker.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipFile

/**
 * MainActivity for Obsession Tracker
 *
 * Handles Flutter app initialization and platform-specific integrations
 * including file handling, permissions, and background services.
 *
 * IMPORTANT: Extends FlutterFragmentActivity (not FlutterActivity) to support
 * biometric authentication via local_auth plugin.
 */
class MainActivity: FlutterFragmentActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val INCOMING_FILE_CHANNEL = "obsessiontracker/incoming_file"
        private val SUPPORTED_EXTENSIONS = listOf("obstrack", "obk", "gpx", "kml")
    }

    private val CHANNEL = "com.obsessiontracker.app/platform"

    // Pending file path to send to Flutter after engine is ready
    private var pendingFilePath: String? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Set up method channel for platform-specific functionality
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceInfo" -> {
                    result.success(getDeviceInfo())
                }
                "requestPermissions" -> {
                    // Handle permission requests
                    result.success("permissions_requested")
                }
                "openSystemSettings" -> {
                    openSystemSettings()
                    result.success("settings_opened")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Send any pending file that was received before Flutter was ready
        pendingFilePath?.let { filePath ->
            Log.d(TAG, "Sending pending file to Flutter: $filePath")
            sendFileToFlutter(filePath)
            pendingFilePath = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Handle intent if app was opened with a file
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)

        // When onNewIntent is called, Flutter engine is already ready
        // So send any pending file immediately
        pendingFilePath?.let { filePath ->
            Log.d(TAG, "Sending file to Flutter from onNewIntent: $filePath")
            sendFileToFlutter(filePath)
            pendingFilePath = null
        }
    }

    /**
     * Handle file opening intents (.obstrack, .obk, .gpx, .kml files)
     */
    private fun handleIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return

        val uri: Uri = intent.data ?: return
        Log.d(TAG, "Received URI: $uri")

        // Get file name from URI
        var fileName = getFileNameFromUri(uri)
        Log.d(TAG, "File name: $fileName")

        // Check if it's a supported file type
        var extension = fileName?.substringAfterLast('.', "")?.lowercase()

        // If extension is missing or not supported, we'll try to detect from content
        val needsDetection = extension.isNullOrEmpty() || !SUPPORTED_EXTENSIONS.contains(extension)

        if (needsDetection) {
            Log.d(TAG, "Extension missing or unsupported ($extension), will detect from content")

            // Copy the file first, then detect type
            val tempPath = copyUriToLocalStorage(uri, fileName ?: "unknown_file")
            if (tempPath == null) {
                Log.e(TAG, "Failed to copy file to local storage")
                return
            }

            // Try to detect file type from content
            val detectedType = detectFileType(tempPath)
            if (detectedType == null) {
                Log.d(TAG, "Could not detect file type, ignoring")
                // Clean up temp file
                File(tempPath).delete()
                return
            }

            Log.d(TAG, "Detected file type: $detectedType")

            // Rename file with correct extension
            val tempFile = File(tempPath)
            val newFileName = "${fileName ?: "import"}.${detectedType}"
            val newFile = File(tempFile.parent, newFileName)
            if (newFile.exists()) newFile.delete()
            tempFile.renameTo(newFile)

            Log.d(TAG, "Renamed file to: ${newFile.absolutePath}")
            // Store for later - Flutter engine not ready yet during onCreate
            pendingFilePath = newFile.absolutePath
            return
        }

        // Extension is valid, proceed normally
        val localPath = copyUriToLocalStorage(uri, fileName)
        if (localPath == null) {
            Log.e(TAG, "Failed to copy file to local storage")
            return
        }

        Log.d(TAG, "Copied file to: $localPath")
        // Store for later - Flutter engine not ready yet during onCreate
        pendingFilePath = localPath
    }

    /**
     * Detect file type by examining content
     *
     * Both .obk and .obstrack are ZIP files:
     * - .obk contains manifest.json (full backup)
     * - .obstrack contains session.json (session export)
     * - .gpx is XML starting with <?xml or <gpx
     * - .kml is XML starting with <?xml or <kml
     */
    private fun detectFileType(filePath: String): String? {
        val file = File(filePath)
        if (!file.exists()) {
            Log.e(TAG, "detectFileType: File does not exist: $filePath")
            return null
        }

        Log.d(TAG, "detectFileType: File size: ${file.length()} bytes")

        // Log first few bytes to help diagnose
        try {
            file.inputStream().use { stream ->
                val header = ByteArray(4)
                val bytesRead = stream.read(header)
                if (bytesRead >= 4) {
                    val hexHeader = header.joinToString(" ") { String.format("%02X", it) }
                    Log.d(TAG, "detectFileType: File header (hex): $hexHeader")
                    // ZIP files start with PK (50 4B)
                    if (header[0] == 0x50.toByte() && header[1] == 0x4B.toByte()) {
                        Log.d(TAG, "detectFileType: File has ZIP signature (PK)")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "detectFileType: Error reading header: ${e.message}")
        }

        try {
            // Check if it's a ZIP file (for .obk and .obstrack)
            ZipFile(file).use { zip ->
                // Check for manifest.json (indicates .obk backup)
                if (zip.getEntry("manifest.json") != null) {
                    Log.d(TAG, "Detected .obk file (contains manifest.json)")
                    return "obk"
                }

                // Check for session.json (indicates .obstrack session export)
                if (zip.getEntry("session.json") != null) {
                    Log.d(TAG, "Detected .obstrack file (contains session.json)")
                    return "obstrack"
                }

                Log.d(TAG, "ZIP file but unknown format")
                return null
            }
        } catch (e: Exception) {
            // Not a ZIP file, check for XML formats
            Log.e(TAG, "Not a ZIP file: ${e.javaClass.simpleName}: ${e.message}")
        }

        // Check for GPX/KML (XML formats)
        try {
            file.inputStream().bufferedReader().use { reader ->
                // Read first 1000 chars to look for markers
                val buffer = CharArray(1000)
                val charsRead = reader.read(buffer)
                if (charsRead > 0) {
                    val content = String(buffer, 0, charsRead).lowercase()

                    if (content.contains("<gpx") || content.contains("xmlns=\"http://www.topografix.com/gpx")) {
                        Log.d(TAG, "Detected .gpx file")
                        return "gpx"
                    }

                    if (content.contains("<kml") || content.contains("xmlns=\"http://www.opengis.net/kml") ||
                        content.contains("xmlns=\"http://earth.google.com/kml")) {
                        Log.d(TAG, "Detected .kml file")
                        return "kml"
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading file for XML detection: ${e.message}")
        }

        // If we couldn't identify the file type, but it's binary data (not text/XML),
        // assume it's an encrypted .obk backup file.
        // .obk files are AES-256-GCM encrypted ZIP archives, so they appear as binary data.
        // The Flutter side will attempt to decrypt and validate - if it fails, it shows an error.
        if (file.length() > 100) {
            Log.d(TAG, "Unidentified binary file (${file.length()} bytes), assuming encrypted .obk backup")
            return "obk"
        }

        Log.d(TAG, "File too small or empty, cannot identify")
        return null
    }

    /**
     * Get file name from a content:// or file:// URI
     */
    private fun getFileNameFromUri(uri: Uri): String? {
        // For file:// URIs, get the last path segment
        if (uri.scheme == "file") {
            return uri.lastPathSegment
        }

        // For content:// URIs, query the content resolver
        var fileName: String? = null

        // Try to get display name from content resolver
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
            if (nameIndex >= 0 && cursor.moveToFirst()) {
                fileName = cursor.getString(nameIndex)
            }
        }

        // Fallback to last path segment if display name not available
        if (fileName == null) {
            fileName = uri.lastPathSegment
        }

        return fileName
    }

    /**
     * Copy a URI's content to local app storage
     * This handles content:// URIs from Google Drive, email attachments, etc.
     */
    private fun copyUriToLocalStorage(uri: Uri, fileName: String?): String? {
        return try {
            // Create imports directory in cache
            val importsDir = File(cacheDir, "imports")
            if (!importsDir.exists()) {
                importsDir.mkdirs()
            }

            // Generate destination file
            val destFile = File(importsDir, fileName ?: "import_${System.currentTimeMillis()}")

            // Delete existing file if present
            if (destFile.exists()) {
                destFile.delete()
            }

            // Copy content from URI to local file
            contentResolver.openInputStream(uri)?.use { inputStream ->
                FileOutputStream(destFile).use { outputStream ->
                    inputStream.copyTo(outputStream)
                }
            }

            destFile.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "Error copying URI to local storage: ${e.message}", e)
            null
        }
    }

    /**
     * Send the local file path to Flutter via method channel
     *
     * If Flutter engine isn't ready yet, store the path and it will be sent
     * when configureFlutterEngine is called.
     */
    private fun sendFileToFlutter(filePath: String) {
        val messenger = flutterEngine?.dartExecutor?.binaryMessenger
        if (messenger == null) {
            Log.d(TAG, "Flutter engine not ready, storing pending file: $filePath")
            pendingFilePath = filePath
            return
        }

        val channel = MethodChannel(messenger, INCOMING_FILE_CHANNEL)
        channel.invokeMethod("onFileReceived", filePath)
        Log.d(TAG, "Sent file to Flutter: $filePath")
    }

    /**
     * Get device information for debugging and compatibility
     */
    private fun getDeviceInfo(): Map<String, Any> {
        return mapOf(
            "model" to android.os.Build.MODEL,
            "manufacturer" to android.os.Build.MANUFACTURER,
            "version" to android.os.Build.VERSION.RELEASE,
            "sdk" to android.os.Build.VERSION.SDK_INT,
            "app_version" to getAppVersion()
        )
    }

    /**
     * Get app version from package manager
     */
    private fun getAppVersion(): String {
        return try {
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            packageInfo.versionName ?: "unknown"
        } catch (e: Exception) {
            "unknown"
        }
    }

    /**
     * Open system settings for the app
     */
    private fun openSystemSettings() {
        val intent = Intent().apply {
            action = android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS
            data = Uri.fromParts("package", packageName, null)
        }
        startActivity(intent)
    }
}
