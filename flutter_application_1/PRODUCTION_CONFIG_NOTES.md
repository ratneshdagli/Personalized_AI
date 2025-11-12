// Production-ready OkHttp client configuration
// Replace the existing okHttpClient in NotificationCaptureService.kt with this for production:

private val okHttpClient: OkHttpClient by lazy {
    OkHttpClient.Builder()
        .connectionSpecs(listOf(
            ConnectionSpec.MODERN_TLS,  // HTTPS only for production
            ConnectionSpec.COMPATIBLE_TLS
        ))
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()
}

// Production backend URL should be HTTPS:
// http://192.168.29.143:8000 -> https://your-production-domain.com
