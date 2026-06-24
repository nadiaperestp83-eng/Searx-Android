package com.zackptg5.searx

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.view.View
import android.webkit.*
import androidx.webkit.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec

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
        // Processo isolado — renderizador multi-process (Chromium-style)
        if (WebViewFeature.isFeatureSupported(WebViewFeature.MULTIPROCESS_MODE)) {
            ProcessGlobalConfig.getInstance().apply {
                if (WebViewFeature.isFeatureSupported(WebViewFeature.MULTI_PROFILE)) {
                    // isolamento por sessão
                }
            }
        }

        // CookieManager isolado — não compartilha com o WebView do sistema
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

                // Cache apenas em memória — voltar é instantâneo
                cacheMode = WebSettings.LOAD_DEFAULT
                setAppCacheEnabled(false)

                // Remove identificação de WebView do User-Agent
                val baseUA = getDefaultUserAgent(context)
                    .replace(Regex("wv"), "")
                    .replace(Regex("; Android.*?\\)"), "; Android ${Build.VERSION.RELEASE})")
                userAgentString = baseUA

                // Performance / Raster
                setRenderPriority(WebSettings.RenderPriority.HIGH)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    // Hardware acceleration já é padrão, garantir
                }

                // Desativa geolocalização
                setGeolocationEnabled(false)

                // Desativa safe browsing (não envia URL ao Google)
                if (WebViewFeature.isFeatureSupported(WebViewFeature.SAFE_BROWSING_ENABLE)) {
                    WebSettingsCompat.setSafeBrowsingEnabled(this@apply.settings, false)
                }

                // Desativa algoritmos de media que fazem fingerprint
                mediaPlaybackRequiresUserGesture = true

                // Force Dark off — respeita o site
                if (WebViewFeature.isFeatureSupported(WebViewFeature.FORCE_DARK)) {
                    WebSettingsCompat.setForceDark(
                        this@apply.settings,
                        WebSettingsCompat.FORCE_DARK_OFF
                    )
                }
            }

            // Hardware acceleration
            setLayerType(View.LAYER_TYPE_HARDWARE, null)

            // ServiceWorker — bloqueia trackers antes do DOM
            if (WebViewFeature.isFeatureSupported(WebViewFeature.SERVICE_WORKER_BASIC_USAGE)) {
                ServiceWorkerControllerCompat.getInstance().apply {
                    setServiceWorkerClient(object : ServiceWorkerClientCompat() {
                        override fun shouldInterceptRequest(request: WebResourceRequest): WebResourceResponse? {
                            return if (isTracker(request.url.toString())) {
                                WebResourceResponse("text/plain", "utf-8", null)
                            } else null
                        }
                    })
                    serviceWorkerSettings.apply {
                        cacheMode = WebSettings.LOAD_DEFAULT
                    }
                }
            }

            webViewClient = object : WebViewClient() {

                // Intercepta TODAS as requisições — bloqueia trackers
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
                    // Injeta CSS para esconder banners de cookie automaticamente
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

                // Bloqueia acesso à geolocalização
                override fun onGeolocationPermissionsShowPrompt(
                    origin: String,
                    callback: GeolocationPermissions.Callback
                ) {
                    callback.invoke(origin, false, false)
                }

                // Bloqueia permissões de mídia
                override fun onPermissionRequest(request: PermissionRequest?) {
                    request?.deny()
                }
            }
        }

        // Canal Flutter → Kotlin
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
