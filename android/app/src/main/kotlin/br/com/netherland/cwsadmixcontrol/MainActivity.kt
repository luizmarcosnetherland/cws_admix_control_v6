package br.com.netherland.cwsadmixcontrol

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val calendarChannelName = "br.com.netherland.cwsadmixcontrol/calendar"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            calendarChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openEventEditor" -> openEventEditor(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun openEventEditor(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val title = args?.get("title") as? String
        val notes = args?.get("notes") as? String
        val startMillis = (args?.get("startMillis") as? Number)?.toLong()
        val endMillis = (args?.get("endMillis") as? Number)?.toLong()
        val alarmOffsetSeconds = (args?.get("alarmOffsetSeconds") as? Number)?.toLong()

        if (title == null || notes == null || startMillis == null || endMillis == null) {
            result.error(
                "invalid_calendar_event",
                "Não conseguimos preparar os dados do evento.",
                null,
            )
            return
        }

        val intent = Intent(Intent.ACTION_INSERT).apply {
            data = CalendarContract.Events.CONTENT_URI
            putExtra(CalendarContract.Events.TITLE, title)
            putExtra(CalendarContract.Events.DESCRIPTION, notes)
            putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, startMillis)
            putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endMillis)
            putExtra(CalendarContract.Events.HAS_ALARM, true)
            alarmOffsetSeconds?.let {
                putExtra(CalendarContract.Reminders.MINUTES, kotlin.math.abs(it / 60).toInt())
            }
        }

        try {
            startActivity(intent)
            result.success(null)
        } catch (error: ActivityNotFoundException) {
            result.error(
                "calendar_unavailable",
                "Não encontramos um aplicativo de calendário para criar o evento.",
                null,
            )
        }
    }
}
