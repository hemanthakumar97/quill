package com.hemanth.quill.ui

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.hemanth.quill.ui.theme.QuillTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            QuillTheme {
                SettingsScreen(onClose = { finish() })
            }
        }
    }
}
