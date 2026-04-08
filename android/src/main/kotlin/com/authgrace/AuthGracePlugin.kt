package com.authgrace

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AuthGracePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "auth_grace")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val keyName = call.argument<String>("keyName") ?: "com.authgrace.auth_grace_key"

        when (call.method) {
            "generateKey" -> {
                val seconds = call.argument<Int>("gracePeriodSeconds") ?: 30
                try {
                    AuthKeyManager.generateKey(seconds, keyName)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("KEY_GEN_FAILED", e.message, null)
                }
            }
            "isWithinGracePeriod" -> {
                result.success(AuthKeyManager.isWithinGracePeriod(keyName))
            }
            "keyExists" -> {
                result.success(AuthKeyManager.keyExists(keyName))
            }
            "deleteKey" -> {
                AuthKeyManager.deleteKey(keyName)
                result.success(true)
            }
            "isHardwareBacked" -> {
                result.success(AuthKeyManager.isHardwareBacked())
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
