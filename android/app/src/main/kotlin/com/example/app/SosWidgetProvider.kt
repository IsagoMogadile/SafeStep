package com.example.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

// Home-screen SOS widget: a single always-on button that opens the app
// straight to the same hold-to-confirm SOS flow used everywhere else
// (see QuickSosScreen in Dart), instead of the app's normal Home tab.
// The widget itself carries no dynamic state beyond its own size — it
// just needs a PendingIntent wired up whenever the system (re)draws it,
// and a layout picked to match however big the user has resized it to.
class SosWidgetProvider : HomeWidgetProvider() {
    // Below this width there's no room for "SOS" + a subtitle without
    // clipping — switch to an icon-only tile instead of shrinking text
    // to the point it's unreadable at a glance.
    private val compactWidthThresholdDp = 100

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    // Fires whenever the user drags-resizes the widget on their home
    // screen — this is what makes it genuinely size-adjustable rather
    // than just resizable-but-cramped: the layout itself swaps to match.
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
    ) {
        val options = appWidgetManager.getAppWidgetOptions(widgetId)
        val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110)
        val layoutRes = if (widthDp < compactWidthThresholdDp) {
            R.layout.sos_widget_compact
        } else {
            R.layout.sos_widget
        }

        val views = RemoteViews(context.packageName, layoutRes)
        val pendingIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("safestep://sos"),
        )
        // Both layouts share this id on their root view, so the entire
        // visible tile — at any size — is one single, generous tap
        // target rather than a small button inside it.
        views.setOnClickPendingIntent(R.id.sos_widget_root, pendingIntent)
        appWidgetManager.updateAppWidget(widgetId, views)
    }
}
