package com.friendorfoe.data

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

data class BackendHealthCheck(
    val url: String,
    val ok: Boolean,
    val version: String? = null,
    val database: String? = null,
    val error: String? = null,
)

object BackendEndpoints {
    const val PRIMARY_WIFI_BACKEND = "http://192.168.1.208:8000/"
    const val SECONDARY_WIFI_BACKEND = "http://192.168.1.218:8000/"

    fun normalize(url: String): String {
        return url.trim().trimEnd('/').let { if (it.isBlank()) it else "$it/" }
    }

    fun label(url: String): String {
        return when (normalize(url)) {
            normalize(PRIMARY_WIFI_BACKEND) -> "208"
            normalize(SECONDARY_WIFI_BACKEND) -> "218"
            else -> normalize(url)
        }
    }

    fun candidates(preferred: String? = null): List<String> {
        val ordered = mutableListOf<String>()

        fun add(value: String?) {
            val normalized = value?.let(::normalize).orEmpty()
            if (normalized.isNotBlank() && normalized !in ordered) {
                ordered += normalized
            }
        }

        add(preferred)
        add(PRIMARY_WIFI_BACKEND)
        add(SECONDARY_WIFI_BACKEND)
        return ordered
    }

    suspend fun probeHealth(url: String): BackendHealthCheck = withContext(Dispatchers.IO) {
        val healthUrl = normalize(url) + "health"
        try {
            val connection = (URL(healthUrl).openConnection() as HttpURLConnection).apply {
                connectTimeout = 1500
                readTimeout = 1500
                requestMethod = "GET"
            }
            connection.inputStream.use { inputStream ->
                val body = inputStream.bufferedReader().readText()
                val json = JsonParser.parseString(body).asJsonObject
                BackendHealthCheck(
                    url = normalize(url),
                    ok = true,
                    version = json.stringOrNull("version"),
                    database = json.stringOrNull("database"),
                )
            }
        } catch (e: Exception) {
            BackendHealthCheck(
                url = normalize(url),
                ok = false,
                error = e.message?.take(120) ?: e::class.java.simpleName,
            )
        }
    }
}

private fun JsonObject.stringOrNull(name: String): String? {
    val element = get(name)
    return if (element != null && !element.isJsonNull) element.asString else null
}