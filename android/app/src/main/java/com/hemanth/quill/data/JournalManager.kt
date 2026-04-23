package com.hemanth.quill.data

import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import java.io.File
import java.io.IOException
import java.time.LocalDate
import java.time.LocalTime
import java.time.format.DateTimeFormatter

class JournalManager(private val context: Context, private val config: ConfigManager) {

    private val defaultBaseDir: File
        get() = File(context.getExternalFilesDir(null), "Journal")

    fun savedToPath(date: LocalDate = LocalDate.now()): String {
        val month = date.format(DateTimeFormatter.ofPattern("MMM-yyyy"))
        val uri = config.journalFolderUri
        return if (uri != null) {
            val name = DocumentFile.fromTreeUri(context, Uri.parse(uri))?.name ?: "Journal"
            "$name/${date.year}/$month.md"
        } else {
            "Journal/${date.year}/$month.md"
        }
    }

    fun appendEntry(text: String, date: LocalDate = LocalDate.now()) {
        val uri = config.journalFolderUri
        if (uri != null) {
            appendEntryToTree(text, Uri.parse(uri), date)
        } else {
            appendEntryToFile(text, date)
        }
    }

    private fun appendEntryToFile(text: String, date: LocalDate) {
        val file = File(File(defaultBaseDir, date.year.toString()),
            "${date.format(DateTimeFormatter.ofPattern("MMM-yyyy"))}.md")
        file.parentFile?.mkdirs()

        val existing = if (file.exists()) file.readText(Charsets.UTF_8) else ""
        file.appendText(buildBlock(existing, date, text), Charsets.UTF_8)
    }

    private fun appendEntryToTree(text: String, treeUri: Uri, date: LocalDate) {
        val root = DocumentFile.fromTreeUri(context, treeUri)
            ?: throw IOException("Cannot access selected folder")

        val yearDoc = root.findFile(date.year.toString())
            ?: root.createDirectory(date.year.toString())
            ?: throw IOException("Cannot create year directory")

        val monthName = "${date.format(DateTimeFormatter.ofPattern("MMM-yyyy"))}.md"
        val monthDoc = yearDoc.findFile(monthName)
            ?: yearDoc.createFile("application/octet-stream", monthName)
            ?: throw IOException("Cannot create journal file")

        val existing = context.contentResolver.openInputStream(monthDoc.uri)
            ?.use { it.bufferedReader(Charsets.UTF_8).readText() } ?: ""

        context.contentResolver.openOutputStream(monthDoc.uri, "wa")
            ?.use { it.write(buildBlock(existing, date, text).toByteArray(Charsets.UTF_8)) }
            ?: throw IOException("Cannot write to journal file")
    }

    private fun buildBlock(existing: String, date: LocalDate, text: String): String {
        val dayHeader = "## ${date.format(DateTimeFormatter.ofPattern("MMMM d, yyyy"))}"
        val timeHeader = "### ${LocalTime.now().format(DateTimeFormatter.ofPattern("h:mm a"))}"
        val trimmed = text.trim()
        return if (existing.contains(dayHeader)) {
            "\n$timeHeader\n$trimmed\n"
        } else {
            val sep = if (existing.isEmpty()) "" else "\n"
            "$sep$dayHeader\n\n$timeHeader\n$trimmed\n"
        }
    }

    fun isStorageAvailable(): Boolean = context.getExternalFilesDir(null) != null
}
