package com.example.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

// Home-screen SOS widget: a single always-on button that opens the app
// straight to the same hold-to-confirm SOS flow used everywhere else
// (see QuickSosScreen in Dart), instead of the app's normal Home tab.
// The widget itself carries no dynamic state — it just needs a
// PendingIntent wired up whenever the system (re)draws it.
class SosWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.sos_widget)
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("safestep://sos"),
            )
            views.setOnClickPendingIntent(R.id.sos_widget_root, pendingIntent)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
