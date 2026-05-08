package com.potdroid.android.data

import android.content.Context
import androidx.core.content.edit
import com.potdroid.android.BuildConfig

class DebugSettings(context: Context) {
    private val preferences = context.getSharedPreferences("debug_settings", Context.MODE_PRIVATE)

    var apiBaseUrl: String
        get() = preferences.getString(KEY_API_BASE_URL, BuildConfig.DEFAULT_API_BASE_URL) ?: BuildConfig.DEFAULT_API_BASE_URL
        set(value) = preferences.edit { putString(KEY_API_BASE_URL, value.trimEnd('/') + "/") }

    var apiToken: String
        get() = preferences.getString(KEY_API_TOKEN, "") ?: ""
        set(value) = preferences.edit { putString(KEY_API_TOKEN, value.trim()) }

    companion object {
        private const val KEY_API_BASE_URL = "api_base_url"
        private const val KEY_API_TOKEN = "api_token"
    }
}
