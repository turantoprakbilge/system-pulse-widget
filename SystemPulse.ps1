param(
    [switch]$StartWithWindows
)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$script:HonorCpuTempAvailable = $false
$script:LastValidCpuTemperature = $null
try {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class HonorBiosTemperature
{
    private const string Dll = @"C:\Program Files\HONOR\BasicService\Util.dll";
    [DllImport(Dll, EntryPoint="?Instance@BiosWmi@@SAAEAV1@XZ", CallingConvention=CallingConvention.Cdecl)]
    private static extern IntPtr Instance();
    [DllImport(Dll, EntryPoint="?Init@BiosWmi@@QEAA_NXZ", CallingConvention=CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)] private static extern bool Init(IntPtr self);
    [DllImport(Dll, EntryPoint="?IsInitialized@BiosWmi@@QEAA_NXZ", CallingConvention=CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)] private static extern bool IsInitialized(IntPtr self);
    [DllImport(Dll, EntryPoint="?GetCpuTemp@BiosWmi@@QEAAMXZ", CallingConvention=CallingConvention.Cdecl)]
    private static extern float ReadCpuTemperature(IntPtr self);

    public static float Read()
    {
        IntPtr instance = Instance();
        if (instance == IntPtr.Zero) return float.NaN;
        if (!IsInitialized(instance) && !Init(instance)) return float.NaN;
        return ReadCpuTemperature(instance);
    }
}
'@ -ErrorAction Stop
    $testTemperature = [HonorBiosTemperature]::Read()
    $script:HonorCpuTempAvailable = -not [single]::IsNaN($testTemperature)
} catch { $script:HonorCpuTempAvailable = $false }

$script:settingsPath = Join-Path $env:LOCALAPPDATA 'SystemPulseWidget\settings_card.json'
$settingsDir = Split-Path $script:settingsPath
if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null }

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="System Pulse" Width="370" Height="410"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False" ResizeMode="NoResize">
  <Border CornerRadius="18" Background="#EE10141C" BorderBrush="#354052" BorderThickness="1" Padding="18">
    <Border.Effect><DropShadowEffect BlurRadius="24" ShadowDepth="4" Opacity="0.55" Color="#000000"/></Border.Effect>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="38"/><RowDefinition Height="*"/><RowDefinition Height="28"/>
      </Grid.RowDefinitions>
      <Grid Grid.Row="0" x:Name="DragArea" Background="Transparent" Cursor="SizeAll">
        <StackPanel Orientation="Horizontal">
          <Ellipse Width="10" Height="10" Fill="#43D9AD" Margin="0,1,10,0"/>
          <TextBlock Text="SYSTEM PULSE" Foreground="#F2F6FC" FontWeight="SemiBold" FontSize="14" VerticalAlignment="Center"/>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <Button x:Name="AlwaysButton" Content="●" ToolTip="Her Zaman Üstte" Width="28" Height="26" Foreground="#43D9AD" Background="Transparent" BorderThickness="0" FontSize="12" Cursor="Hand"/>
          <Button x:Name="CloseButton" Content="×" Width="28" Height="26" Foreground="#96A1B3" Background="Transparent" BorderThickness="0" FontSize="19" Cursor="Hand"/>
        </StackPanel>
      </Grid>
      <StackPanel Grid.Row="1">
        <!-- CPU Row -->
        <Grid Margin="0,4,0,10">
          <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <StackPanel><TextBlock Text="CPU" Foreground="#96A1B3" FontSize="11"/><TextBlock x:Name="CpuText" Text="--%" Foreground="#F2F6FC" FontSize="26" FontWeight="SemiBold"/></StackPanel>
          <TextBlock Grid.Column="1" x:Name="ClockText" Text="-- GHz" Foreground="#68A8FF" FontSize="16" VerticalAlignment="Bottom" Margin="0,0,0,4"/>
        </Grid>
        <ProgressBar x:Name="CpuBar" Height="4" Maximum="100" Foreground="#68A8FF" Background="#263142" BorderThickness="0" Margin="0,-6,0,12"/>

        <!-- GPU Row -->
        <Grid Margin="0,0,0,10">
          <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <StackPanel><TextBlock Text="GPU" Foreground="#96A1B3" FontSize="11"/><TextBlock x:Name="GpuText" Text="--%" Foreground="#F2F6FC" FontSize="26" FontWeight="SemiBold"/></StackPanel>
          <TextBlock Grid.Column="1" x:Name="GpuMemoryText" Text="-- GB" Foreground="#B28CFF" FontSize="16" VerticalAlignment="Bottom" Margin="0,0,0,4"/>
        </Grid>
        <ProgressBar x:Name="GpuBar" Height="4" Maximum="100" Foreground="#B28CFF" Background="#263142" BorderThickness="0" Margin="0,-6,0,12"/>

        <!-- Network Row (DL & UL) -->
        <Grid Margin="0,0,0,8">
          <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
          <Border Grid.Column="0" Background="#1B222E" CornerRadius="10" Padding="10,8" Margin="0,0,4,0">
            <StackPanel>
              <TextBlock Text="DOWNLOAD (İNDİRME)" Foreground="#96A1B3" FontSize="9.5"/>
              <TextBlock x:Name="NetDlText" Text="↓ -- MB/s" Foreground="#FF7FA8" FontSize="16" FontWeight="SemiBold"/>
            </StackPanel>
          </Border>
          <Border Grid.Column="1" Background="#1B222E" CornerRadius="10" Padding="10,8" Margin="4,0,0,0">
            <StackPanel>
              <TextBlock Text="UPLOAD (YÜKLEME)" Foreground="#96A1B3" FontSize="9.5"/>
              <TextBlock x:Name="NetUlText" Text="↑ -- KB/s" Foreground="#FFA3C0" FontSize="16" FontWeight="SemiBold"/>
            </StackPanel>
          </Border>
        </Grid>

        <!-- RAM, DISK, CHARGE Row -->
        <Grid Margin="0,4,0,0">
          <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
          <Border Grid.Column="0" Background="#1B222E" CornerRadius="10" Padding="8,8" Margin="0,0,3,0">
            <StackPanel>
              <TextBlock Text="RAM" Foreground="#96A1B3" FontSize="9.5"/>
              <TextBlock x:Name="RamText" Text="--%" Foreground="#43D9AD" FontSize="16" FontWeight="SemiBold"/>
              <TextBlock x:Name="RamDetailText" Text="-- GB" Foreground="#687386" FontSize="8.5"/>
            </StackPanel>
          </Border>
          <Border Grid.Column="1" Background="#1B222E" CornerRadius="10" Padding="8,8" Margin="3,0,3,0">
            <StackPanel>
              <TextBlock Text="DİSK (OKUMA/YAZMA)" Foreground="#96A1B3" FontSize="9"/>
              <TextBlock x:Name="DiskText" Text="--%" Foreground="#56C7FF" FontSize="16" FontWeight="SemiBold"/>
              <TextBlock x:Name="DiskSpeedText" Text="R: -- W: --" Foreground="#687386" FontSize="8.5"/>
            </StackPanel>
          </Border>
          <Border Grid.Column="2" Background="#1B222E" CornerRadius="10" Padding="8,8" Margin="3,0,0,0">
            <StackPanel>
              <TextBlock Text="GÜÇ / ŞARJ" Foreground="#96A1B3" FontSize="9.5"/>
              <TextBlock x:Name="ChargeText" Text="-- W" Foreground="#FFB86B" FontSize="16" FontWeight="SemiBold"/>
              <TextBlock x:Name="ChargeStateText" Text="Ölçülüyor" Foreground="#687386" FontSize="8.5"/>
            </StackPanel>
          </Border>
        </Grid>
      </StackPanel>
      <TextBlock Grid.Row="2" x:Name="StatusText" Text="Başlatılıyor…" Foreground="#687386" FontSize="10" VerticalAlignment="Bottom" TextTrimming="CharacterEllipsis"/>
    </Grid>
  </Border>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$names = 'DragArea','AlwaysButton','CloseButton','CpuText','ClockText','CpuBar','GpuText','GpuMemoryText','GpuBar','NetDlText','NetUlText','RamText','RamDetailText','DiskText','DiskSpeedText','ChargeText','ChargeStateText','StatusText'
foreach ($name in $names) { Set-Variable -Name $name -Value $window.FindName($name) -Scope Script }

$script:lastRx = [int64]0
$script:lastTx = [int64]0
$script:lastNetTime = $null

function Format-Rate([double]$bytes) {
    if ($bytes -ge 1GB) { return ('{0:N1} GB/s' -f ($bytes / 1GB)) }
    if ($bytes -ge 1MB) { return ('{0:N1} MB/s' -f ($bytes / 1MB)) }
    if ($bytes -ge 1KB) { return ('{0:N0} KB/s' -f ($bytes / 1KB)) }
    return ('{0:N0} B/s' -f $bytes)
}

function Format-CompactRate([double]$bytes) {
    if ($bytes -ge 1GB) { return ('{0:N1}G' -f ($bytes / 1GB)) }
    if ($bytes -ge 1MB) { return ('{0:N1}M' -f ($bytes / 1MB)) }
    if ($bytes -ge 1KB) { return ('{0:N0}K' -f ($bytes / 1KB)) }
    return ('{0:N0}B' -f $bytes)
}

function Update-Metrics {
    try {
        $cpu = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop).PercentProcessorTime
        $freq = (Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation -Filter "Name='_Total'" -ErrorAction Stop).ProcessorFrequency
        $script:CpuText.Text = '{0:N0}%' -f $cpu
        $script:CpuBar.Value = [math]::Min(100, $cpu)
        $script:ClockText.Text = '{0:N2} GHz' -f ($freq / 1000)
    } catch { $script:CpuText.Text = 'N/A'; $script:ClockText.Text = 'N/A' }

    try {
        $engines = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop |
            Where-Object { $_.Name -match 'engtype_(3D|Compute|Graphics|VideoDecode|VideoEncode)' }
        $gpu = if ($engines) { [math]::Min(100, [math]::Round(($engines | Measure-Object UtilizationPercentage -Sum).Sum)) } else { 0 }
        $mem = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory -ErrorAction Stop
        $dedicatedBytes = ($mem | Measure-Object DedicatedUsage -Sum).Sum
        $sharedBytes = ($mem | Measure-Object SharedUsage -Sum).Sum
        $bytes = $dedicatedBytes + $sharedBytes
        $script:GpuText.Text = '{0:N0}%' -f $gpu
        $script:GpuBar.Value = $gpu
        $script:GpuMemoryText.Text = '{0:N1} GB' -f ($bytes / 1GB)
    } catch { $script:GpuText.Text = 'N/A'; $script:GpuMemoryText.Text = 'N/A' }

    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $totalRam = [double]$os.TotalVisibleMemorySize * 1KB
        $usedRam = $totalRam - ([double]$os.FreePhysicalMemory * 1KB)
        $ramPercent = [math]::Round(($usedRam / $totalRam) * 100)
        $script:RamText.Text = "$ramPercent%"
        $script:RamDetailText.Text = '{0:N1} / {1:N1} GB' -f ($usedRam / 1GB), ($totalRam / 1GB)
    } catch { $script:RamText.Text = 'N/A'; $script:RamDetailText.Text = '' }

    try {
        $disk = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'" -ErrorAction Stop
        $script:DiskText.Text = '{0:N0}%' -f [math]::Min(100, $disk.PercentDiskTime)
        $rStr = Format-CompactRate $disk.DiskReadBytesPerSec
        $wStr = Format-CompactRate $disk.DiskWriteBytesPerSec
        $script:DiskSpeedText.Text = "R: $rStr · W: $wStr"
    } catch { $script:DiskText.Text = 'N/A'; $script:DiskSpeedText.Text = '' }

    try {
        $battery = Get-CimInstance -Namespace root/wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue | Select-Object -First 1
        $batteryInfo = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
        $pct = if ($batteryInfo -and $batteryInfo.EstimatedChargeRemaining) { $batteryInfo.EstimatedChargeRemaining } else { 100 }

        if ($battery) {
            if ($battery.Charging -and $battery.ChargeRate -gt 0) {
                $script:ChargeText.Text = '+{0:N1} W' -f ($battery.ChargeRate / 1000)
                $script:ChargeStateText.Text = "$pct% (Şarj)"
            } elseif ($battery.Discharging -and $battery.DischargeRate -gt 0) {
                $script:ChargeText.Text = '-{0:N1} W' -f ($battery.DischargeRate / 1000)
                $script:ChargeStateText.Text = "$pct% (Pilde)"
            } elseif ($battery.PowerOnline) {
                $script:ChargeText.Text = 'Prizde'
                $script:ChargeStateText.Text = "$pct% (Dolu)"
            } else {
                $script:ChargeText.Text = "$pct%"
                $script:ChargeStateText.Text = 'Boşta'
            }
        } else {
            $script:ChargeText.Text = "$pct%"
            $script:ChargeStateText.Text = 'Masaüstü'
        }
    } catch { $script:ChargeText.Text = 'N/A'; $script:ChargeStateText.Text = 'Sensör Yok' }

    try {
        $now = [DateTime]::UtcNow
        $rxTotal = [int64]0
        $txTotal = [int64]0

        $interfaces = [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
            Where-Object {
                $_.OperationalStatus -eq [Net.NetworkInformation.OperationalStatus]::Up -and
                $_.NetworkInterfaceType -ne [Net.NetworkInformation.NetworkInterfaceType]::Loopback -and
                $_.NetworkInterfaceType -ne [Net.NetworkInformation.NetworkInterfaceType]::Tunnel
            }

        foreach ($iface in $interfaces) {
            try {
                $stats = $iface.GetIPv4Statistics()
                $rxTotal += [int64]$stats.BytesReceived
                $txTotal += [int64]$stats.BytesSent
            } catch {}
        }

        if ($null -ne $script:lastNetTime -and $script:lastNetTime -ne $now) {
            $elapsed = ($now - $script:lastNetTime).TotalSeconds
            if ($elapsed -gt 0) {
                $dlRate = [math]::Max(0, ($rxTotal - $script:lastRx) / $elapsed)
                $ulRate = [math]::Max(0, ($txTotal - $script:lastTx) / $elapsed)
                $script:NetDlText.Text = ('↓ {0}' -f (Format-Rate $dlRate))
                $script:NetUlText.Text = ('↑ {0}' -f (Format-Rate $ulRate))
            }
        }
        $script:lastRx = $rxTotal
        $script:lastTx = $txTotal
        $script:lastNetTime = $now
    } catch {
        $script:NetDlText.Text = '↓ N/A'
        $script:NetUlText.Text = '↑ N/A'
    }

    $script:StatusText.Text = 'Son güncelleme: ' + (Get-Date -Format 'HH:mm:ss')
}

$script:DragArea.Add_MouseLeftButtonDown({
    if ($_.LeftButton -eq [System.Windows.Input.MouseButtonState]::Pressed) {
        $timer.Stop()
        try {
            $window.DragMove()
            $_.Handled = $true
        } finally {
            $timer.Start()
        }
    }
})
$script:CloseButton.Add_Click({ $window.Close() })
$script:AlwaysButton.Add_Click({
    $window.Topmost = -not $window.Topmost
    $script:AlwaysButton.Foreground = if ($window.Topmost) { '#43D9AD' } else { '#687386' }
})

if (Test-Path $script:settingsPath) {
    try {
        $saved = Get-Content $script:settingsPath -Raw | ConvertFrom-Json
        if ($null -ne $saved.Left) { $window.Left = $saved.Left; $window.Top = $saved.Top }
    } catch {}
} else {
    $window.WindowStartupLocation = 'CenterScreen'
}

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1.5)
$timer.Add_Tick({ Update-Metrics })
$window.Add_ContentRendered({ Update-Metrics; $timer.Start() })
$window.Add_Closed({
    $timer.Stop()
    @{ Left = $window.Left; Top = $window.Top } | ConvertTo-Json | Set-Content $script:settingsPath -Encoding UTF8
})

if ($StartWithWindows) {
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $PSCommandPath + '"'
    Set-ItemProperty -Path $runKey -Name 'SystemPulseCardWidget' -Value $command
}

$window.ShowDialog() | Out-Null
