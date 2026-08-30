package dev.toprak.systempulse

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.TrafficStats
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import java.io.File
import kotlin.math.roundToInt

data class PulseSnapshot(
    val cpuPercent: Int = 0,
    val cpuGHz: Double = 0.0,
    val ramPercent: Int = 0,
    val ramUsedGb: Double = 0.0,
    val ramTotalGb: Double = 0.0,
    val storagePercent: Int = 0,
    val storageUsedGb: Double = 0.0,
    val storageTotalGb: Double = 0.0,
    val networkBytesPerSec: Long = 0,
    val batteryPercent: Int = 0,
    val batteryTempC: Double = 0.0,
    val batteryWatts: Double? = null,
    val charging: Boolean = false,
    val device: String = "${Build.MANUFACTURER} ${Build.MODEL}",
    val androidVersion: String = "Android ${Build.VERSION.RELEASE}"
)

class SystemMonitor(private val context: Context) {
    private var lastCpuTotal = 0L
    private var lastCpuIdle = 0L
    private var lastRx = TrafficStats.getTotalRxBytes().coerceAtLeast(0)
    private var lastTx = TrafficStats.getTotalTxBytes().coerceAtLeast(0)
    private var lastNetworkAt = System.nanoTime()

    fun sample(): PulseSnapshot {
        val cpu = readCpuLoad()
        val clock = readCpuClockGHz()
        val am = context.getSystemService(ActivityManager::class.java)
        val mem = ActivityManager.MemoryInfo().also(am::getMemoryInfo)
        val ramTotal = mem.totalMem.toDouble()
        val ramUsed = ramTotal - mem.availMem

        val stat = StatFs(Environment.getDataDirectory().path)
        val storageTotal = stat.totalBytes.toDouble()
        val storageFree = stat.availableBytes.toDouble()
        val storageUsed = storageTotal - storageFree

        val battery = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = battery?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = battery?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        val status = battery?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val charging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
        val temp = (battery?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0) / 10.0
        val bm = context.getSystemService(BatteryManager::class.java)
        val currentUa = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
        val voltageMv = battery?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0) ?: 0
        val watts = if (currentUa != Int.MIN_VALUE && voltageMv > 0) currentUa.toDouble() * voltageMv / 1_000_000_000.0 else null

        return PulseSnapshot(
            cpuPercent = cpu,
            cpuGHz = clock,
            ramPercent = percent(ramUsed, ramTotal),
            ramUsedGb = gb(ramUsed), ramTotalGb = gb(ramTotal),
            storagePercent = percent(storageUsed, storageTotal),
            storageUsedGb = gb(storageUsed), storageTotalGb = gb(storageTotal),
            networkBytesPerSec = readNetworkRate(),
            batteryPercent = if (level >= 0) (level * 100.0 / scale).roundToInt() else 0,
            batteryTempC = temp,
            batteryWatts = watts,
            charging = charging
        )
    }

    private fun readCpuLoad(): Int = try {
        val fields = File("/proc/stat").useLines { it.first().trim().split(Regex("\\s+")) }
        val values = fields.drop(1).map { it.toLong() }
        val idle = values.getOrElse(3) { 0 } + values.getOrElse(4) { 0 }
        val total = values.sum()
        val totalDelta = total - lastCpuTotal
        val idleDelta = idle - lastCpuIdle
        lastCpuTotal = total; lastCpuIdle = idle
        if (totalDelta <= 0) 0 else ((totalDelta - idleDelta) * 100.0 / totalDelta).roundToInt().coerceIn(0, 100)
    } catch (_: Exception) { 0 }

    private fun readCpuClockGHz(): Double {
        val values = File("/sys/devices/system/cpu").listFiles { f -> f.name.matches(Regex("cpu\\d+")) }
            ?.mapNotNull { cpu -> runCatching { File(cpu, "cpufreq/scaling_cur_freq").readText().trim().toLong() }.getOrNull() }
            .orEmpty()
        return if (values.isEmpty()) 0.0 else values.average() / 1_000_000.0
    }

    private fun readNetworkRate(): Long {
        val now = System.nanoTime()
        val rx = TrafficStats.getTotalRxBytes().coerceAtLeast(0)
        val tx = TrafficStats.getTotalTxBytes().coerceAtLeast(0)
        val seconds = (now - lastNetworkAt) / 1_000_000_000.0
        val delta = (rx - lastRx) + (tx - lastTx)
        lastRx = rx; lastTx = tx; lastNetworkAt = now
        return if (seconds > 0) (delta / seconds).toLong().coerceAtLeast(0) else 0
    }

    private fun percent(used: Double, total: Double) = if (total <= 0) 0 else (used / total * 100).roundToInt().coerceIn(0, 100)
    private fun gb(bytes: Double) = bytes / 1024.0 / 1024.0 / 1024.0
}
