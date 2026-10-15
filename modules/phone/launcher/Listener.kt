package dev.neru.bare

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class Listener : NotificationListenerService() {
    override fun onListenerConnected() {
        changed?.invoke()
    }

    override fun onListenerDisconnected() {
        changed?.invoke()
    }

    override fun onNotificationPosted(notification: StatusBarNotification?) {
        changed?.invoke()
    }

    override fun onNotificationRemoved(notification: StatusBarNotification?) {
        changed?.invoke()
    }

    companion object {
        var changed: (() -> Unit)? = null
    }
}
