package com.hemanth.quill.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class AIManager {
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .build()

    private val jsonType = "application/json".toMediaType()

    suspend fun polish(text: String, config: ConfigManager): String = withContext(Dispatchers.IO) {
        val prompt = "${config.polishMode.systemPrompt}\n\n---\n$text"
        when (config.provider) {
            AIProvider.CLAUDE -> claude(prompt, config.getApiKey(AIProvider.CLAUDE), config.effectiveModel(AIProvider.CLAUDE))
            AIProvider.OPENAI -> openai(prompt, config.getApiKey(AIProvider.OPENAI), config.effectiveModel(AIProvider.OPENAI))
            AIProvider.GEMINI -> gemini(prompt, config.getApiKey(AIProvider.GEMINI), config.effectiveModel(AIProvider.GEMINI))
            AIProvider.OLLAMA -> ollama(prompt, config.ollamaHost, config.effectiveModel(AIProvider.OLLAMA))
        }
    }

    private fun claude(prompt: String, key: String, model: String): String {
        if (key.isEmpty()) throw AIException("No API key for Claude. Add one in Settings.")
        val body = JSONObject()
            .put("model", model)
            .put("max_tokens", 1024)
            .put("messages", JSONArray().put(JSONObject().put("role", "user").put("content", prompt)))
            .toString().toRequestBody(jsonType)

        val request = Request.Builder()
            .url("https://api.anthropic.com/v1/messages")
            .post(body)
            .addHeader("x-api-key", key)
            .addHeader("anthropic-version", "2023-06-01")
            .build()

        val json = executeAndParse(request)
        if (json.has("error")) throw AIException("Claude: ${json.getJSONObject("error").getString("message")}")
        return json.getJSONArray("content").getJSONObject(0).getString("text").trim()
    }

    private fun openai(prompt: String, key: String, model: String): String {
        if (key.isEmpty()) throw AIException("No API key for ChatGPT. Add one in Settings.")
        val body = JSONObject()
            .put("model", model)
            .put("messages", JSONArray().put(JSONObject().put("role", "user").put("content", prompt)))
            .toString().toRequestBody(jsonType)

        val request = Request.Builder()
            .url("https://api.openai.com/v1/chat/completions")
            .post(body)
            .addHeader("Authorization", "Bearer $key")
            .build()

        val json = executeAndParse(request)
        if (json.has("error")) throw AIException("OpenAI: ${json.getJSONObject("error").getString("message")}")
        return json.getJSONArray("choices").getJSONObject(0).getJSONObject("message").getString("content").trim()
    }

    private fun gemini(prompt: String, key: String, model: String): String {
        if (key.isEmpty()) throw AIException("No API key for Gemini. Add one in Settings.")
        val body = JSONObject()
            .put("contents", JSONArray().put(
                JSONObject().put("parts", JSONArray().put(JSONObject().put("text", prompt)))
            ))
            .toString().toRequestBody(jsonType)

        val request = Request.Builder()
            .url("https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key")
            .post(body)
            .build()

        val json = executeAndParse(request)
        if (json.has("error")) throw AIException("Gemini: ${json.getJSONObject("error").getString("message")}")
        return json.getJSONArray("candidates")
            .getJSONObject(0)
            .getJSONObject("content")
            .getJSONArray("parts")
            .getJSONObject(0)
            .getString("text").trim()
    }

    private fun ollama(prompt: String, host: String, model: String): String {
        val resolvedModel = model.ifEmpty { "llama3:latest" }
        val body = JSONObject()
            .put("model", resolvedModel)
            .put("stream", false)
            .put("messages", JSONArray().put(JSONObject().put("role", "user").put("content", prompt)))
            .toString().toRequestBody(jsonType)

        val request = Request.Builder()
            .url("$host/api/chat")
            .post(body)
            .build()

        val json = executeAndParse(request)
        if (json.has("error")) throw AIException("Ollama: ${json.getString("error")}")
        return json.getJSONObject("message").getString("content").trim()
    }

    private fun executeAndParse(request: Request): JSONObject {
        val response = client.newCall(request).execute()
        val body = response.body?.string() ?: throw AIException("Empty response from server")
        return JSONObject(body)
    }
}

class AIException(message: String) : Exception(message)
