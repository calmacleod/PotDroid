package com.potdroid.android.network

import com.potdroid.android.data.DebugSettings
import kotlinx.serialization.json.Json
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory

class ApiClient(
    private val settings: DebugSettings,
) {
    fun candidatePotholeApi(): CandidatePotholeApi {
        val client = OkHttpClient.Builder()
            .addInterceptor(authInterceptor())
            .build()

        val json = Json { ignoreUnknownKeys = true }

        return Retrofit.Builder()
            .baseUrl(settings.apiBaseUrl)
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()
            .create(CandidatePotholeApi::class.java)
    }

    private fun authInterceptor() = Interceptor { chain ->
        val token = settings.apiToken
        val request = if (token.isBlank()) {
            chain.request()
        } else {
            chain.request().newBuilder()
                .header("Authorization", "Bearer $token")
                .build()
        }
        chain.proceed(request)
    }
}
