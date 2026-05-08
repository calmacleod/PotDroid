package com.potdroid.android.network

import org.junit.Assert.assertEquals
import org.junit.Test

class PairingParserTest {
    @Test
    fun parsesQrPayload() {
        val parsed = PairingParser.parse(
            input = """{"type":"potdroid_pairing","version":1,"api_base_url":"https://pair.example","code":"ABCD-EFGH-JK23"}""",
            fallbackApiBaseUrl = "https://fallback.example",
        )

        assertEquals("https://pair.example", parsed.apiBaseUrl)
        assertEquals("ABCD-EFGH-JK23", parsed.code)
    }

    @Test
    fun parsesDeepLinkPayload() {
        val parsed = PairingParser.parse(
            input = "potdroid://pair?api_base_url=https%3A%2F%2Fpair.example&code=ABCD-EFGH-JK23",
            fallbackApiBaseUrl = "https://fallback.example",
        )

        assertEquals("https://pair.example", parsed.apiBaseUrl)
        assertEquals("ABCD-EFGH-JK23", parsed.code)
    }

    @Test
    fun parsesCompactDeepLinkPayload() {
        val parsed = PairingParser.parse(
            input = "potdroid://pair?u=https%3A%2F%2Fpair.example&c=ABCD-EFGH-JK23",
            fallbackApiBaseUrl = "https://fallback.example",
        )

        assertEquals("https://pair.example", parsed.apiBaseUrl)
        assertEquals("ABCD-EFGH-JK23", parsed.code)
    }

    @Test
    fun treatsPlainTextAsPairingCode() {
        val parsed = PairingParser.parse(
            input = "ABCD-EFGH-JK23",
            fallbackApiBaseUrl = "https://fallback.example",
        )

        assertEquals("https://fallback.example", parsed.apiBaseUrl)
        assertEquals("ABCD-EFGH-JK23", parsed.code)
    }
}
