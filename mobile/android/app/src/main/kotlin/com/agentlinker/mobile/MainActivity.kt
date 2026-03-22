package com.agentlinker.mobile

import android.Manifest
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val envChannelName = "com.agentlinker.mobile/env"
    private val channelName = "com.agentlinker.mobile/sms"
    private val smsPermRequest = 9201
    private var pendingSmsResult: MethodChannel.Result? = null
    private var pendingSmsLimit: Int = 50

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, envChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isEmulator" -> result.success(isEmulator())
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "readInbox" -> {
                    val limitArg = call.argument<Int>("limit") ?: 50
                    val limit = limitArg.coerceIn(1, 200)
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
                        pendingSmsResult = result
                        pendingSmsLimit = limit
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_SMS), smsPermRequest)
                    } else {
                        deliverInboxResult(result, limit)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isEmulator(): Boolean {
        return Build.FINGERPRINT.startsWith("generic")
            || Build.FINGERPRINT.startsWith("unknown")
            || Build.FINGERPRINT.contains("emu")
            || Build.MODEL.contains("google_sdk")
            || Build.MODEL.contains("Emulator")
            || Build.MODEL.contains("Android SDK built for x86")
            || Build.MANUFACTURER.contains("Genymotion")
            || (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
            || "google_sdk" == Build.PRODUCT
            || Build.PRODUCT.contains("sdk_gphone")
            || Build.PRODUCT.contains("emulator")
            || Build.HARDWARE.contains("goldfish")
            || Build.HARDWARE.contains("ranchu")
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != smsPermRequest) return
        val r = pendingSmsResult ?: return
        pendingSmsResult = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            deliverInboxResult(r, pendingSmsLimit)
        } else {
            r.error("PERMISSION_DENIED", "用户未授予 READ_SMS", null)
        }
    }

    private fun deliverInboxResult(result: MethodChannel.Result, limit: Int) {
        try {
            result.success(readSmsInbox(limit))
        } catch (e: Exception) {
            result.error("READ_FAILED", e.message, null)
        }
    }

    @SuppressLint("Range")
    private fun readSmsInbox(limit: Int): List<Map<String, Any?>> {
        val list = mutableListOf<Map<String, Any?>>()
        val uri = Telephony.Sms.Inbox.CONTENT_URI
        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.READ,
            Telephony.Sms.TYPE,
        )
        contentResolver.query(uri, projection, null, null, "${Telephony.Sms.DATE} DESC")?.use { cursor ->
            var n = 0
            while (cursor.moveToNext() && n < limit) {
                val idIdx = cursor.getColumnIndex(Telephony.Sms._ID)
                val addrIdx = cursor.getColumnIndex(Telephony.Sms.ADDRESS)
                val bodyIdx = cursor.getColumnIndex(Telephony.Sms.BODY)
                val dateIdx = cursor.getColumnIndex(Telephony.Sms.DATE)
                val readIdx = cursor.getColumnIndex(Telephony.Sms.READ)
                val typeIdx = cursor.getColumnIndex(Telephony.Sms.TYPE)
                val address = if (addrIdx >= 0) (cursor.getString(addrIdx) ?: "") else ""
                val body = if (bodyIdx >= 0) (cursor.getString(bodyIdx) ?: "") else ""
                list.add(
                    mapOf(
                        "_id" to (if (idIdx >= 0) cursor.getLong(idIdx) else 0L),
                        "address" to address,
                        "body" to body,
                        "date_ms" to (if (dateIdx >= 0) cursor.getLong(dateIdx) else 0L),
                        "read" to (if (readIdx >= 0) cursor.getInt(readIdx) == 1 else false),
                        "type" to (if (typeIdx >= 0) cursor.getInt(typeIdx) else 0),
                    ),
                )
                n++
            }
        }
        return list
    }
}
