package com.luffytv.luffytv

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build

class UpdateInstallReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_INSTALL_STATUS = "com.luffytv.luffytv.UPDATE_INSTALL_STATUS"
        const val EXTRA_VERSION_CODE = "expectedVersionCode"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(
            PackageInstaller.EXTRA_STATUS,
            PackageInstaller.STATUS_FAILURE,
        )
        val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
        val versionCode = intent.getLongExtra(EXTRA_VERSION_CODE, 0)
        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            UpdateInstallState.write(context, "pending_user_action", message, versionCode)
            val confirmation = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_INTENT)
            }
            confirmation?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (confirmation != null) context.startActivity(confirmation)
            return
        }

        val mapped = when (status) {
            PackageInstaller.STATUS_SUCCESS -> "success"
            PackageInstaller.STATUS_FAILURE_ABORTED -> "failed_aborted"
            PackageInstaller.STATUS_FAILURE_BLOCKED -> "failed_blocked"
            PackageInstaller.STATUS_FAILURE_CONFLICT -> "failed_conflict"
            PackageInstaller.STATUS_FAILURE_INCOMPATIBLE -> "failed_incompatible"
            PackageInstaller.STATUS_FAILURE_INVALID -> "failed_invalid"
            PackageInstaller.STATUS_FAILURE_STORAGE -> "failed_storage"
            else -> "failed"
        }
        UpdateInstallState.write(context, mapped, message, versionCode)
        if (status != PackageInstaller.STATUS_SUCCESS) {
            val reopen = context.packageManager.getLaunchIntentForPackage(context.packageName)
            reopen?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            if (reopen != null) context.startActivity(reopen)
        }
    }
}

object UpdateInstallState {
    private const val PREFS = "luffytv_update_installer"
    private const val STATUS = "status"
    private const val MESSAGE = "message"
    private const val VERSION_CODE = "versionCode"

    fun write(context: Context, status: String, message: String?, versionCode: Long) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(STATUS, status)
            .putString(MESSAGE, message)
            .putLong(VERSION_CODE, versionCode)
            .apply()
    }

    fun read(context: Context): Map<String, Any?> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return mapOf(
            "status" to (prefs.getString(STATUS, "none") ?: "none"),
            "message" to prefs.getString(MESSAGE, null),
            "versionCode" to prefs.getLong(VERSION_CODE, 0),
        )
    }

    fun clear(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }
}
