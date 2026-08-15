package dev.toprak.systempulse

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import java.util.Locale

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { PulseApp(SystemMonitor(applicationContext)) }
    }
}

private val Bg = Color(0xFF0B0F16)
private val Card = Color(0xFF111824)
private val Border = Color(0xFF2A3547)
private val Text = Color(0xFFDDE6F3)
private val Muted = Color(0xFF7D899B)
private val Blue = Color(0xFF68A8FF)
private val Green = Color(0xFF43D9AD)
private val Pink = Color(0xFFFF8DB3)
private val Orange = Color(0xFFFFB86B)

@Composable
fun PulseApp(monitor: SystemMonitor) {
    var data by remember { mutableStateOf(monitor.sample()) }
    LaunchedEffect(Unit) { while (true) { delay(2000); data = monitor.sample() } }
    MaterialTheme(colorScheme = darkColorScheme(background = Bg, surface = Card, onSurface = Text)) {
        Surface(Modifier.fillMaxSize(), color = Bg) {
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Spacer(Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(9.dp).background(Green, RoundedCornerShape(50)))
                    Spacer(Modifier.width(9.dp))
                    Text("SYSTEM PULSE", color = Text, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.weight(1f))
                    Text("LIVE · 2s", color = Green, fontSize = 11.sp)
                }
                Text("${data.device} · ${data.androidVersion}", color = Muted, fontSize = 12.sp)
                MetricCard("CPU", "${data.cpuPercent}%", if (data.cpuGHz > 0) f("%.2f GHz", data.cpuGHz) else "Frequency unavailable", data.cpuPercent / 100f, Blue)
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    SmallMetric("RAM", "${data.ramPercent}%", f("%.1f / %.1f GB", data.ramUsedGb, data.ramTotalGb), data.ramPercent / 100f, Green, Modifier.weight(1f))
                    SmallMetric("STORAGE", "${data.storagePercent}%", f("%.0f / %.0f GB", data.storageUsedGb, data.storageTotalGb), data.storagePercent / 100f, Blue, Modifier.weight(1f))
                }
                MetricCard("NETWORK", rate(data.networkBytesPerSec), "Combined upload + download", null, Pink)
                MetricCard("BATTERY", "${data.batteryPercent}%", batteryLine(data), data.batteryPercent / 100f, if (data.charging) Green else Orange)
                Text("Android restricts third-party apps from reading universal GPU utilization and CPU temperature. Battery temperature is shown instead; available CPU frequency values depend on the device kernel.", color = Muted, fontSize = 11.sp, lineHeight = 16.sp)
            }
        }
    }
}

@Composable private fun MetricCard(label: String, value: String, detail: String, progress: Float?, accent: Color) {
    Card(colors = CardDefaults.cardColors(containerColor = Card), shape = RoundedCornerShape(18.dp), border = androidx.compose.foundation.BorderStroke(1.dp, Border)) {
        Column(Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(label, color = Muted, fontSize = 11.sp, fontWeight = FontWeight.Bold)
            Text(value, color = accent, fontSize = 28.sp, fontWeight = FontWeight.SemiBold)
            Text(detail, color = Text, fontSize = 12.sp)
            if (progress != null) LinearProgressIndicator(progress = { progress.coerceIn(0f, 1f) }, modifier = Modifier.fillMaxWidth().height(5.dp), color = accent, trackColor = Border)
        }
    }
}

@Composable private fun SmallMetric(label: String, value: String, detail: String, progress: Float, accent: Color, modifier: Modifier) {
    Card(modifier, colors = CardDefaults.cardColors(containerColor = Card), shape = RoundedCornerShape(18.dp), border = androidx.compose.foundation.BorderStroke(1.dp, Border)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
            Text(label, color = Muted, fontSize = 10.sp, fontWeight = FontWeight.Bold)
            Text(value, color = accent, fontSize = 23.sp, fontWeight = FontWeight.SemiBold)
            Text(detail, color = Text, fontSize = 11.sp)
            LinearProgressIndicator(progress = { progress }, modifier = Modifier.fillMaxWidth().height(4.dp), color = accent, trackColor = Border)
        }
    }
}

private fun batteryLine(d: PulseSnapshot): String {
    val state = if (d.charging) "Charging" else "On battery"
    val power = d.batteryWatts?.let { " · ${if (it >= 0) "+" else ""}${f("%.1f", it)} W" } ?: ""
    return "$state · ${f("%.1f", d.batteryTempC)} °C$power"
}
private fun rate(v: Long) = if (v >= 1024 * 1024) f("%.1f MB/s", v / 1048576.0) else f("%.1f KB/s", v / 1024.0)
private fun f(format: String, vararg args: Any) = String.format(Locale.US, format, *args)
