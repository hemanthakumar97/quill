package com.hemanth.quill.data

import android.content.Context
import java.io.File
import java.time.LocalDate
import java.time.LocalTime
import java.time.format.DateTimeFormatter

class JournalManager(private val context: Context) {

    private val baseDir: File
        get() = File(context.getExternalFilesDir(null), "Journal")

    fun journalFile(date: LocalDate = LocalDate.now()): File {
        val yearDir = File(baseDir, date.year.toString())
        val month = date.format(DateTimeFormatter.ofPattern("MMM-yyyy"))
        return File(yearDir, "$month.md")
    }

    fun savedToPath(date: LocalDate = LocalDate.now()): String {
        val month = date.format(DateTimeFormatter.ofPattern("MMM-yyyy"))
        return "Quill/Journal/${date.year}/$month.md"
    }

    fun appendEntry(text: String, date: LocalDate = LocalDate.now()) {
        val file = journalFile(date)
        file.parentFile?.mkdirs()

        val dayHeader = "## ${date.format(DateTimeFormatter.ofPattern("MMMM d, yyyy"))}"
        val timeHeader = "### ${LocalTime.now().format(DateTimeFormatter.ofPattern("HH:mm"))}"
        val trimmed = text.trim()

        val existing = if (file.exists()) file.readText(Charsets.UTF_8) else ""

        val block = if (existing.contains(dayHeader)) {
            "\n$timeHeader\n$trimmed\n"
        } else {
            val sep = if (existing.isEmpty()) "" else "\n"
            "$sep$dayHeader\n\n$timeHeader\n$trimmed\n"
        }

        file.appendText(block, Charsets.UTF_8)
    }

    fun isStorageAvailable(): Boolean = context.getExternalFilesDir(null) != null
}
