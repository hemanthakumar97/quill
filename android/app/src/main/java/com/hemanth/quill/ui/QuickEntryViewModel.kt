package com.hemanth.quill.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.hemanth.quill.data.AIManager
import com.hemanth.quill.data.ConfigManager
import com.hemanth.quill.data.JournalManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed interface EntryState {
    data object Writing : EntryState
    data object Polishing : EntryState
    data class Preview(val polished: String) : EntryState
    data class Saved(val path: String) : EntryState
    data class Error(val message: String) : EntryState
}

class QuickEntryViewModel(application: Application) : AndroidViewModel(application) {

    val config = ConfigManager(application)
    private val journal = JournalManager(application)
    private val ai = AIManager()

    val entryText = MutableStateFlow("")
    private val _state = MutableStateFlow<EntryState>(EntryState.Writing)
    val state: StateFlow<EntryState> = _state

    fun save() {
        val text = entryText.value.trim()
        if (text.isEmpty()) return
        if (config.aiEnabled) polish() else commit(text)
    }

    fun polish() {
        val text = entryText.value.trim()
        if (text.isEmpty()) return
        _state.value = EntryState.Polishing
        viewModelScope.launch {
            try {
                val polished = ai.polish(text, config)
                _state.value = EntryState.Preview(polished)
            } catch (e: Exception) {
                _state.value = EntryState.Error(e.message ?: "Unknown error")
            }
        }
    }

    fun commitPolished(polished: String) = commit(polished)

    fun commitOriginal() = commit(entryText.value.trim())

    fun retry() = polish()

    fun reset() {
        entryText.value = ""
        _state.value = EntryState.Writing
    }

    private fun commit(text: String) {
        try {
            journal.appendEntry(text)
            _state.value = EntryState.Saved(journal.savedToPath())
        } catch (e: Exception) {
            _state.value = EntryState.Error(e.message ?: "Failed to save entry")
        }
    }
}
