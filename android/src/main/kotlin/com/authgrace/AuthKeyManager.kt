package com.authgrace

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.UserNotAuthenticatedException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

object AuthKeyManager {

    private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
    // IMPORTANT: namespaced key name to avoid collision with other packages
    private const val DEFAULT_KEY_NAME = "com.authgrace.auth_grace_key"
    private const val TRANSFORMATION =
        "${KeyProperties.KEY_ALGORITHM_AES}/" +
        "${KeyProperties.BLOCK_MODE_CBC}/" +
        "${KeyProperties.ENCRYPTION_PADDING_PKCS7}"

    fun generateKey(gracePeriodSeconds: Int, keyName: String = DEFAULT_KEY_NAME) {
        val builder = KeyGenParameterSpec.Builder(
            keyName,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_CBC)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_PKCS7)
            .setUserAuthenticationRequired(true)

        // Android 11+ (API 30): use newer API for better auth type control
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setUserAuthenticationParameters(
                gracePeriodSeconds,
                KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL
            )
        } else {
            @Suppress("DEPRECATION")
            builder.setUserAuthenticationValidityDurationSeconds(gracePeriodSeconds)
        }

        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE_PROVIDER)
        keyGenerator.init(builder.build())
        keyGenerator.generateKey()
    }

    fun isWithinGracePeriod(keyName: String = DEFAULT_KEY_NAME): Boolean {
        // Emulator has no real TEE — skip Keystore check entirely
        if (isEmulator()) return false

        return try {
            val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
            keyStore.load(null)

            val key = keyStore.getKey(keyName, null) as? SecretKey ?: return false

            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, key)

            // Success = phone was unlocked within grace period
            true

        } catch (e: UserNotAuthenticatedException) {
            // Grace period expired
            false

        } catch (e: KeyPermanentlyInvalidatedException) {
            // User changed biometrics — silently delete and regenerate
            deleteKey(keyName)
            false

        } catch (e: Exception) {
            false
        }
    }

    fun keyExists(keyName: String = DEFAULT_KEY_NAME): Boolean {
        return try {
            val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
            keyStore.load(null)
            keyStore.containsAlias(keyName)
        } catch (e: Exception) {
            false
        }
    }

    fun deleteKey(keyName: String = DEFAULT_KEY_NAME) {
        try {
            val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
            keyStore.load(null)
            if (keyStore.containsAlias(keyName)) {
                keyStore.deleteEntry(keyName)
            }
        } catch (e: Exception) {
            // ignore
        }
    }

    fun isHardwareBacked(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
                keyStore.load(null)
                true // If we can load AndroidKeyStore on API 31+, TEE exists
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun isEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
            || Build.FINGERPRINT.startsWith("unknown")
            || Build.MODEL.contains("Emulator")
            || Build.MODEL.contains("Android SDK built for x86")
            || Build.MANUFACTURER.contains("Genymotion")
            || Build.BRAND.startsWith("generic"))
    }
}
