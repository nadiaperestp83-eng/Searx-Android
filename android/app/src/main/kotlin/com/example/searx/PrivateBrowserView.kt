package com.zackptg5.searx

import android.content.Context
import android.graphics.Bitmap
import android.os.Build
import android.view.View
import android.webkit.*
import androidx.webkit.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

// ─── Factory ────────────────────────────────────────────────────────────────

class PrivateBrowserFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val url = params?.get("url") as? String ?: "about:blank"
        return PrivateBrowserView(context, viewId, messenger, url)
    }
}

// ─── Bloklist de trackers ────────────────────────────────────────────────────

private val TRACKER_PATTERNS = listOf(
    "google-analytics.com",
    "googletagmanager.com",
    "doubleclick.net",
    "googlesyndication.com",
    "facebook.net",
    "facebook.com/tr",
    "connect.facebook.net",
    "analytics.twitter.com",
    "ads.twitter.com",
    "scorecardresearch.com",
    "quantserve.com",
    "outbrain.com",
    "taboola.com",
    "hotjar.com",
    "mouseflow.com",
    "clarity.ms",
    "amazon-adsystem.com",
    "adnxs.com",
    "rubiconproject.com",
    "pubmatic.com",
    "criteo.com",
    "moatads.com",
    "chartbeat.com",
    "newrelic.com",
    "segment.com",
    "mixpanel.com",
    "amplitude.com",
    "branch.io",
    "appsflyer.com",
    "adjust.com",
    "kochava.com",
)

private fun isTracker(url: String): Boolean {
    val lower = url.lowercase()
    return TRACKER_PATTERNS.any { lower.contains(it) }
}

// ─── PlatformView ────────────────────────────────────────────────────────────

class PrivateBrowserView(
    private val context: Context,
    private val viewId: Int,
    messenger: BinaryMessenger,
    private val initialUrl: String,
) : PlatformView {

    private val channel = MethodChannel(messenger, "searxgo/browser_$viewId")
    private val webView: WebView

    init {
        // Isolamento de perfil de dados (cookies, cache, etc.) – suportado a partir do Android 10 (API 29)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            WebView.setDataDirectorySuffix("searx_private_$viewId")
        }

        val cookieManager = CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)
        cookieManager.removeAllCookies(null)

        webView = WebView(context).apply {
            settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                databaseEnabled = false
                allowFileAccess = false
                allowContentAccess = false
                allowFileAccessFromFileURLs = false
                allowUniversalAccessFromFileURLs = false

                cacheMode = WebSettings.LOAD_DEFAULT

                val baseUA = WebSettings.getDefaultUserAgent(context)
                    .replace(Regex(" wv"), "")
                    .replace(Regex("; Android .*?\\)"), "; Android ${Build.VERSION.RELEASE})")
                userAgentString = baseUA

                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                    setRenderPriority(WebSettings.RenderPriority.HIGH)
                }

                setGeolocationEnabled(false)

                // Safe Browsing – desativado para não enviar URLs ao Google
                if (WebViewFeature.isFeatureSupported(WebViewFeature.SAFE_BROWSING_ENABLE)) {
                    WebSettingsCompat.setSafeBrowsingEnabled(this, false)   // <-- CORRIGIDO
                }

                mediaPlaybackRequiresUserGesture = true

                // Modo escuro forçado – desativado para respeitar o site
                if (WebViewFeature.isFeatureSupported(WebViewFeature.FORCE_DARK)) {
                    WebSettingsCompat.setForceDark(this, WebSettingsCompat.FORCE_DARK_OFF) // <-- CORRIGIDO
                }
            }

            setLayerType(View.LAYER_TYPE_HARDWARE, null)

            // ServiceWorker – bloqueio de trackers antes do carregamento
            if (WebViewFeature.isFeatureSupported(WebViewFeature.SERVICE_WORKER_BASIC_USAGE)) {
                ServiceWorkerControllerCompat.getInstance().apply {
                    setServiceWorkerClient(object : ServiceWorkerClientCompat() {
                        override fun shouldInterceptRequest(request: WebResourceRequest): WebResourceResponse? {
                            return if (isTracker(request.url.toString())) {
                                WebResourceResponse("text/plain", "utf-8", null)
                            } else null
                        }
                    })
                    // Nota: ServiceWorkerWebSettingsCompat não expõe cacheMode, portanto mantemos o padrão
                }
            }

            webViewClient = object : WebViewClient() {

                override fun shouldInterceptRequest(
                    view: WebView,
                    request: WebResourceRequest
                ): WebResourceResponse? {
                    val url = request.url.toString()
                    if (isTracker(url)) {
                        return WebResourceResponse("text/plain", "utf-8", null)
                    }
                    return null
                }

                override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
                    channel.invokeMethod("onPageStarted", url)
                }

                override fun onPageFinished(view: WebView, url: String) {
                    // Injeta CSS para ocultar banners de cookies
                    val bannerHider = """
                        (function() {
                            var style = document.createElement('style');
                            style.textContent = `
                                [class*='cookie'], [id*='cookie'],
                                [class*='consent'], [id*='consent'],
                                [class*='gdpr'], [id*='gdpr'],
                                [class*='banner'], [class*='popup'],
                                [class*='overlay'][class*='privacy'],
                                #onetrust-banner-sdk,
                                .cc-window, .cc-banner,
                                #cookiebanner, .cookie-notice,
                                .cookie-law-info-bar {
                                    display: none !important;
                                    visibility: hidden !important;
                                }
                                body { overflow: auto !important; }
                            `;
                            document.head.appendChild(style);
                        })();
                    """.trimIndent()
                    view.evaluateJavascript(bannerHider, null)
                    channel.invokeMethod("onPageFinished", url)
                }

                override fun onReceivedError(
                    view: WebView,
                    request: WebResourceRequest,
                    error: WebResourceError
                ) {
                    if (request.isForMainFrame) {
                        channel.invokeMethod("onError", error.description.toString())
                    }
                }
            }

            webChromeClient = object : WebChromeClient() {
                override fun onProgressChanged(view: WebView, newProgress: Int) {
                    channel.invokeMethod("onProgress", newProgress)
                }

                override fun onGeolocationPermissionsShowPrompt(
                    origin: String,
                    callback: GeolocationPermissions.Callback
                ) {
                    callback.invoke(origin, false, false)
                }

                override fun onPermissionRequest(request: PermissionRequest?) {
                    request?.deny()
                }
            }
        }

        // Métodos expostos ao Flutter
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "loadUrl" -> {
                    val url = call.argument<String>("url") ?: return@setMethodCallHandler
                    webView.loadUrl(url)
                    result.success(null)
                }
                "goBack" -> {
                    if (webView.canGoBack()) webView.goBack()
                    result.success(webView.canGoBack())
                }
                "goForward" -> {
                    if (webView.canGoForward()) webView.goForward()
                    result.success(webView.canGoForward())
                }
                "reload" -> {
                    webView.reload()
                    result.success(null)
                }
                "clearData" -> {
                    webView.clearCache(true)
                    webView.clearHistory()
                    CookieManager.getInstance().removeAllCookies(null)
                    result.success(null)
                }
                "getUrl" -> result.success(webView.url)
                else -> result.notImplemented()
            }
        }

        webView.loadUrl(initialUrl)
    }

    override fun getView(): View = webView

    override fun dispose() {
        webView.stopLoading()
        webView.clearCache(true)
        webView.clearHistory()
        CookieManager.getInstance().removeAllCookies(null)
        channel.setMethodCallHandler(null)
        webView.destroy()
    }
}
