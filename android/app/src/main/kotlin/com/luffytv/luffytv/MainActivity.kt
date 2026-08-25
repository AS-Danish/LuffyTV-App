package com.luffytv.luffytv

import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.StatFs
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.luffytv/update_installer"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "isSelfUpdaterSupported" -> result.success(BuildConfig.FLAVOR == "sideload")
                        "getAvailableBytes" -> result.success(StatFs(cacheDir.path).availableBytes)
                        "canRequestPackageInstalls" -> result.success(canRequestPackageInstalls())
                        "openUnknownSourcesSettings" -> {
                            openUnknownSourcesSettings()
                            result.success(null)
                        }
                        "inspectApk" -> {
                            val path = call.argument<String>("path")
                                ?: throw IllegalArgumentException("APK path is required.")
                            result.success(inspectApk(validatedUpdateFile(path)))
                        }
                        "installApk" -> {
                            val path = call.argument<String>("path")
                                ?: throw IllegalArgumentException("APK path is required.")
                            val expectedVersionCode = call.argument<Number>("expectedVersionCode")?.toLong()
                                ?: throw IllegalArgumentException("Expected versionCode is required.")
                            result.success(installApk(validatedUpdateFile(path), expectedVersionCode))
                        }
                        "getInstallationStatus" -> result.success(UpdateInstallState.read(this))
                        "clearInstallationStatus" -> {
                            UpdateInstallState.clear(this)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Throwable) {
                    result.error("UPDATE_INSTALLER_ERROR", error.message, error.javaClass.simpleName)
                }
            }
    }

    private fun canRequestPackageInstalls(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()

    private fun openUnknownSourcesSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        startActivity(
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            ),
        )
    }

    private fun validatedUpdateFile(path: String): File {
        if (BuildConfig.FLAVOR != "sideload") {
            throw SecurityException("Self-updating is disabled for this distribution.")
        }
        val file = File(path).canonicalFile
        val updateRoot = File(cacheDir, "update").canonicalFile
        if (!file.path.startsWith(updateRoot.path + File.separator) ||
            file.extension.lowercase() !in setOf("apk", "part") ||
            !file.isFile
        ) {
            throw SecurityException("APK is outside Luffy TV's validated update directory.")
        }
        return file
    }

    private fun inspectApk(file: File): Map<String, Any> {
        val archive = packageInfoForArchive(file)
            ?: throw IllegalArgumentException("Android could not parse the APK.")
        val installed = packageInfoForInstalled()
        val archiveSigners = signerDigests(archive)
        val installedSigners = signerDigests(installed)
        return mapOf(
            "packageName" to archive.packageName,
            "versionCode" to longVersionCode(archive),
            "signatureMatches" to (
                archiveSigners.isNotEmpty() &&
                    installedSigners.isNotEmpty() &&
                    archiveSigners.any(installedSigners::contains)
                ),
        )
    }

    private fun installApk(file: File, expectedVersionCode: Long): Int {
        if (!canRequestPackageInstalls()) {
            throw SecurityException("Unknown-source permission is not granted.")
        }
        val inspection = inspectApk(file)
        if (inspection["packageName"] != packageName ||
            inspection["versionCode"] != expectedVersionCode ||
            inspection["signatureMatches"] != true
        ) {
            throw SecurityException("APK identity validation failed before installation.")
        }

        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(packageName)
            setSize(file.length())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_REQUIRED)
            }
        }
        val packageInstaller = packageManager.packageInstaller
        val sessionId = packageInstaller.createSession(params)
        try {
            packageInstaller.openSession(sessionId).use { session ->
                file.inputStream().use { input ->
                    session.openWrite("base.apk", 0, file.length()).use { output ->
                        input.copyTo(output, 1024 * 1024)
                        session.fsync(output)
                    }
                }
                UpdateInstallState.write(
                    this,
                    "committed",
                    "Waiting for Android installer.",
                    expectedVersionCode,
                )
                val callbackIntent = Intent(this, UpdateInstallReceiver::class.java).apply {
                    action = UpdateInstallReceiver.ACTION_INSTALL_STATUS
                    putExtra(UpdateInstallReceiver.EXTRA_VERSION_CODE, expectedVersionCode)
                }
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
                val pendingIntent = PendingIntent.getBroadcast(this, sessionId, callbackIntent, flags)
                session.commit(pendingIntent.intentSender)
            }
        } catch (error: Throwable) {
            packageInstaller.abandonSession(sessionId)
            throw error
        }
        return sessionId
    }

    @Suppress("DEPRECATION")
    private fun packageInfoForArchive(file: File): PackageInfo? {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
        return packageManager.getPackageArchiveInfo(file.path, flags)?.also {
            it.applicationInfo?.sourceDir = file.path
            it.applicationInfo?.publicSourceDir = file.path
        }
    }

    @Suppress("DEPRECATION")
    private fun packageInfoForInstalled(): PackageInfo {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
        return packageManager.getPackageInfo(packageName, flags)
    }

    @Suppress("DEPRECATION")
    private fun signerDigests(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = info.signingInfo ?: return emptySet()
            if (signingInfo.hasMultipleSigners()) signingInfo.apkContentsSigners
            else signingInfo.signingCertificateHistory
        } else {
            info.signatures
        }
        return signatures.orEmpty().mapTo(mutableSetOf()) { signature ->
            MessageDigest.getInstance("SHA-256")
                .digest(signature.toByteArray())
                .joinToString("") { byte -> "%02x".format(byte) }
        }
    }

    @Suppress("DEPRECATION")
    private fun longVersionCode(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            info.versionCode.toLong()
        }
}
