package com.example.app

import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.quicksettings.TileService

// Quick Settings tile: reachable by swiping the notification shade down
// twice, with the phone still LOCKED — unlike the home-screen widget,
// which needs the phone unlocked first. That gap matters specifically
// for the "phone was just grabbed" scenario the widget redesign was
// built around, so this is a second, faster entry point to the exact
// same flow rather than a replacement for it.
//
// Deliberately not registered as its own launcher icon or given an
// alarming label — the app's own icon and name are enough, same
// discretion reasoning as SosWidgetProvider's navy background: a tile
// in the shade shouldn't read as an obvious panic button to anyone else
// who glances at it.
class SosQuickSettingsTileService : TileService() {
    override fun onClick() {
        super.onClick()

        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("safestep://sos")
            // TileService isn't an Activity context, so this is required
            // to start one from here.
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // startActivityAndCollapse(Intent) is removed on API 34+ in
            // favor of the PendingIntent overload.
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            startActivityAndCollapse(pendingIntent)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
