package com.potdroid.android.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets

@Serializable
data class PairingQrPayload(
    val type: String,
    val version: Int,
    @SerialName("api_base_url") val apiBaseUrl: String,
    val code: String,
)

object PairingParser {
    private val json = Json { ignoreUnknownKeys = true }

    fun parse(input: String, fallbackApiBaseUrl: String): ParsedPairing {
        val trimmed = input.trim()
        val payload = runCatching { json.decodeFromString<PairingQrPayload>(trimmed) }.getOrNull()
        val deepLinkPayload = parseDeepLink(trimmed)

        return when {
            payload?.type == "potdroid_pairing" -> ParsedPairing(apiBaseUrl = payload.apiBaseUrl, code = payload.code)
            deepLinkPayload != null -> deepLinkPayload
            else -> ParsedPairing(apiBaseUrl = fallbackApiBaseUrl, code = trimmed)
        }
    }

    private fun parseDeepLink(input: String): ParsedPairing? {
        val uri = runCatching { URI(input) }.getOrNull() ?: return null
        if (uri.scheme != "potdroid" || uri.host != "pair") return null

        val params = uri.rawQuery.orEmpty()
            .split("&")
            .filter { it.contains("=") }
            .associate {
                val (key, value) = it.split("=", limit = 2)
                decode(key) to decode(value)
            }

        val apiBaseUrl = params["u"].orEmpty().ifBlank { params["api_base_url"].orEmpty() }
        val code = params["c"].orEmpty().ifBlank { params["code"].orEmpty() }
        if (apiBaseUrl.isBlank() || code.isBlank()) return null

        return ParsedPairing(apiBaseUrl = apiBaseUrl, code = code)
    }

    private fun decode(value: String): String =
        URLDecoder.decode(value, StandardCharsets.UTF_8.name())
}

data class ParsedPairing(
    val apiBaseUrl: String,
    val code: String,
)
