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

$script:settingsPath = Join-Path $env:LOCALAPPDATA 'SystemPulseWidget\settings.json'
$settingsDir = Split-Path $script:settingsPath
if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null }

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="System Pulse" Width="360" Height="400"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="True" ResizeMode="NoResize">
  <Border CornerRadius="18" Background="#EE10141C" BorderBrush="#354052" BorderThickness="1" Padding="18">
    <Border.Effect><DropShadowEffect BlurRadius="24" ShadowDepth="4" Opacity="0.5" Color="#000000"/></Border.Effect>
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
          <Button x:Name="AlwaysButton" Content="●" ToolTip="Always on top" Width="28" Height="26" Foreground="#43D9AD" Background="Transparent" BorderThickness="0" FontSize="12"/>
          <Button x:Name="CloseButton" Content="×" Width="28" Height="26" Foreground="#96A1B3" Background="Transparent" BorderThickness="0" FontSize="19"/>
        </StackPanel>
      </Grid>
      <StackPanel Grid.Row="1">
        <Grid Margin="0,4,0,12">
          <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <StackPanel><TextBlock Text="CPU" Foreground="#96A1B3" FontSize="11"/><TextBlock x:Name="CpuText" Text="--%" Foreground="#F2F6FC" FontSize="27" FontWeight="SemiBold"/></StackPanel>
          <TextBlock Grid.Column="1" x:Name="ClockText" Text="-- GHz" Foreground="#68A8FF" FontSize="17" VerticalAlignment="Bottom" Margin="0,0,0,4"/>
        </Grid>
        <ProgressBar x:Name="CpuBar" Height="5" Maximum="100" Foreground="#68A8FF" Background="#263142" BorderThickness="0" Margin="0,-10,0,13"/>
        <Grid Margin="0,0,0,12">
          <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <StackPanel><TextBlock Text="GPU" Foreground="#96A1B3" FontSize="11"/><TextBlock x:Name="GpuText" Text="--%" Foreground="#F2F6FC" FontSize="27" FontWeight="SemiBold"/></StackPanel>
          <TextBlock Grid.Column="1" x:Name="GpuMemoryText" Text="-- GB" Foreground="#B28CFF" FontSize="17" VerticalAlignment="Bottom" Margin="0,0,0,4"/>
        </Grid>
        <ProgressBar x:Name="GpuBar" Height="5" Maximum="100" Foreground="#B28CFF" Background="#263142" BorderThickness="0" Margin="0,-10,0,13"/>
        <Grid>
          <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
          <Border Grid.Column="0" Background="#1B222E" CornerRadius="10" Padding="12,9" Margin="0,0,6,0">
            <StackPanel><TextBlock Text="CPU TEMPERATURE" Foreground="#96A1B3" FontSize="10"/><TextBlock x:Name="CpuTempText" Text="N/A" ToolTip="Temperature sensor unavailable" Foreground="#FFB86B" FontSize="20" FontWeight="SemiBold"/></StackPanel>
          </Border>
          <Border Grid.Column="1" Background="#1B222E" CornerRadius="10" Padding="12,9" Margin="6,0,0,0">
            <StackPanel><TextBlock Text="NETWORK TRAFFIC" Foreground="#96A1B3" FontSize="10"/><TextBlock x:Name="GpuTempText" Text="-- MB/s" ToolTip="Combined download and upload rate" Foreground="#FF6F91" FontSize="20" FontWeight="SemiBold"/></StackPanel>
          </Border>
        </Grid>
        <Grid Margin="0,12,0,0">
          <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
          <Border Grid.Column="0" Background="#1B222E" CornerRadius="10" Padding="10,9" Margin="0,0,4,0">
            <StackPanel><TextBlock Text="RAM" Foreground="#96A1B3" FontSize="10"/><TextBlock x:Name="RamText" Text="--%" Foreground="#43D9AD" FontSize="17" FontWeight="SemiBold"/><TextBlock x:Name="RamDetailText" Text="-- / -- GB" Foreground="#687386" FontSize="9"/></StackPanel>
          </Border>
          <Border Grid.Column="1" Background="#1B222E" CornerRadius="10" Padding="10,9" Margin="4,0,4,0">
            <StackPanel><TextBlock Text="DISK" Foreground="#96A1B3" FontSize="10"/><TextBlock x:Name="DiskText" Text="--%" Foreground="#68A8FF" FontSize="17" FontWeight="SemiBold"/><TextBlock x:Name="DiskSpeedText" Text="-- MB/s" Foreground="#687386" FontSize="9"/></StackPanel>
          </Border>
          <Border Grid.Column="2" Background="#1B222E" CornerRadius="10" Padding="10,9" Margin="4,0,0,0">
            <StackPanel><TextBlock Text="POWER" Foreground="#96A1B3" FontSize="10"/><TextBlock x:Name="ChargeText" Text="-- W" Foreground="#FFB86B" FontSize="17" FontWeight="SemiBold"/><TextBlock x:Name="ChargeStateText" Text="Measuring" Foreground="#687386" FontSize="9"/></StackPanel>
          </Border>
        </Grid>
      </StackPanel>
      <TextBlock Grid.Row="2" x:Name="StatusText" Text="Starting…" Foreground="#687386" FontSize="10" VerticalAlignment="Bottom" TextTrimming="CharacterEllipsis"/>
    </Grid>
  </Border>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$names = 'DragArea','AlwaysButton','CloseButton','CpuText','ClockText','CpuBar','GpuText','GpuMemoryText','GpuBar','CpuTempText','GpuTempText','RamText','RamDetailText','DiskText','DiskSpeedText','ChargeText','ChargeStateText','StatusText'
foreach ($name in $names) { Set-Variable -Name $name -Value $window.FindName($name) -Scope Script }

function Get-SensorTemperature {
    param([string]$HardwareType)
    if ($HardwareType -eq 'CPU' -and $script:HonorCpuTempAvailable) {
        try {
            $temperature = [HonorBiosTemperature]::Read()
            # Honor BIOS-WMI can transiently return 0 during initialization.
            # A running laptop CPU cannot be at or below 10 C; reject that
            # sentinel and retain the latest confirmed package temperature.
            if (-not [single]::IsNaN($temperature) -and $temperature -gt 10 -and $temperature -le 110) {
                $script:LastValidCpuTemperature = [math]::Round($temperature)
                return $script:LastValidCpuTemperature
            }
        } catch {}
        if ($null -ne $script:LastValidCpuTemperature) { return $script:LastValidCpuTemperature }
    }
    return $null
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
        # Integrated Arc GPUs use system RAM. Include shared memory instead of
        # reading only dedicated VRAM (which is normally zero on this model).
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
        $script:DiskSpeedText.Text = '{0:N1} MB/s' -f ($disk.DiskBytesPerSec / 1MB)
    } catch { $script:DiskText.Text = 'N/A'; $script:DiskSpeedText.Text = '' }

    try {
        $battery = Get-CimInstance -Namespace root/wmi -ClassName BatteryStatus -ErrorAction Stop | Select-Object -First 1
        if ($battery.Charging -and $battery.ChargeRate -gt 0) {
            $script:ChargeText.Text = '{0:N1} W' -f ($battery.ChargeRate / 1000)
            $script:ChargeStateText.Text = 'Into battery'
        } elseif ($battery.Discharging -and $battery.DischargeRate -gt 0) {
            $script:ChargeText.Text = '-{0:N1} W' -f ($battery.DischargeRate / 1000)
            $script:ChargeStateText.Text = 'From battery'
        } else {
            $script:ChargeText.Text = '0,0 W'
            $script:ChargeStateText.Text = if ($battery.PowerOnline) { 'Plugged in' } else { 'Idle' }
        }
    } catch { $script:ChargeText.Text = 'N/A'; $script:ChargeStateText.Text = 'Sensor unavailable' }

    $cpuTemp = Get-SensorTemperature 'CPU'
    $script:CpuTempText.Text = if ($null -ne $cpuTemp) { "$cpuTemp°C" } else { 'N/A' }
    try {
        $network = Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface -ErrorAction Stop |
            Where-Object { $_.Name -notmatch 'Loopback|isatap|Teredo' }
        $networkBytes = ($network | Measure-Object BytesTotalPersec -Sum).Sum
        $script:GpuTempText.Text = if ($networkBytes -ge 1MB) {
            '{0:N1} MB/s' -f ($networkBytes / 1MB)
        } else {
            '{0:N0} KB/s' -f ($networkBytes / 1KB)
        }
        $script:GpuTempText.FontSize = 20
    } catch { $script:GpuTempText.Text = 'N/A' }
    $script:StatusText.Text = 'Last updated  •  ' + (Get-Date -Format 'HH:mm:ss')
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
$timer.Interval = [TimeSpan]::FromSeconds(2)
$timer.Add_Tick({ Update-Metrics })
$window.Add_ContentRendered({ Update-Metrics; $timer.Start() })
$window.Add_Closed({
    $timer.Stop()
    @{ Left = $window.Left; Top = $window.Top } | ConvertTo-Json | Set-Content $script:settingsPath -Encoding UTF8
})

if ($StartWithWindows) {
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $PSCommandPath + '"'
    Set-ItemProperty -Path $runKey -Name 'SystemPulseWidget' -Value $command
}

$window.ShowDialog() | Out-Null
