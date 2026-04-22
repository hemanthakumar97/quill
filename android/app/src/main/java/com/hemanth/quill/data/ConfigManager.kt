package com.hemanth.quill.data

import android.content.Context
import androidx.core.content.edit

class ConfigManager(context: Context) {
    private val prefs = context.getSharedPreferences("quill_config", Context.MODE_PRIVATE)

    var provider: AIProvider
        get() = AIProvider.fromString(prefs.getString("provider", "claude") ?: "claude")
        set(v) = prefs.edit { putString("provider", v.name.lowercase()) }

    var polishMode: PolishMode
        get() = PolishMode.fromString(prefs.getString("mode", "light") ?: "light")
        set(v) = prefs.edit { putString("mode", v.name.lowercase()) }

    var aiEnabled: Boolean
        get() = prefs.getBoolean("ai_enabled", false)
        set(v) = prefs.edit { putBoolean("ai_enabled", v) }

    var ollamaHost: String
        get() = prefs.getString("ollama_host", "http://localhost:11434") ?: "http://localhost:11434"
        set(v) = prefs.edit { putString("ollama_host", v) }

    fun getApiKey(p: AIProvider): String =
        prefs.getString("api_key_${p.name.lowercase()}", "") ?: ""

    fun setApiKey(p: AIProvider, key: String) =
        prefs.edit { putString("api_key_${p.name.lowercase()}", key) }

    fun getSelectedModel(p: AIProvider): String =
        prefs.getString("model_${p.name.lowercase()}", "") ?: ""

    fun setSelectedModel(p: AIProvider, model: String) =
        prefs.edit { putString("model_${p.name.lowercase()}", model) }

    fun effectiveModel(p: AIProvider): String {
        val saved = getSelectedModel(p)
        return if (saved.isNotEmpty()) saved else p.defaultModelId
    }
}
