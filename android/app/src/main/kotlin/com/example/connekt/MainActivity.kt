package com.example.connekt

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.provider.CallLog
import android.provider.ContactsContract
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.connekt.app/call_logs"
    private val AUDIO_CHANNEL = "com.connekt.app/audio"
    private var audioMethodChannel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingContactsResult: MethodChannel.Result? = null
    private var pendingAudioPermResult: MethodChannel.Result? = null
    private val PERMISSION_REQUEST_CODE = 4101
    private val CONTACTS_PERMISSION_REQUEST_CODE = 4102
    private val AUDIO_PERMISSION_REQUEST_CODE = 4103

    private var mediaRecorder: MediaRecorder? = null
    private var recordingFilePath: String? = null
    private var mediaPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    val hasPerm = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED
                    result.success(hasPerm)
                }
                "requestPermission" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else {
                        pendingResult?.success(false)
                        pendingResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.READ_CALL_LOG, Manifest.permission.READ_CONTACTS),
                            PERMISSION_REQUEST_CODE
                        )
                    }
                }
                "getCallLogs" -> {
                    val limit = call.argument<Int>("limit") ?: 100
                    try {
                        val logs = fetchCallLogs(limit)
                        result.success(logs)
                    } catch (e: Exception) {
                        result.error("FETCH_ERROR", e.message, null)
                    }
                }
                "checkContactsPermission" -> {
                    val hasPerm = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED
                    result.success(hasPerm)
                }
                "requestContactsPermission" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else {
                        pendingContactsResult?.success(false)
                        pendingContactsResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.READ_CONTACTS),
                            CONTACTS_PERMISSION_REQUEST_CODE
                        )
                    }
                }
                "getContacts" -> {
                    val limit = call.argument<Int>("limit") ?: 250
                    try {
                        val contacts = fetchDeviceContacts(limit)
                        result.success(contacts)
                    } catch (e: Exception) {
                        result.error("CONTACTS_FETCH_ERROR", e.message, null)
                    }
                }
                "sendSmsInvite" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    if (phone.isBlank()) {
                        result.success(false)
                    } else {
                        try {
                            val uri = Uri.parse("smsto:${Uri.encode(phone)}")
                            val intent = Intent(Intent.ACTION_SENDTO, uri).apply {
                                putExtra("sms_body", message)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        audioMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
        audioMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestAudioPermission" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else {
                        pendingAudioPermResult?.success(false)
                        pendingAudioPermResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.RECORD_AUDIO),
                            AUDIO_PERMISSION_REQUEST_CODE
                        )
                    }
                }
                "startRecording" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                        result.error("PERMISSION_DENIED", "Microphone permission not granted", null)
                    } else {
                        try {
                            val path = beginAudioRecording()
                            result.success(mapOf("started" to true, "path" to path))
                        } catch (e: Exception) {
                            stopAndReleaseRecorder(discard = true)
                            result.error("RECORD_START_ERROR", e.message ?: "Failed to start recorder", null)
                        }
                    }
                }
                "stopRecording" -> {
                    val discard = call.argument<Boolean>("discard") ?: false
                    try {
                        val info = stopAndReleaseRecorder(discard = discard)
                        result.success(info)
                    } catch (e: Exception) {
                        result.error("RECORD_STOP_ERROR", e.message ?: "Failed to stop recorder", null)
                    }
                }
                "getAmplitude" -> {
                    val rawAmp = try {
                        mediaRecorder?.maxAmplitude ?: 0
                    } catch (_: Exception) {
                        0
                    }
                    val normalized = (rawAmp.toDouble() / 32767.0).coerceIn(0.0, 1.0)
                    result.success(normalized)
                }
                "playAudio" -> {
                    val primary = call.argument<String>("source") ?: ""
                    val fallback = call.argument<String>("fallbackSource") ?: ""
                    val chosen = when {
                        primary.startsWith("http://") || primary.startsWith("https://") -> primary
                        primary.isNotBlank() && File(primary).exists() && File(primary).length() > 0L -> primary
                        fallback.isNotBlank() -> fallback
                        else -> primary
                    }
                    if (chosen.isBlank()) {
                        result.error("NO_SOURCE", "No audio source available", null)
                    } else {
                        startAudioPlayback(chosen, result)
                    }
                }
                "stopAudio" -> {
                    stopAndReleasePlayer()
                    result.success(true)
                }
                "getPlaybackStatus" -> {
                    val player = mediaPlayer
                    if (player == null) {
                        result.success(mapOf("isPlaying" to false, "positionMs" to 0, "durationMs" to 0))
                    } else {
                        try {
                            result.success(
                                mapOf(
                                    "isPlaying" to player.isPlaying,
                                    "positionMs" to player.currentPosition,
                                    "durationMs" to player.duration
                                )
                            )
                        } catch (_: Exception) {
                            result.success(mapOf("isPlaying" to false, "positionMs" to 0, "durationMs" to 0))
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        stopAndReleaseRecorder(discard = false)
        stopAndReleasePlayer()
        super.onDestroy()
    }

    private fun beginAudioRecording(): String {
        stopAndReleaseRecorder(discard = true)
        val outFile = File(cacheDir, "connekt_voice_${System.currentTimeMillis()}.m4a")
        val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        recorder.apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioEncodingBitRate(96000)
            setAudioSamplingRate(44100)
            setOutputFile(outFile.absolutePath)
            prepare()
            start()
        }
        mediaRecorder = recorder
        recordingFilePath = outFile.absolutePath
        return outFile.absolutePath
    }

    private fun stopAndReleaseRecorder(discard: Boolean): Map<String, Any>? {
        val recorder = mediaRecorder
        val path = recordingFilePath
        mediaRecorder = null
        recordingFilePath = null

        if (recorder != null) {
            try {
                recorder.stop()
            } catch (_: Exception) {
            }
            try {
                recorder.reset()
            } catch (_: Exception) {
            }
            try {
                recorder.release()
            } catch (_: Exception) {
            }
        }

        if (path == null) return null
        val file = File(path)
        if (discard) {
            if (file.exists()) file.delete()
            return null
        }
        if (!file.exists() || file.length() <= 0L) return null
        return mapOf(
            "path" to file.absolutePath,
            "size" to file.length()
        )
    }

    private fun startAudioPlayback(source: String, result: MethodChannel.Result) {
        stopAndReleasePlayer()
        var replied = false
        try {
            val player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .build()
                )
                setOnCompletionListener {
                    stopAndReleasePlayer()
                    runOnUiThread {
                        audioMethodChannel?.invokeMethod("onPlaybackCompleted", null)
                    }
                }
                setOnErrorListener { _, what, extra ->
                    if (!replied) {
                        replied = true
                        result.error("PLAYBACK_ERROR", "MediaPlayer error ($what/$extra)", null)
                    }
                    stopAndReleasePlayer()
                    runOnUiThread {
                        audioMethodChannel?.invokeMethod("onPlaybackCompleted", null)
                    }
                    true
                }
                setDataSource(source)
                if (source.startsWith("http://") || source.startsWith("https://")) {
                    setOnPreparedListener { mp ->
                        mp.start()
                        if (!replied) {
                            replied = true
                            result.success(mapOf("started" to true, "durationMs" to mp.duration))
                        }
                    }
                    prepareAsync()
                } else {
                    prepare()
                    start()
                    if (!replied) {
                        replied = true
                        result.success(mapOf("started" to true, "durationMs" to duration))
                    }
                }
            }
            mediaPlayer = player
        } catch (e: Exception) {
            stopAndReleasePlayer()
            if (!replied) {
                replied = true
                result.error("PLAYBACK_ERROR", e.message ?: "Failed to play audio", null)
            }
        }
    }

    private fun stopAndReleasePlayer() {
        val player = mediaPlayer
        mediaPlayer = null
        if (player != null) {
            try {
                if (player.isPlaying) player.stop()
            } catch (_: Exception) {
            }
            try {
                player.reset()
            } catch (_: Exception) {
            }
            try {
                player.release()
            } catch (_: Exception) {
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == AUDIO_PERMISSION_REQUEST_CODE) {
            val audioIdx = permissions.indexOf(Manifest.permission.RECORD_AUDIO)
            val granted = if (audioIdx >= 0 && audioIdx < grantResults.size) {
                grantResults[audioIdx] == PackageManager.PERMISSION_GRANTED
            } else {
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            }
            pendingAudioPermResult?.success(granted)
            pendingAudioPermResult = null
            return
        }
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val callLogIdx = permissions.indexOf(Manifest.permission.READ_CALL_LOG)
            val granted = if (callLogIdx >= 0 && callLogIdx < grantResults.size) {
                grantResults[callLogIdx] == PackageManager.PERMISSION_GRANTED
            } else {
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            }
            pendingResult?.success(granted)
            pendingResult = null
        } else if (requestCode == CONTACTS_PERMISSION_REQUEST_CODE) {
            val contactsIdx = permissions.indexOf(Manifest.permission.READ_CONTACTS)
            val granted = if (contactsIdx >= 0 && contactsIdx < grantResults.size) {
                grantResults[contactsIdx] == PackageManager.PERMISSION_GRANTED
            } else {
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            }
            pendingContactsResult?.success(granted)
            pendingContactsResult = null
        }
    }

    private fun fetchCallLogs(limit: Int): List<Map<String, Any?>> {
        val callLogs = mutableListOf<Map<String, Any?>>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
            return callLogs
        }

        val maxItems = if (limit > 0) limit else 100
        val projection = arrayOf(
            CallLog.Calls._ID,
            CallLog.Calls.NUMBER,
            CallLog.Calls.CACHED_NAME,
            CallLog.Calls.TYPE,
            CallLog.Calls.DATE,
            CallLog.Calls.DURATION
        )

        // Do not embed LIMIT in sortOrder: Android 10+ CallLogProvider rejects LIMIT tokens in sortOrder.
        val cursor: Cursor? = contentResolver.query(
            CallLog.Calls.CONTENT_URI,
            projection,
            null,
            null,
            "${CallLog.Calls.DATE} DESC"
        )

        cursor?.use {
            val numberIdx = it.getColumnIndex(CallLog.Calls.NUMBER)
            val nameIdx = it.getColumnIndex(CallLog.Calls.CACHED_NAME)
            val typeIdx = it.getColumnIndex(CallLog.Calls.TYPE)
            val dateIdx = it.getColumnIndex(CallLog.Calls.DATE)
            val durationIdx = it.getColumnIndex(CallLog.Calls.DURATION)

            while (it.moveToNext() && callLogs.size < maxItems) {
                val number = if (numberIdx != -1) it.getString(numberIdx) ?: "" else ""
                val name = if (nameIdx != -1) it.getString(nameIdx) ?: "" else ""
                val typeCode = if (typeIdx != -1) it.getInt(typeIdx) else 0
                val dateMillis = if (dateIdx != -1) it.getLong(dateIdx) else 0L
                val duration = if (durationIdx != -1) it.getInt(durationIdx) else 0

                val typeStr = when (typeCode) {
                    CallLog.Calls.INCOMING_TYPE,
                    CallLog.Calls.ANSWERED_EXTERNALLY_TYPE -> "incoming"
                    CallLog.Calls.OUTGOING_TYPE -> "outgoing"
                    CallLog.Calls.MISSED_TYPE -> "missed"
                    CallLog.Calls.REJECTED_TYPE,
                    CallLog.Calls.BLOCKED_TYPE -> "rejected"
                    CallLog.Calls.VOICEMAIL_TYPE -> "voicemail"
                    else -> "unknown"
                }

                val logMap = HashMap<String, Any?>()
                logMap["number"] = number.ifBlank { "Unknown" }
                logMap["name"] = if (name.isNotBlank()) name else (if (number.isNotBlank()) number else "Unknown Caller")
                logMap["type"] = typeStr
                logMap["timestamp"] = dateMillis
                logMap["duration"] = duration
                callLogs.add(logMap)
            }
        }

        return callLogs
    }

    private fun fetchDeviceContacts(limit: Int): List<Map<String, Any?>> {
        val contacts = mutableListOf<Map<String, Any?>>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
            return contacts
        }

        val maxItems = if (limit > 0) limit else 250
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
            ContactsContract.CommonDataKinds.Phone.NORMALIZED_NUMBER
        )

        val cursor: Cursor? = contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            projection,
            null,
            null,
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
        )

        val seenKeys = HashSet<String>()
        cursor?.use {
            val idIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)
            val nameIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val numberIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
            val normIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NORMALIZED_NUMBER)

            while (it.moveToNext() && contacts.size < maxItems) {
                val contactId = if (idIdx != -1) it.getString(idIdx) ?: "" else ""
                val rawPhone = if (numberIdx != -1) (it.getString(numberIdx) ?: "").trim() else ""
                val normPhone = if (normIdx != -1) (it.getString(normIdx) ?: "").trim() else ""
                if (rawPhone.isBlank() && normPhone.isBlank()) continue

                val displayPhone = rawPhone.ifBlank { normPhone }
                val rawName = if (nameIdx != -1) (it.getString(nameIdx) ?: "").trim() else ""
                val displayName = rawName.ifBlank { displayPhone }

                val digitsOnly = displayPhone.filter { ch -> ch.isDigit() || ch == '+' }
                val dedupeKey = "${displayName.lowercase()}|${normPhone.ifBlank { digitsOnly }}"
                if (!seenKeys.add(dedupeKey)) continue

                val contactMap = HashMap<String, Any?>()
                contactMap["id"] = contactId.ifBlank { "phone_${contacts.size}" }
                contactMap["name"] = displayName
                contactMap["phone"] = displayPhone
                contacts.add(contactMap)
            }
        }

        return contacts
    }
}
