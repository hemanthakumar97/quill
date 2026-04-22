package com.hemanth.quill.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import com.hemanth.quill.data.AIProvider
import com.hemanth.quill.data.ConfigManager
import com.hemanth.quill.data.PolishMode

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(onClose: () -> Unit) {
    val context = LocalContext.current
    val config = remember { ConfigManager(context) }

    var aiEnabled by remember { mutableStateOf(config.aiEnabled) }
    var provider by remember { mutableStateOf(config.provider) }
    var polishMode by remember { mutableStateOf(config.polishMode) }
    var ollamaHost by remember { mutableStateOf(config.ollamaHost) }
    var showKey by remember { mutableStateOf(false) }
    var draftKeys by remember {
        mutableStateOf(AIProvider.entries.associateWith { config.getApiKey(it) })
    }
    var selectedModels by remember {
        mutableStateOf(AIProvider.entries.associateWith { config.getSelectedModel(it) })
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings", fontWeight = FontWeight.SemiBold) },
                actions = {
                    TextButton(onClick = {
                        config.aiEnabled = aiEnabled
                        config.provider = provider
                        config.polishMode = polishMode
                        config.ollamaHost = ollamaHost
                        AIProvider.entries.forEach { p ->
                            draftKeys[p]?.let { config.setApiKey(p, it) }
                            selectedModels[p]?.let { config.setSelectedModel(p, it) }
                        }
                        onClose()
                    }) { Text("Done") }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // AI toggle
            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text("Enable AI polishing", style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                Switch(checked = aiEnabled, onCheckedChange = { aiEnabled = it })
            }

            if (aiEnabled) {
                HorizontalDivider()

                // Provider
                SettingsSection("Provider") {
                    SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                        AIProvider.entries.forEachIndexed { idx, p ->
                            SegmentedButton(
                                selected = provider == p,
                                onClick = { provider = p },
                                shape = SegmentedButtonDefaults.itemShape(idx, AIProvider.entries.size),
                                label = { Text(p.displayName, maxLines = 1, style = MaterialTheme.typography.labelSmall) }
                            )
                        }
                    }
                }

                // API Key / Ollama host
                if (provider.requiresApiKey) {
                    SettingsSection("API Key") {
                        OutlinedTextField(
                            value = draftKeys[provider] ?: "",
                            onValueChange = { draftKeys = draftKeys + (provider to it) },
                            modifier = Modifier.fillMaxWidth(),
                            placeholder = { Text("Paste key here…") },
                            visualTransformation = if (showKey) VisualTransformation.None else PasswordVisualTransformation(),
                            trailingIcon = {
                                IconButton(onClick = { showKey = !showKey }) {
                                    Icon(
                                        if (showKey) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                        contentDescription = null
                                    )
                                }
                            },
                            singleLine = true
                        )
                        Text(
                            text = when (provider) {
                                AIProvider.CLAUDE -> "console.anthropic.com → API Keys"
                                AIProvider.OPENAI -> "platform.openai.com → API Keys"
                                AIProvider.GEMINI -> "aistudio.google.com → Get API Key"
                                AIProvider.OLLAMA -> ""
                            },
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                } else {
                    SettingsSection("Ollama Host") {
                        OutlinedTextField(
                            value = ollamaHost,
                            onValueChange = { ollamaHost = it },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true
                        )
                        Text(
                            "Run `ollama list` in Terminal to see installed models.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                // Model picker
                if (provider != AIProvider.OLLAMA) {
                    SettingsSection("Model") {
                        val models = provider.curatedModels
                        var expanded by remember(provider) { mutableStateOf(false) }
                        val currentId = (selectedModels[provider] ?: "").ifEmpty { provider.defaultModelId }
                        val currentLabel = models.firstOrNull { it.id == currentId }
                            ?.let { "${it.label} · ${it.tier}" } ?: currentId

                        ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
                            OutlinedTextField(
                                value = currentLabel,
                                onValueChange = {},
                                readOnly = true,
                                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .menuAnchor(MenuAnchorType.PrimaryNotEditable)
                            )
                            ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                                models.forEach { m ->
                                    DropdownMenuItem(
                                        text = { Text("${m.label} · ${m.tier}") },
                                        onClick = {
                                            selectedModels = selectedModels + (provider to m.id)
                                            expanded = false
                                        }
                                    )
                                }
                            }
                        }
                    }
                }

                // Polish mode
                SettingsSection("Polish Mode") {
                    PolishMode.entries.forEach { mode ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 2.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            RadioButton(selected = polishMode == mode, onClick = { polishMode = mode })
                            Spacer(Modifier.width(8.dp))
                            Column {
                                Text(mode.displayName, style = MaterialTheme.typography.bodyMedium)
                                Text(
                                    mode.detail,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SettingsSection(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Medium)
        content()
    }
}
