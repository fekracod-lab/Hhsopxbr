package com.dalal.alqaimapp

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.dalal.alqaimapp/signing"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // The native super call handles automatic plugin registration via FlutterActivity.
        super.configureFlutterEngine(flutterEngine)

        // custom method channel for signing information
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getSha1") {
                try {
                    val sha1 = getSigningSha1()
                    result.success(sha1)
                } catch (e: Exception) {
                    result.error("ERROR", "Failed to get SHA1: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getSigningSha1(): String? {
        try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            }

            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                packageInfo.signatures
            }

            if (signatures != null && signatures.isNotEmpty()) {
                val md = MessageDigest.getInstance("SHA-1")
                val digest = md.digest(signatures[0].toByteArray())
                return digest.joinToString("") { "%02X".format(it) }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }
}
