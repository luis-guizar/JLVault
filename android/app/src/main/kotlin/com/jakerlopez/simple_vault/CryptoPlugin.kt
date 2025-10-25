package com.jakerlopez.simple_vault

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.security.SecureRandom
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec
import java.security.MessageDigest
import java.util.Base64
import org.json.JSONObject
import org.json.JSONArray

class CryptoPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val cryptoScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val keyCache = mutableMapOf<String, ByteArray>()
    private val saltCache = mutableMapOf<String, ByteArray>()

    companion object {
        private const val CHANNEL = "com.simplevault/crypto"
        private const val AES_TRANSFORMATION = "AES/GCM/NoPadding"
        private const val KEY_LENGTH = 32 // 256 bits
        private const val IV_LENGTH = 12 // GCM standard
        private const val TAG_LENGTH = 16 // 128 bits
        
        // Argon2 parameters (simplified for demo - use actual Argon2 library in production)
        private const val PBKDF2_ITERATIONS = 100000
        private const val SALT_LENGTH = 32
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        cryptoScope.cancel()
        clearCache()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                result.success(null)
            }
            "isAvailable" -> {
                result.success(true)
            }
            "encryptAccount" -> {
                handleEncryptAccount(call, result)
            }
            "decryptAccount" -> {
                handleDecryptAccount(call, result)
            }
            "decryptAccounts" -> {
                handleDecryptAccounts(call, result)
            }
            "deriveVaultKey" -> {
                handleDeriveVaultKey(call, result)
            }
            "clearCache" -> {
                clearCache()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun handleEncryptAccount(call: MethodCall, result: Result) {
        cryptoScope.launch {
            try {
                val account = call.argument<Map<String, Any>>("account")!!
                val vaultId = call.argument<String>("vaultId")!!
                val masterPassword = call.argument<String>("masterPassword")!!

                val encryptedAccount = encryptAccount(account, vaultId, masterPassword)
                
                withContext(Dispatchers.Main) {
                    result.success(encryptedAccount)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("ENCRYPTION_ERROR", e.message, null)
                }
            }
        }
    }

    private fun handleDecryptAccount(call: MethodCall, result: Result) {
        cryptoScope.launch {
            try {
                val account = call.argument<Map<String, Any>>("account")!!
                val vaultId = call.argument<String>("vaultId")!!
                val masterPassword = call.argument<String>("masterPassword")!!

                val decryptedAccount = decryptAccount(account, vaultId, masterPassword)
                
                withContext(Dispatchers.Main) {
                    result.success(decryptedAccount)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("DECRYPTION_ERROR", e.message, null)
                }
            }
        }
    }

    private fun handleDecryptAccounts(call: MethodCall, result: Result) {
        cryptoScope.launch {
            try {
                val accounts = call.argument<List<Map<String, Any>>>("accounts")!!
                val vaultId = call.argument<String>("vaultId")!!
                val masterPassword = call.argument<String>("masterPassword")!!

                val decryptedAccounts = decryptAccounts(accounts, vaultId, masterPassword)
                
                withContext(Dispatchers.Main) {
                    result.success(decryptedAccounts)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("BATCH_DECRYPTION_ERROR", e.message, null)
                }
            }
        }
    }

    private fun handleDeriveVaultKey(call: MethodCall, result: Result) {
        cryptoScope.launch {
            try {
                val vaultId = call.argument<String>("vaultId")!!
                val masterPassword = call.argument<String>("masterPassword")!!

                val key = deriveVaultKey(vaultId, masterPassword)
                val keyBase64 = Base64.getEncoder().encodeToString(key)
                
                withContext(Dispatchers.Main) {
                    result.success(keyBase64)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("KEY_DERIVATION_ERROR", e.message, null)
                }
            }
        }
    }

    private suspend fun encryptAccount(
        account: Map<String, Any>,
        vaultId: String,
        masterPassword: String
    ): Map<String, Any> = withContext(Dispatchers.IO) {
        val key = deriveVaultKey(vaultId, masterPassword)
        val result = account.toMutableMap()

        // Encrypt sensitive fields
        result["username"] = encryptString(account["username"] as String, key)
        result["password"] = encryptString(account["password"] as String, key)
        
        // Handle TOTP config if present
        account["totp_config"]?.let { totpConfig ->
            if (totpConfig is Map<*, *>) {
                val totpJson = JSONObject(totpConfig as Map<String, Any>).toString()
                result["totp_config"] = encryptString(totpJson, key)
            }
        }

        result
    }

    private suspend fun decryptAccount(
        account: Map<String, Any>,
        vaultId: String,
        masterPassword: String
    ): Map<String, Any> = withContext(Dispatchers.IO) {
        val key = deriveVaultKey(vaultId, masterPassword)
        val result = account.toMutableMap()

        // Decrypt sensitive fields
        result["username"] = decryptString(account["username"] as String, key)
        result["password"] = decryptString(account["password"] as String, key)
        
        // Handle TOTP config if present
        account["totp_config"]?.let { encryptedTotpConfig ->
            if (encryptedTotpConfig is String) {
                try {
                    val decryptedJson = decryptString(encryptedTotpConfig, key)
                    val totpObject = JSONObject(decryptedJson)
                    result["totp_config"] = jsonObjectToMap(totpObject)
                } catch (e: Exception) {
                    // If decryption fails, assume it's already decrypted
                    result["totp_config"] = encryptedTotpConfig
                }
            }
        }

        result
    }

    private suspend fun decryptAccounts(
        accounts: List<Map<String, Any>>,
        vaultId: String,
        masterPassword: String
    ): List<Map<String, Any>> = withContext(Dispatchers.IO) {
        val key = deriveVaultKey(vaultId, masterPassword)
        
        // Process accounts in parallel for better performance
        accounts.map { account ->
            async {
                try {
                    decryptAccountWithKey(account, key)
                } catch (e: Exception) {
                    // Return original account if decryption fails
                    account
                }
            }
        }.awaitAll()
    }

    private fun decryptAccountWithKey(
        account: Map<String, Any>,
        key: ByteArray
    ): Map<String, Any> {
        val result = account.toMutableMap()

        // Decrypt sensitive fields
        result["username"] = decryptString(account["username"] as String, key)
        result["password"] = decryptString(account["password"] as String, key)
        
        // Handle TOTP config if present
        account["totp_config"]?.let { encryptedTotpConfig ->
            if (encryptedTotpConfig is String) {
                try {
                    val decryptedJson = decryptString(encryptedTotpConfig, key)
                    val totpObject = JSONObject(decryptedJson)
                    result["totp_config"] = jsonObjectToMap(totpObject)
                } catch (e: Exception) {
                    // If decryption fails, assume it's already decrypted
                    result["totp_config"] = encryptedTotpConfig
                }
            }
        }

        return result
    }

    private fun deriveVaultKey(vaultId: String, masterPassword: String): ByteArray {
        // Check cache first
        val cacheKey = "$vaultId:${masterPassword.hashCode()}"
        keyCache[cacheKey]?.let { return it }

        // Get or generate salt
        val salt = saltCache.getOrPut(vaultId) {
            // In production, this should be stored securely
            generateSalt()
        }

        // Derive key using PBKDF2 (simplified - use Argon2 in production)
        val key = deriveKeyPBKDF2(masterPassword, salt)
        
        // Cache the key
        keyCache[cacheKey] = key
        
        return key
    }

    private fun deriveKeyPBKDF2(password: String, salt: ByteArray): ByteArray {
        val spec = javax.crypto.spec.PBEKeySpec(
            password.toCharArray(),
            salt,
            PBKDF2_ITERATIONS,
            KEY_LENGTH * 8
        )
        val factory = javax.crypto.SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
        return factory.generateSecret(spec).encoded
    }

    private fun generateSalt(): ByteArray {
        val salt = ByteArray(SALT_LENGTH)
        SecureRandom().nextBytes(salt)
        return salt
    }

    private fun encryptString(plaintext: String, key: ByteArray): String {
        val cipher = Cipher.getInstance(AES_TRANSFORMATION)
        val secretKey = SecretKeySpec(key, "AES")
        
        // Generate random IV
        val iv = ByteArray(IV_LENGTH)
        SecureRandom().nextBytes(iv)
        
        val gcmSpec = GCMParameterSpec(TAG_LENGTH * 8, iv)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey, gcmSpec)
        
        val ciphertext = cipher.doFinal(plaintext.toByteArray())
        
        // Combine IV and ciphertext
        val combined = iv + ciphertext
        return Base64.getEncoder().encodeToString(combined)
    }

    private fun decryptString(ciphertext: String, key: ByteArray): String {
        val combined = Base64.getDecoder().decode(ciphertext)
        
        // Extract IV and ciphertext
        val iv = combined.sliceArray(0 until IV_LENGTH)
        val encrypted = combined.sliceArray(IV_LENGTH until combined.size)
        
        val cipher = Cipher.getInstance(AES_TRANSFORMATION)
        val secretKey = SecretKeySpec(key, "AES")
        val gcmSpec = GCMParameterSpec(TAG_LENGTH * 8, iv)
        
        cipher.init(Cipher.DECRYPT_MODE, secretKey, gcmSpec)
        val decrypted = cipher.doFinal(encrypted)
        
        return String(decrypted)
    }

    private fun jsonObjectToMap(jsonObject: JSONObject): Map<String, Any> {
        val map = mutableMapOf<String, Any>()
        val keys = jsonObject.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = jsonObject.get(key)
            map[key] = when (value) {
                is JSONObject -> jsonObjectToMap(value)
                is JSONArray -> jsonArrayToList(value)
                else -> value
            }
        }
        return map
    }

    private fun jsonArrayToList(jsonArray: JSONArray): List<Any> {
        val list = mutableListOf<Any>()
        for (i in 0 until jsonArray.length()) {
            val value = jsonArray.get(i)
            list.add(when (value) {
                is JSONObject -> jsonObjectToMap(value)
                is JSONArray -> jsonArrayToList(value)
                else -> value
            })
        }
        return list
    }

    private fun clearCache() {
        keyCache.clear()
        saltCache.clear()
    }
}