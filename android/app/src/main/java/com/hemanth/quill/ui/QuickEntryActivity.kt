package com.hemanth.quill.ui

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.hemanth.quill.ui.theme.QuillTheme
import kotlinx.coroutines.delay
import java.time.LocalDate
import java.time.format.DateTimeFormatter

class QuickEntryActivity : ComponentActivity() {

    private val viewModel: QuickEntryViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.setLayout(
            (resources.displayMetrics.widthPixels * 0.92).toInt(),
            WindowManager.LayoutParams.WRAP_CONTENT
        )

        setContent {
            QuillTheme {
                QuickEntryScreen(
                    viewModel = viewModel,
                    onDismiss = { finish() },
                    onOpenSettings = {
                        startActivity(Intent(this, MainActivity::class.java))
                    }
                )
            }
        }

    }

    override fun finish() {
        when (val state = viewModel.state.value) {
            is EntryState.Polishing -> return
            is EntryState.Writing -> {
                val text = viewModel.entryText.value.trim()
                if (text.isNotEmpty()) {
                    viewModel.commitOriginal()
                    return
                }
                super.finish()
            }
            is EntryState.Preview -> {
                viewModel.commitOriginal()
                return
            }
            else -> super.finish()
        }
    }
}

@Composable
fun QuickEntryScreen(
    viewModel: QuickEntryViewModel,
    onDismiss: () -> Unit,
    onOpenSettings: () -> Unit
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val entryText by viewModel.entryText.collectAsStateWithLifecycle()

    Surface(
        shape = MaterialTheme.shapes.large,
        tonalElevation = 6.dp
    ) {
        AnimatedContent(targetState = state, label = "entry_state") { s ->
            when (s) {
                is EntryState.Writing -> WritingScreen(
                    entryText = entryText,
                    onTextChange = { viewModel.entryText.value = it },
                    aiEnabled = viewModel.config.aiEnabled,
                    providerName = viewModel.config.provider.displayName,
                    onSave = { viewModel.save() },
                    onOpenSettings = onOpenSettings
                )
                is EntryState.Polishing -> PolishingScreen(
                    providerName = viewModel.config.provider.displayName
                )
                is EntryState.Preview -> PreviewScreen(
                    polished = s.polished,
                    modeName = viewModel.config.polishMode.displayName,
                    onSavePolished = { viewModel.commitPolished(s.polished) },
                    onSaveOriginal = { viewModel.commitOriginal() }
                )
                is EntryState.Saved -> {
                    SavedScreen(path = s.path)
                    LaunchedEffect(Unit) {
                        delay(1500)
                        onDismiss()
                    }
                }
                is EntryState.Error -> ErrorScreen(
                    message = s.message,
                    onSaveOriginal = { viewModel.commitOriginal() },
                    onRetry = { viewModel.retry() }
                )
            }
        }
    }
}

@Composable
private fun WritingScreen(
    entryText: String,
    onTextChange: (String) -> Unit,
    aiEnabled: Boolean,
    providerName: String,
    onSave: () -> Unit,
    onOpenSettings: () -> Unit
) {
    val focusRequester = remember { FocusRequester() }
    val today = LocalDate.now().format(DateTimeFormatter.ofPattern("MMMM d, yyyy"))

    Column(modifier = Modifier.padding(16.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = today,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(1f)
            )
            if (aiEnabled) {
                Surface(
                    color = MaterialTheme.colorScheme.primaryContainer,
                    shape = MaterialTheme.shapes.small
                ) {
                    Text(
                        text = providerName,
                        style = MaterialTheme.typography.labelSmall,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                        color = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                }
                Spacer(Modifier.width(8.dp))
            }
            IconButton(onClick = onOpenSettings, modifier = Modifier.size(32.dp)) {
                Icon(
                    Icons.Default.Settings,
                    contentDescription = "Settings",
                    modifier = Modifier.size(18.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

        OutlinedTextField(
            value = entryText,
            onValueChange = onTextChange,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 140.dp)
                .focusRequester(focusRequester),
            placeholder = {
                Text(
                    "What's on your mind today?",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        )

        Spacer(Modifier.height(12.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = if (aiEnabled) "tap to polish & save" else "tap to save",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f)
            )
            Button(
                onClick = onSave,
                enabled = entryText.isNotBlank()
            ) {
                Text(if (aiEnabled) "Polish & Save" else "Save")
            }
        }
    }

    LaunchedEffect(Unit) { focusRequester.requestFocus() }
}

@Composable
private fun PolishingScreen(providerName: String) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        CircularProgressIndicator()
        Text("Polishing your entry…", style = MaterialTheme.typography.bodyMedium)
        Text(
            "via $providerName",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun PreviewScreen(
    polished: String,
    modeName: String,
    onSavePolished: () -> Unit,
    onSaveOriginal: () -> Unit
) {
    Column(modifier = Modifier.padding(16.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "✨ AI Preview",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(1f)
            )
            Surface(
                color = MaterialTheme.colorScheme.primaryContainer,
                shape = MaterialTheme.shapes.small
            ) {
                Text(
                    text = modeName,
                    style = MaterialTheme.typography.labelSmall,
                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
            }
        }

        HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = 240.dp)
                .verticalScroll(rememberScrollState())
        ) {
            Text(polished, style = MaterialTheme.typography.bodyMedium, lineHeight = 22.sp)
        }

        Spacer(Modifier.height(12.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            OutlinedButton(onClick = onSaveOriginal) { Text("Save Original") }
            Button(onClick = onSavePolished) { Text("Save Polished") }
        }
    }
}

@Composable
private fun SavedScreen(path: String) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("✓", style = MaterialTheme.typography.displayMedium, color = MaterialTheme.colorScheme.primary)
        Text("Saved", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
        Text(path, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun ErrorScreen(
    message: String,
    onSaveOriginal: () -> Unit,
    onRetry: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text("⚠", style = MaterialTheme.typography.displaySmall, color = MaterialTheme.colorScheme.error)
        Text(message, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.fillMaxWidth())
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedButton(onClick = onSaveOriginal) { Text("Save Original") }
            Button(onClick = onRetry) { Text("Retry") }
        }
    }
}
