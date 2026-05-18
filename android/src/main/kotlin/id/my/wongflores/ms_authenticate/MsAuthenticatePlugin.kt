package id.my.wongflores.ms_authenticate

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import android.app.Application
import android.os.Bundle


/** MsAuthenticatePlugin */
class MsAuthenticatePlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.NewIntentListener {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    
    private var pendingResult: Result? = null
    private var currentRedirectUrl: String? = null

    private var isLoginFlowActive = false
    private var isRedirectHandled = false
    private var lifecycleCallbacks: Application.ActivityLifecycleCallbacks? = null


    companion object {
        private const val TAG = "MsAuthenticatePlugin"
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ms_authenticate")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "loginWithMicrosoft" -> {
                val tenantId = call.argument<String>("tenantId")
                val clientId = call.argument<String>("clientId")
                val clientSecret = call.argument<String>("clientSecret")
                val redirectUrl = call.argument<String>("redirectUrl")
                val scope = call.argument<String>("scope")
                val tokenScope = call.argument<String>("tokenScope")
                val nonce = call.argument<String>("nonce")

                if (tenantId != null && clientId != null && redirectUrl != null && scope != null) {
                    loginWithMicrosoft(
                        tenantId = tenantId,
                        clientId = clientId,
                        clientSecret = clientSecret,
                        redirectUrl = redirectUrl,
                        scope = scope,
                        tokenScope = tokenScope,
                        nonce = nonce,
                        result = result
                    )
                } else {
                    result.error(
                        "INVALID_ARGS",
                        "Missing required arguments",
                        null
                    )
                }
            }
            "exchangeCodeForToken" -> {
                val tenantId = call.argument<String>("tenantId")
                val clientId = call.argument<String>("clientId")
                val clientSecret = call.argument<String>("clientSecret")
                val code = call.argument<String>("code")
                val redirectUrl = call.argument<String>("redirectUrl")
                val scope = call.argument<String>("scope")

                if (tenantId != null && clientId != null && code != null && redirectUrl != null) {
                    exchangeCodeForToken(tenantId, clientId, clientSecret, code, redirectUrl, scope, result)
                } else {
                    result.error(
                        "INVALID_ARGS",
                        "Missing required arguments for exchangeCodeForToken",
                        null
                    )
                }
            }
            "logout" -> {
                logout()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addOnNewIntentListener(this)
        registerLifecycleCallbacks()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        unregisterLifecycleCallbacks()
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addOnNewIntentListener(this)
        registerLifecycleCallbacks()
    }

    override fun onDetachedFromActivity() {
        unregisterLifecycleCallbacks()
        activity = null
    }

    private var currentTenantId: String? = null
    private var currentClientId: String? = null
    private var currentClientSecret: String? = null
    private var currentTokenScope: String? = null

    private fun loginWithMicrosoft(
        tenantId: String,
        clientId: String,
        clientSecret: String?,
        redirectUrl: String,
        scope: String,
        tokenScope: String?,
        nonce: String?,
        result: Result
    ) {
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity not available", null)
            return
        }

        // Simpan referensi result untuk nanti dipanggil di onNewIntent
        this.pendingResult = result
        this.currentRedirectUrl = redirectUrl
        this.currentTenantId = tenantId
        this.currentClientId = clientId
        this.currentClientSecret = clientSecret
        this.currentTokenScope = tokenScope

        // Reset state flags untuk tracking cancel
        this.isLoginFlowActive = true
        this.isRedirectHandled = false

        // Build authorization URL
        val authUrl = buildAuthorizationUrl(
            tenantId = tenantId,
            clientId = clientId,
            redirectUrl = redirectUrl,
            scope = scope,
            nonce = nonce
        )

        Log.d(TAG, "Auth URL: $authUrl")

        // Buka browser menggunakan CustomTabsIntent agar bisa tertutup otomatis saat redirect
        try {
            val builder = CustomTabsIntent.Builder()
            val customTabsIntent = builder.build()
            
            // Gunakan flag NO_HISTORY agar tidak meninggalkan jejak di history browser
            customTabsIntent.intent.addFlags(Intent.FLAG_ACTIVITY_NO_HISTORY)
            
            activity?.let {
                customTabsIntent.launchUrl(it, Uri.parse(authUrl))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Gagal membuka Custom Tab: ${e.message}. Mencoba fallback...")
            // Fallback ke Intent.ACTION_VIEW jika Custom Tabs gagal
            try {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(authUrl))
                intent.addFlags(Intent.FLAG_ACTIVITY_NO_HISTORY or Intent.FLAG_ACTIVITY_NEW_TASK)
                activity?.startActivity(intent)
            } catch (e2: Exception) {
                Log.e(TAG, "Gagal membuka browser fallback: ${e2.message}")
                pendingResult?.error("BROWSER_ERROR", "Could not launch browser: ${e2.message}", null)
                pendingResult = null
            }
        }
    }

    private fun buildAuthorizationUrl(
        tenantId: String,
        clientId: String,
        redirectUrl: String,
        scope: String,
        nonce: String?
    ): String {
        val baseUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize"
        val params = mutableMapOf(
            "client_id" to clientId,
            "response_type" to "code",
            "redirect_uri" to redirectUrl,
            "response_mode" to "query",
            "scope" to scope,
            "state" to java.util.UUID.randomUUID().toString().replace("-", ""),
            "prompt" to "login"
        )

        if (nonce != null) {
            params["nonce"] = nonce
        }

        val queryString = params.entries.joinToString("&") { (key, value) ->
            "$key=${java.net.URLEncoder.encode(value, "UTF-8")}"
        }

        return "$baseUrl?$queryString"
    }

    private fun exchangeCodeForToken(
        tenantId: String,
        clientId: String,
        clientSecret: String?,
        code: String,
        redirectUrl: String,
        scope: String?,
        result: Result
    ) {
        Thread {
            try {
                val urlString = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
                val url = java.net.URL(urlString)
                val conn = url.openConnection() as java.net.HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
                conn.doOutput = true

                val params = mutableMapOf(
                    "client_id" to clientId,
                    "code" to code,
                    "redirect_uri" to redirectUrl,
                    "grant_type" to "authorization_code"
                )
                
                if (clientSecret != null) {
                    params["client_secret"] = clientSecret
                }
                if (scope != null) {
                    params["scope"] = scope
                }

                val postData = params.entries.joinToString("&") { (key, value) ->
                    "${java.net.URLEncoder.encode(key, "UTF-8")}=${java.net.URLEncoder.encode(value, "UTF-8")}"
                }
                
                conn.outputStream.use { os ->
                    val input = postData.toByteArray(Charsets.UTF_8)
                    os.write(input, 0, input.size)
                }

                val responseCode = conn.responseCode
                if (responseCode == 200) {
                    val responseStr = conn.inputStream.bufferedReader().use { it.readText() }
                    val jsonObject = org.json.JSONObject(responseStr)
                    
                    val tokenMap = mutableMapOf<String, Any>()
                    val keys = jsonObject.keys()
                    while (keys.hasNext()) {
                        val key = keys.next()
                        tokenMap[key] = jsonObject.get(key)
                    }

                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        result.success(tokenMap)
                    }
                } else {
                    val errorStr = try {
                        conn.errorStream?.bufferedReader()?.use { it.readText() }
                    } catch (e: Exception) { null }
                    
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        result.error("TOKEN_EXCHANGE_FAILED", "Response code: $responseCode, error: $errorStr", null)
                    }
                }
            } catch (e: Exception) {
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    result.error("NETWORK_ERROR", e.message, null)
                }
            }
        }.start()
    }

    override fun onNewIntent(intent: Intent): Boolean {
        val action = intent.action
        val data = intent.dataString

        if (Intent.ACTION_VIEW == action && data != null && currentRedirectUrl != null) {
            // Cek apakah url redirect sesuai
            if (data.startsWith(currentRedirectUrl!!, ignoreCase = true)) {
                this.isRedirectHandled = true
                this.isLoginFlowActive = false
                //Log.d(TAG, "Redirect URI tertangkap: $data")
                
                val code = extractCodeFromUrl(data)
                if (code != null) {
                    //Log.d(TAG, "Authorization code extracted: $code. Exchanging for token...")
                    
                    val pr = pendingResult
                    val tId = currentTenantId
                    val cId = currentClientId
                    val cSecret = currentClientSecret
                    val rUrl = currentRedirectUrl
                    val tScope = currentTokenScope
                    
                    if (pr != null && tId != null && cId != null && rUrl != null) {
                        exchangeCodeForToken(tId, cId, cSecret, code, rUrl, tScope, pr)
                    } else {
                        pendingResult?.error("MISSING_DATA", "Missing data to exchange token", null)
                        pendingResult = null
                    }
                } else {
                    val error = extractErrorFromUrl(data)
                    pendingResult?.error("AUTH_FAILED", error ?: "Failed to extract authorization code", null)
                    pendingResult = null
                }
                
                return true
            }
        }
        return false
    }

    private fun extractCodeFromUrl(url: String): String? {
        return try {
            val uri = Uri.parse(url)
            uri.getQueryParameter("code")
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting code: ${e.message}")
            null
        }
    }

    private fun extractErrorFromUrl(url: String): String? {
        return try {
            val uri = Uri.parse(url)
            uri.getQueryParameter("error") ?: uri.getQueryParameter("error_description")
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting error: ${e.message}")
            null
        }
    }

    private fun registerLifecycleCallbacks() {
        if (lifecycleCallbacks != null) return
        
        val application = activity?.application ?: return
        lifecycleCallbacks = object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
            override fun onActivityStarted(activity: Activity) {}
            
            override fun onActivityResumed(act: Activity) {
                if (act == activity) {
                    if (isLoginFlowActive && !isRedirectHandled) {
                        Log.d(TAG, "User returned to app without redirect. Assuming cancellation.")
                        pendingResult?.error("AUTH_CANCELLED", "User cancelled login", null)
                        pendingResult = null
                        isLoginFlowActive = false
                    }
                }
            }
            
            override fun onActivityPaused(activity: Activity) {}
            override fun onActivityStopped(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityDestroyed(activity: Activity) {}
        }
        application.registerActivityLifecycleCallbacks(lifecycleCallbacks)
    }

    private fun unregisterLifecycleCallbacks() {
        val application = activity?.application ?: return
        lifecycleCallbacks?.let {
            application.unregisterActivityLifecycleCallbacks(it)
        }
        lifecycleCallbacks = null
    }

    private fun logout() {
        Log.d(TAG, "Logout called")
        // Jika ada logout logic tambahan
        pendingResult = null
    }
}
