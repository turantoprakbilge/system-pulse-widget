# System Pulse - Taskbar Strip Monitor
# Lightweight Windows 10/11 taskbar-docked hardware monitor

param(
    [switch]$StartWithWindows,
    [switch]$Install
)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing, System.Windows.Forms

# Honor CPU temperature sensor integration (if available)
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

$script:appDataDir = Join-Path $env:LOCALAPPDATA 'SystemPulseWidget'
if (-not (Test-Path $script:appDataDir)) { New-Item -ItemType Directory -Path $script:appDataDir -Force | Out-Null }
$script:settingsPath = Join-Path $script:appDataDir 'settings.json'

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="System Pulse"
        Width="1120" Height="48"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False" ResizeMode="NoResize">
  <Window.Resources>
    <Style TargetType="TextBlock">
      <Setter Property="FontFamily" Value="Segoe UI Variable, Segoe UI, sans-serif"/>
    </Style>
    <Style x:Key="MetricLabel" TargetType="TextBlock">
      <Setter Property="FontSize" Value="9.5"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Foreground" Value="#6B7B94"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>
    <Style x:Key="MetricValPrimary" TargetType="TextBlock">
      <Setter Property="FontSize" Value="12.5"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>
    <Style x:Key="MetricValSecondary" TargetType="TextBlock">
      <Setter Property="FontSize" Value="9.5"/>
      <Setter Property="Foreground" Value="#8695AB"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>
  </Window.Resources>

  <Border x:Name="MainBorder" Background="#F20B0F17" BorderBrush="#2A3547" BorderThickness="1" CornerRadius="10" Padding="10,4">
    <Border.Effect>
      <DropShadowEffect BlurRadius="16" ShadowDepth="2" Opacity="0.6" Color="#000000"/>
    </Border.Effect>

    <Border.ContextMenu>
      <ContextMenu Background="#131923" Foreground="#E1E7F0" BorderBrush="#2D3A4E">
        <MenuItem x:Name="MenuTopmost" Header="Always on Top" IsCheckable="True" IsChecked="True"/>
        <Separator Background="#263244"/>
        <MenuItem x:Name="MenuDockRight" Header="Dock to Taskbar (Bottom Right)"/>
        <MenuItem x:Name="MenuDockCenter" Header="Dock to Taskbar (Bottom Center)"/>
        <MenuItem x:Name="MenuDockLeft" Header="Dock to Taskbar (Bottom Left)"/>
        <Separator Background="#263244"/>
        <MenuItem x:Name="MenuAutostart" Header="Start with Windows" IsCheckable="True"/>
        <Separator Background="#263244"/>
        <MenuItem x:Name="MenuExit" Header="Exit"/>
      </ContextMenu>
    </Border.ContextMenu>

    <Grid VerticalAlignment="Center">
      <Grid.ColumnDefinitions>
        <!-- 0: Logo -->
        <ColumnDefinition Width="Auto"/>
        <!-- 1: Divider -->
        <ColumnDefinition Width="12"/>
        <!-- 2: SYS (Uptime and Top Process) -->
        <ColumnDefinition Width="1.15*"/>
        <!-- 3: Divider -->
        <ColumnDefinition Width="8"/>
        <!-- 4: CPU -->
        <ColumnDefinition Width="*"/>
        <!-- 5: Divider -->
        <ColumnDefinition Width="8"/>
        <!-- 6: RAM -->
        <ColumnDefinition Width="1.05*"/>
        <!-- 7: Divider -->
        <ColumnDefinition Width="8"/>
        <!-- 8: GPU -->
        <ColumnDefinition Width="0.95*"/>
        <!-- 9: Divider -->
        <ColumnDefinition Width="8"/>
        <!-- 10: DISK -->
        <ColumnDefinition Width="1.35*"/>
        <!-- 11: Divider -->
        <ColumnDefinition Width="8"/>
        <!-- 12: NET (with Ping) -->
        <ColumnDefinition Width="1.35*"/>
        <!-- 13: Divider -->
        <ColumnDefinition Width="8"/>
        <!-- 14: POWER (with Estimated Remaining Time) -->
        <ColumnDefinition Width="1.35*"/>
        <!-- 15: Controls -->
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>

      <!-- Logo / Pulse Drag Area -->
      <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="2,0,2,0" Cursor="SizeAll" ToolTip="Drag to move | Right-click for settings">
        <Ellipse x:Name="PulseDot" Width="8" Height="8" Fill="#43D9AD" Margin="0,0,6,0"/>
        <TextBlock Text="PULSE" Foreground="#F0F4F8" FontWeight="Bold" FontSize="11" VerticalAlignment="Center"/>
      </StackPanel>

      <!-- Divider 1 -->
      <Rectangle Grid.Column="1" Width="1" Fill="#1E2736" HorizontalAlignment="Center" Margin="0,3"/>

      <!-- SYS (Uptime & Top Resource Process) -->
      <StackPanel Grid.Column="2" VerticalAlignment="Center" Cursor="SizeAll" ToolTip="System Uptime and Top CPU Consumer">
        <StackPanel Orientation="Horizontal">
          <TextBlock Text="SYS " Style="{StaticResource MetricLabel}"/>
          <TextBlock x:Name="UptimeText" Text="-- d -- h" Foreground="#E2E8F0" Style="{StaticResource MetricValPrimary}"/>
        </StackPanel>
        <TextBlock x:Name="TopProcText" Text="Top: measuring..." Style="{StaticResource MetricValSecondary}" TextTrimming="CharacterEllipsis"/>
      </StackPanel>

      <!-- Divider 2 -->
      <Rectangle Grid.Column="3" Width="1" Fill="#1E2736" HorizontalAlignment="Center" Margin="0,3"/>

      <!-- CPU (with CPU Temperature) -->
      <StackPanel Grid.Column="4" VerticalAlignment="Center" Cursor="SizeAll" ToolTip="CPU Utilization, Frequency and Package Temperature">
        <StackPanel Orientation="Horizontal">
          <TextBlock Text="CPU " Style="{StaticResource MetricLabel}"/>
          <TextBlock x:Name="CpuText" Text="--%" Foreground="#68A8FF" Style="{StaticResource MetricValPrimary}"/>
        </StackPanel>
        <TextBlock x:Name="ClockText" Text="-- GHz" Style="{StaticResource MetricValSecondary}"/>
      </StackPanel>

      <!-- Divider 3 -->
      <Rectangle Grid.Column="5" Width="1" Fill="#1E2736" HorizontalAlignment="Center" Margin="0,3"/>

      <!-- RAM -->
      <StackPanel Grid.Column="6" VerticalAlignment="Center" Cursor="SizeAll" ToolTip="Memory Usage and Allocated / Total Physical RAM">
        <StackPanel Orientation="Horizontal">
          <TextBlock Text="RAM " Style="{StaticResource MetricLabel}"/>
          <TextBlock x:Name="RamText" Text="--%" Foreground="#43D9AD" Style="{StaticResource MetricValPrimary}"/>
        </StackPanel>
        <TextBlock x:Name="RamDetailText" Text="-- / -- GB" Style="{StaticResource MetricValSecondary}"/>
      </StackPanel>

      <!-- Divider 4 -->
      <Rectangle Grid.Column="7" Width="1" Fill="#1E2736" HorizontalAlignment="Center" Margin="0,3"/>

      <!-- GPU (Utilization and Memory - NO GPU Temperature) -->
      <StackPanel Grid.Column="8" VerticalAlignment="Center" Cursor="SizeAll" ToolTip="GPU Utilization and Shared/Dedicated Memory">
        <StackPanel Orientation="Horizontal">
          <TextBlock Text="GPU " Style="{StaticResource MetricLabel}"/>
          <TextBlock x:Name="GpuText" Text="--%" Foreground="#B28CFF" Style="{StaticResource MetricValPrimary}"/>
        </StackPanel>
        <TextBlock x:Name="GpuMemText" Text="-- GB" Style="{StaticResource MetricValSecondary}"/>
      </StackPanel>

      <!-- Divider 5 -->
      <Rectangle Grid.Column="9" Width="1" Fill="#1E2736" HorizontalAlignment="Center" Margin="0,3"/>

      <!-- DISK (Read and Write Speeds) -->
      <StackPanel Grid.Column="10" VerticalAlignment="Center" Cursor="SizeAll" ToolTip="Disk Activity and Real-Time Read / Write Speeds">
        <StackPanel Orientation="Horizontal">
          <TextBlock Text="DISK " Style="{StaticResource MetricLabel}"/>
          <TextBlock x:Name="DiskUsageText" Text="--%" Foreground="#56C7FF" Style="{StaticResource MetricValPrimary}"/>
        </StackPanel>
        <TextBlock x:Name="DiskSpeedText" Text="R: 0 KB/s | W: 0 KB/s" Style="{StaticResource MetricValSecondary}"/>
      </StackPanel>

      <!-- Divider 6 -->
      <Rectangle Grid.Column="11" Width="1" Fill="#1E2736" HorizontalAlignment="Center" Margin="0,3"/>

      <!-- NET (Upload, Download & Ping Latency) -->
      <StackPanel Grid.Column="12" VerticalAlignment="Center" Cursor="SizeAll" ToolTip="Network Download (DL), Upload (UL) and Ping Latency">
        <StackPanel Orientation="Horizontal">
          <TextBlock Text="NET " Style="{StaticResource MetricLabel}"/>
          <TextBlock x:Name="NetDlText" Text="DL: 0 KB/s" Foreground="#FF7FA8" Style="{StaticResource MetricValPrimary}"/>
        </StackPanel>
        <TextBlock x:Name="NetUlText" Text="UL: 0 KB/s | -- ms" Style="{StaticResource MetricValSecondary}"/>
      </StackPanel>

      <!-- Divider 7 -->
      <Rectangle Grid.Column="13" Width="1" Fill="#1E2736" HorizontalAlignment="Center" Margin="0,3"/>

      <!-- POWER (Charging Speed, Battery Status, Temp and Estimated Remaining Time) -->
      <StackPanel Grid.Column="14" VerticalAlignment="Center" Cursor="SizeAll" ToolTip="Live Power Draw, Battery Percentage and Estimated Remaining Time">
        <StackPanel Orientation="Horizontal">
          <TextBlock Text="PWR " Style="{StaticResource MetricLabel}"/>
          <TextBlock x:Name="PowerRateText" Text="-- W" Foreground="#FFB86B" Style="{StaticResource MetricValPrimary}"/>
        </StackPanel>
        <TextBlock x:Name="PowerDetailText" Text="Measuring..." Style="{StaticResource MetricValSecondary}"/>
      </StackPanel>

      <!-- Controls -->
      <StackPanel Grid.Column="15" Orientation="Horizontal" VerticalAlignment="Center" Margin="4,0,0,0">
        <Button x:Name="PinButton" Content="PIN" ToolTip="Always on Top" Width="24" Height="22" Foreground="#43D9AD" Background="Transparent" BorderThickness="0" FontSize="9" FontWeight="Bold" Cursor="Hand" Margin="0,0,1,0"/>
        <Button x:Name="CloseButton" Content="X" ToolTip="Close" Width="22" Height="22" Foreground="#707E94" Background="Transparent" BorderThickness="0" FontSize="11" FontWeight="Bold" Cursor="Hand"/>
      </StackPanel>

    </Grid>
  </Border>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Element variable bindings
$names = 'MainBorder','PulseDot','UptimeText','TopProcText','CpuText','ClockText','RamText','RamDetailText','GpuText','GpuMemText','DiskUsageText','DiskSpeedText','NetDlText','NetUlText','PowerRateText','PowerDetailText','PinButton','CloseButton','MenuTopmost','MenuDockRight','MenuDockCenter','MenuDockLeft','MenuAutostart','MenuExit'
foreach ($name in $names) {
    $elem = $window.FindName($name)
    if ($elem) { Set-Variable -Name $name -Value $elem -Scope Script }
}

$script:lastRx = [int64]0
$script:lastTx = [int64]0
$script:lastNetTime = $null
$script:pulseToggle = $false
$script:cachedPing = "-- ms"
$script:tickCounter = 0
$script:numCores = [Environment]::ProcessorCount
$script:pinger = [System.Net.NetworkInformation.Ping]::new()

function Format-Rate([double]$bytes) {
    if ($bytes -ge 1GB) { return ('{0:N1} GB/s' -f ($bytes / 1GB)) }
    if ($bytes -ge 1MB) { return ('{0:N1} MB/s' -f ($bytes / 1MB)) }
    if ($bytes -ge 1KB) { return ('{0:N0} KB/s' -f ($bytes / 1KB)) }
    return '0 KB/s'
}

function Format-CompactRate([double]$bytes) {
    if ($bytes -ge 1GB) { return ('{0:N1} GB/s' -f ($bytes / 1GB)) }
    if ($bytes -ge 1MB) { return ('{0:N1} MB/s' -f ($bytes / 1MB)) }
    if ($bytes -ge 1KB) { return ('{0:N0} KB/s' -f ($bytes / 1KB)) }
    return '0 KB/s'
}

function Get-SensorCpuTemp {
    if ($script:HonorCpuTempAvailable) {
        try {
            $t = [HonorBiosTemperature]::Read()
            if (-not [single]::IsNaN($t) -and $t -gt 10 -and $t -le 115) {
                $script:LastValidCpuTemperature = [math]::Round($t)
                return $script:LastValidCpuTemperature
            }
        } catch {}
        if ($null -ne $script:LastValidCpuTemperature) { return $script:LastValidCpuTemperature }
    }
    return $null
}

function Get-SensorBatteryTemp {
    try {
        $bt = Get-CimInstance -Namespace root/wmi -ClassName BatteryTemperature -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($bt -and $bt.Temperature -gt 0) {
            $celsius = [math]::Round(($bt.Temperature - 2732) / 10.0)
            if ($celsius -gt 5 -and $celsius -lt 85) {
                return "$celsius C"
            }
        }
    } catch {}
    return $null
}

function Dock-ToTaskbar([string]$position = 'Right') {
    $area = [System.Windows.SystemParameters]::WorkArea
    $window.Top = [math]::Max(0, ($area.Bottom - $window.Height - 6))
    
    switch ($position) {
        'Right'  { $window.Left = [math]::Max(0, ($area.Right - $window.Width - 12)) }
        'Center' { $window.Left = [math]::Max(0, ($area.Left + (($area.Width - $window.Width) / 2))) }
        'Left'   { $window.Left = [math]::Max(0, ($area.Left + 12)) }
    }
    Save-Settings
}

function Save-Settings {
    try {
        $data = @{
            Left = $window.Left
            Top = $window.Top
            Topmost = $window.Topmost
        }
        $data | ConvertTo-Json | Set-Content $script:settingsPath -Encoding UTF8
    } catch {}
}

function Load-Settings {
    $loaded = $false
    if (Test-Path $script:settingsPath) {
        try {
            $data = Get-Content $script:settingsPath -Raw | ConvertFrom-Json
            if ($null -ne $data.Left -and $null -ne $data.Top) {
                $window.Left = $data.Left
                $window.Top = $data.Top
                if ($null -ne $data.Topmost) {
                    $window.Topmost = [bool]$data.Topmost
                    $script:PinButton.Foreground = if ($window.Topmost) { '#43D9AD' } else { '#687B94' }
                    $script:MenuTopmost.IsChecked = $window.Topmost
                }
                $loaded = $true
            }
        } catch {}
    }
    if (-not $loaded) {
        Dock-ToTaskbar 'Right'
    }
}

function Check-Autostart {
    try {
        $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        $val = (Get-ItemProperty -Path $runKey -Name 'SystemPulseWidget' -ErrorAction SilentlyContinue).SystemPulseWidget
        return ($null -ne $val)
    } catch { return $false }
}

function Set-Autostart([bool]$enable) {
    try {
        $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        if ($enable) {
            $vbs = Join-Path $script:appDataDir 'launcher.vbs'
            $cmd = "wscript.exe //B `"$vbs`""
            Set-ItemProperty -Path $runKey -Name 'SystemPulseWidget' -Value $cmd
        } else {
            Remove-ItemProperty -Path $runKey -Name 'SystemPulseWidget' -ErrorAction SilentlyContinue
        }
    } catch {}
}

function Update-Metrics {
    $script:tickCounter++
    
    # Visual pulse tick
    $script:pulseToggle = -not $script:pulseToggle
    $script:PulseDot.Opacity = if ($script:pulseToggle) { 1.0 } else { 0.45 }

    # 1. System Uptime
    try {
        $ts = [TimeSpan]::FromMilliseconds([Environment]::TickCount64)
        $script:UptimeText.Text = if ($ts.Days -gt 0) {
            ('{0}d {1}h' -f $ts.Days, $ts.Hours)
        } elseif ($ts.Hours -gt 0) {
            ('{0}h {1}m' -f $ts.Hours, $ts.Minutes)
        } else {
            ('{0}m' -f $ts.Minutes)
        }
    } catch { $script:UptimeText.Text = '--' }

    # 2. Top Resource Process
    try {
        $topProc = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '_Total|Idle' } |
            Sort-Object PercentProcessorTime -Descending |
            Select-Object -First 1
        if ($topProc -and $topProc.Name) {
            $pName = $topProc.Name -replace '#\d+$',''
            $pctVal = [math]::Round($topProc.PercentProcessorTime / $script:numCores)
            $script:TopProcText.Text = ('Top: {0} ({1}%)' -f $pName, $pctVal)
        } else {
            $script:TopProcText.Text = 'Top: Idle'
        }
    } catch {
        $script:TopProcText.Text = 'Top: --'
    }

    # 3. CPU, Frequency and CPU Temperature
    try {
        $cpu = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop).PercentProcessorTime
        $freq = (Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation -Filter "Name='_Total'" -ErrorAction Stop).ProcessorFrequency
        $cpuTemp = Get-SensorCpuTemp
        
        $script:CpuText.Text = '{0:N0}%' -f $cpu
        $script:ClockText.Text = if ($null -ne $cpuTemp) {
            ('{0:N2} GHz | {1} C' -f ($freq / 1000), $cpuTemp)
        } else {
            ('{0:N2} GHz' -f ($freq / 1000))
        }
    } catch {
        $script:CpuText.Text = 'N/A'
        $script:ClockText.Text = '-- GHz'
    }

    # 4. RAM
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $totalRam = [double]$os.TotalVisibleMemorySize * 1KB
        $usedRam = $totalRam - ([double]$os.FreePhysicalMemory * 1KB)
        $ramPct = [math]::Round(($usedRam / $totalRam) * 100)
        $script:RamText.Text = "$ramPct%"
        $script:RamDetailText.Text = '{0:N1} / {1:N1} GB' -f ($usedRam / 1GB), ($totalRam / 1GB)
    } catch {
        $script:RamText.Text = 'N/A'
        $script:RamDetailText.Text = '-- / -- GB'
    }

    # 5. GPU (Utilization + VRAM - STRICTLY NO GPU TEMP)
    try {
        $engines = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop |
            Where-Object { $_.Name -match 'engtype_(3D|Compute|Graphics|VideoDecode|VideoEncode)' }
        $gpu = if ($engines) { [math]::Min(100, [math]::Round(($engines | Measure-Object UtilizationPercentage -Sum).Sum)) } else { 0 }
        $mem = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory -ErrorAction Stop
        $vramBytes = (($mem | Measure-Object DedicatedUsage -Sum).Sum) + (($mem | Measure-Object SharedUsage -Sum).Sum)
        $script:GpuText.Text = '{0:N0}%' -f $gpu
        $script:GpuMemText.Text = '{0:N1} GB' -f ($vramBytes / 1GB)
    } catch {
        $script:GpuText.Text = 'N/A'
        $script:GpuMemText.Text = '-- GB'
    }

    # 6. DISK (Activity % + Read Speed + Write Speed)
    try {
        $disk = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'" -ErrorAction Stop
        $diskPct = [math]::Min(100, $disk.PercentDiskTime)
        $rSpeed = Format-CompactRate $disk.DiskReadBytesPerSec
        $wSpeed = Format-CompactRate $disk.DiskWriteBytesPerSec
        $script:DiskUsageText.Text = '{0:N0}%' -f $diskPct
        $script:DiskSpeedText.Text = ('R: {0} | W: {1}' -f $rSpeed, $wSpeed)
    } catch {
        $script:DiskUsageText.Text = 'N/A'
        $script:DiskSpeedText.Text = 'R: -- | W: --'
    }

    # 7. NETWORK (Real-time Upload/Download Speeds & Ping Latency)
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

        # Update Ping every 2 ticks (approx 3s)
        if ($script:tickCounter % 2 -eq 1) {
            try {
                $reply = $script:pinger.Send('1.1.1.1', 350)
                if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                    $script:cachedPing = "$($reply.RoundtripTime) ms"
                } else {
                    $script:cachedPing = "timeout"
                }
            } catch {
                $script:cachedPing = "off"
            }
        }

        if ($null -ne $script:lastNetTime -and $script:lastNetTime -ne $now) {
            $elapsed = ($now - $script:lastNetTime).TotalSeconds
            if ($elapsed -gt 0) {
                $dlRate = [math]::Max(0, ($rxTotal - $script:lastRx) / $elapsed)
                $ulRate = [math]::Max(0, ($txTotal - $script:lastTx) / $elapsed)
                
                $script:NetDlText.Text = ('DL: {0}' -f (Format-Rate $dlRate))
                $script:NetUlText.Text = ('UL: {0} | {1}' -f (Format-Rate $ulRate), $script:cachedPing)
            }
        }
        $script:lastRx = $rxTotal
        $script:lastTx = $txTotal
        $script:lastNetTime = $now
    } catch {
        $script:NetDlText.Text = 'DL: N/A'
        $script:NetUlText.Text = 'UL: N/A'
    }

    # 8. POWER / BATTERY (Live Wattage, Battery Temp & Estimated Remaining Time)
    try {
        $battery = Get-CimInstance -Namespace root/wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue | Select-Object -First 1
        $batteryInfo = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
        $pct = if ($batteryInfo -and $batteryInfo.EstimatedChargeRemaining) { $batteryInfo.EstimatedChargeRemaining } else { 100 }
        $batTemp = Get-SensorBatteryTemp
        $tempSuffix = if ($null -ne $batTemp) { " | $batTemp" } else { "" }

        if ($battery) {
            if ($battery.Charging -and $battery.ChargeRate -gt 0) {
                $watt = $battery.ChargeRate / 1000
                $script:PowerRateText.Text = ('+{0:N1} W' -f $watt)
                $script:PowerRateText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#43D9AD')
                $script:PowerDetailText.Text = "$pct% (Charging$tempSuffix)"
            } elseif ($battery.Discharging -and $battery.DischargeRate -gt 0) {
                $watt = $battery.DischargeRate / 1000
                $script:PowerRateText.Text = ('-{0:N1} W' -f $watt)
                $script:PowerRateText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#FFB86B')
                
                # Calculate estimated remaining time
                $remStr = ""
                if ($battery.RemainingCapacity -gt 0) {
                    $hoursLeft = $battery.RemainingCapacity / $battery.DischargeRate
                    $h = [math]::Floor($hoursLeft)
                    $m = [math]::Round(($hoursLeft - $h) * 60)
                    $remStr = " | ${h}h ${m}m"
                }
                $script:PowerDetailText.Text = "$pct% (Battery$remStr$tempSuffix)"
            } elseif ($battery.PowerOnline) {
                $script:PowerRateText.Text = "0.0 W (AC)"
                $script:PowerRateText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#68A8FF')
                $script:PowerDetailText.Text = "$pct% (Full$tempSuffix)"
            } else {
                $script:PowerRateText.Text = "$pct%"
                $script:PowerRateText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#96A1B3')
                $script:PowerDetailText.Text = "Idle$tempSuffix"
            }
        } else {
            $script:PowerRateText.Text = "$pct%"
            $script:PowerRateText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#96A1B3')
            $script:PowerDetailText.Text = "Desktop"
        }
    } catch {
        $script:PowerRateText.Text = 'N/A'
        $script:PowerDetailText.Text = 'No Sensor'
    }
}

# Window Dragging
$window.Add_MouseLeftButtonDown({
    if ($_.LeftButton -eq [System.Windows.Input.MouseButtonState]::Pressed) {
        $timer.Stop()
        try {
            $window.DragMove()
            $_.Handled = $true
            Save-Settings
        } finally {
            $timer.Start()
        }
    }
})

# Close and Pin handlers
$script:CloseButton.Add_Click({ $window.Close() })
$script:PinButton.Add_Click({
    $window.Topmost = -not $window.Topmost
    $script:PinButton.Foreground = if ($window.Topmost) { '#43D9AD' } else { '#687B94' }
    $script:MenuTopmost.IsChecked = $window.Topmost
    Save-Settings
})

# Context Menu Handlers
$script:MenuTopmost.Add_Click({
    $window.Topmost = $script:MenuTopmost.IsChecked
    $script:PinButton.Foreground = if ($window.Topmost) { '#43D9AD' } else { '#687B94' }
    Save-Settings
})
$script:MenuDockRight.Add_Click({ Dock-ToTaskbar 'Right' })
$script:MenuDockCenter.Add_Click({ Dock-ToTaskbar 'Center' })
$script:MenuDockLeft.Add_Click({ Dock-ToTaskbar 'Left' })
$script:MenuAutostart.Add_Click({
    Set-Autostart $script:MenuAutostart.IsChecked
})
$script:MenuExit.Add_Click({ $window.Close() })

# Initial Settings and Autostart state
$script:MenuAutostart.IsChecked = Check-Autostart
if ($StartWithWindows) {
    Set-Autostart $true
    $script:MenuAutostart.IsChecked = $true
}

# Timer Setup (1.5s refresh for responsive, smooth updates)
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(1500)
$timer.Add_Tick({ Update-Metrics })

$window.Add_ContentRendered({
    Load-Settings
    Update-Metrics
    $timer.Start()
})

$window.Add_Closed({
    $timer.Stop()
    Save-Settings
})

$window.ShowDialog() | Out-Null
