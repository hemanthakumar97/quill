package com.hemanth.quill.data

data class ModelOption(val id: String, val label: String, val tier: String)

enum class AIProvider(val displayName: String, val requiresApiKey: Boolean) {
    CLAUDE("Claude", true),
    OPENAI("ChatGPT", true),
    GEMINI("Gemini", true),
    OLLAMA("Local (Ollama)", false);

    val curatedModels: List<ModelOption>
        get() = when (this) {
            CLAUDE -> listOf(
                ModelOption("claude-opus-4-7", "Opus 4.7", "Flagship"),
                ModelOption("claude-sonnet-4-6", "Sonnet 4.6", "Balanced"),
                ModelOption("claude-haiku-4-5-20251001", "Haiku 4.5", "Fast"),
            )
            OPENAI -> listOf(
                ModelOption("gpt-4o", "GPT-4o", "Flagship"),
                ModelOption("gpt-4o-mini", "GPT-4o mini", "Balanced"),
            )
            GEMINI -> listOf(
                ModelOption("gemini-1.5-pro", "Gemini 1.5 Pro", "Flagship"),
                ModelOption("gemini-1.5-flash", "Gemini 1.5 Flash", "Balanced"),
                ModelOption("gemini-2.0-flash", "Gemini 2.0 Flash", "Fast"),
            )
            OLLAMA -> emptyList()
        }

    val defaultModelId: String
        get() = curatedModels.firstOrNull { it.tier == "Balanced" }?.id
            ?: curatedModels.firstOrNull()?.id ?: ""

    companion object {
        fun fromString(value: String): AIProvider =
            entries.firstOrNull { it.name.equals(value, ignoreCase = true) } ?: CLAUDE
    }
}

enum class PolishMode(val displayName: String, val detail: String, val systemPrompt: String) {
    LIGHT(
        "Light Polish",
        "Fix grammar, keep your voice",
        "You are a light copy-editor for a personal journal. " +
            "Fix grammar and spelling, improve readability, but preserve the author's exact voice, " +
            "tone, and meaning. Make minimal changes — do not add new ideas or expand the text. " +
            "Return only the polished journal text with no commentary or explanation."
    ),
    FULL(
        "Full Rewrite",
        "Expand into flowing prose",
        "You are a journaling assistant. Rewrite the following raw journal notes into " +
            "rich, flowing, reflective prose. Keep the meaning and emotions intact but make " +
            "it read like a thoughtful personal diary entry. " +
            "Return only the rewritten text with no commentary or explanation."
    ),
    STRUCTURED(
        "Structured",
        "Organize into sections",
        "You are a journaling assistant. Reorganize the following raw journal notes into " +
            "three clearly labeled sections using markdown bold: " +
            "**What happened**, **How I felt**, **Key takeaway**. " +
            "Be concise and faithful to the original content. " +
            "Return only the formatted text with no commentary or explanation."
    );

    companion object {
        fun fromString(value: String): PolishMode =
            entries.firstOrNull { it.name.equals(value, ignoreCase = true) } ?: LIGHT
    }
}
