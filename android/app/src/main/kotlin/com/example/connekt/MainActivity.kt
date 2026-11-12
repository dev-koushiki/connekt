package com.example.connekt

import android.Manifest
import android.content.pm.PackageManager
import android.database.Cursor
import android.provider.CallLog
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.connekt.app/call_logs"
    private var pendingResult: MethodChannel.Result? = null
    private val PERMISSION_REQUEST_CODE = 4101

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
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val callLogIdx = permissions.indexOf(Manifest.permission.READ_CALL_LOG)
            val granted = if (callLogIdx >= 0 && callLogIdx < grantResults.size) {
                grantResults[callLogIdx] == PackageManager.PERMISSION_GRANTED
            } else {
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            }
            pendingResult?.success(granted)
            pendingResult = null
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
}
