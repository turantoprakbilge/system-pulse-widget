Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

try {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class HonorTaskbarTemperature {
 const string D=@"C:\Program Files\HONOR\BasicService\Util.dll";
 [DllImport(D,EntryPoint="?Instance@BiosWmi@@SAAEAV1@XZ",CallingConvention=CallingConvention.Cdecl)] static extern IntPtr Instance();
 [DllImport(D,EntryPoint="?Init@BiosWmi@@QEAA_NXZ",CallingConvention=CallingConvention.Cdecl)][return:MarshalAs(UnmanagedType.I1)] static extern bool Init(IntPtr p);
 [DllImport(D,EntryPoint="?IsInitialized@BiosWmi@@QEAA_NXZ",CallingConvention=CallingConvention.Cdecl)][return:MarshalAs(UnmanagedType.I1)] static extern bool IsInitialized(IntPtr p);
 [DllImport(D,EntryPoint="?GetCpuTemp@BiosWmi@@QEAAMXZ",CallingConvention=CallingConvention.Cdecl)] static extern float GetTemp(IntPtr p);
 public static float Read(){var p=Instance();if(p==IntPtr.Zero)return float.NaN;if(!IsInitialized(p)&&!Init(p))return float.NaN;return GetTemp(p);}
}
'@
} catch {}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="System Pulse"
 Width="860" Height="66" WindowStyle="None" AllowsTransparency="True" Background="Transparent"
 Topmost="True" ShowInTaskbar="False" ResizeMode="NoResize">
 <Border Background="#F510141C" BorderBrush="#465267" BorderThickness="1" CornerRadius="12" Padding="12,5">
  <Border.Effect><DropShadowEffect BlurRadius="14" ShadowDepth="2" Opacity="0.45"/></Border.Effect>
  <Grid>
   <Grid.RowDefinitions><RowDefinition/><RowDefinition/></Grid.RowDefinitions>
   <Grid.ColumnDefinitions><ColumnDefinition Width="90"/><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/><ColumnDefinition Width="25"/></Grid.ColumnDefinitions>
   <StackPanel Grid.Column="0" Grid.RowSpan="2" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,10,0">
    <Ellipse Width="8" Height="8" Fill="#43D9AD" Margin="0,0,7,0"/><TextBlock Text="PULSE" Foreground="#DDE6F3" FontWeight="SemiBold" FontSize="11"/>
   </StackPanel>
   <TextBlock Grid.Column="1" Grid.Row="0" x:Name="Temp" Foreground="#FFB86B" FontSize="12" VerticalAlignment="Center" Text="CPU --°"/>
   <TextBlock Grid.Column="2" Grid.Row="0" x:Name="Cpu" Foreground="#68A8FF" FontSize="12" VerticalAlignment="Center" Text="CPU --%"/>
   <TextBlock Grid.Column="3" Grid.Row="0" x:Name="Clock" Foreground="#68A8FF" FontSize="12" VerticalAlignment="Center" Text="-- GHz"/>
   <TextBlock Grid.Column="4" Grid.Row="0" x:Name="Gpu" Foreground="#B28CFF" FontSize="12" VerticalAlignment="Center" Text="GPU --%"/>
   <TextBlock Grid.Column="5" Grid.Row="0" x:Name="GpuMem" Foreground="#B28CFF" FontSize="12" VerticalAlignment="Center" Text="GPU RAM -- GB"/>
   <TextBlock Grid.Column="1" Grid.Row="1" x:Name="Ram" Foreground="#43D9AD" FontSize="12" VerticalAlignment="Center" Text="RAM --%"/>
   <TextBlock Grid.Column="2" Grid.Row="1" x:Name="RamDetail" Foreground="#43D9AD" FontSize="12" VerticalAlignment="Center" Text="-- / -- GB"/>
   <TextBlock Grid.Column="3" Grid.Row="1" x:Name="Disk" Foreground="#56C7FF" FontSize="12" VerticalAlignment="Center" Text="DISK --%"/>
   <TextBlock Grid.Column="4" Grid.Row="1" x:Name="Network" Foreground="#FF8DB3" FontSize="12" VerticalAlignment="Center" Text="NET -- KB/s"/>
   <TextBlock Grid.Column="5" Grid.Row="1" x:Name="Power" Foreground="#FF6F91" FontSize="12" VerticalAlignment="Center" Text="CHARGE -- W"/>
   <Button Grid.Column="6" Grid.RowSpan="2" x:Name="Close" Content="×" ToolTip="Close" Foreground="#7D899B" Background="Transparent" BorderThickness="0" FontSize="17" Width="25"/>
  </Grid>
 </Border>
</Window>
'@
$reader=New-Object System.Xml.XmlNodeReader $xaml
$window=[Windows.Markup.XamlReader]::Load($reader)
foreach($n in 'Temp','Cpu','Clock','Gpu','GpuMem','Ram','RamDetail','Disk','Network','Power','Close'){Set-Variable -Scope Script -Name $n -Value $window.FindName($n)}
$script:lastTemp=$null

function Set-Position {
 $area=[System.Windows.SystemParameters]::WorkArea
 $window.Left=$area.Right-$window.Width-12
 $window.Top=$area.Bottom-$window.Height-6
}
function Update-Values {
 try{$t=[HonorTaskbarTemperature]::Read();if(-not[single]::IsNaN($t)-and$t-gt 10-and$t-le 110){$script:lastTemp=[math]::Round($t)};if($null-ne$script:lastTemp){$script:Temp.Text="CPU $($script:lastTemp)°"}}catch{}
 try{$c=(Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime;$f=(Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation -Filter "Name='_Total'").ProcessorFrequency;$script:Cpu.Text="CPU $([math]::Round($c))%";$script:Clock.Text=('{0:N2} GHz'-f($f/1000))}catch{}
 try{$e=Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine|Where-Object{$_.Name-match'engtype_(3D|Compute|Graphics|VideoDecode|VideoEncode)'};$g=[math]::Min(100,[math]::Round(($e|Measure-Object UtilizationPercentage -Sum).Sum));$m=Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory;$gb=(($m|Measure-Object DedicatedUsage -Sum).Sum+($m|Measure-Object SharedUsage -Sum).Sum)/1GB;$script:Gpu.Text="GPU $g%";$script:GpuMem.Text=('GPU RAM {0:N1} GB'-f$gb)}catch{}
 try{$o=Get-CimInstance Win32_OperatingSystem;$total=[double]$o.TotalVisibleMemorySize;$used=$total-[double]$o.FreePhysicalMemory;$r=[math]::Round($used/$total*100);$script:Ram.Text="RAM $r%";$script:RamDetail.Text=('{0:N1} / {1:N1} GB'-f($used*1KB/1GB),($total*1KB/1GB))}catch{}
 try{$d=Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'";$dp=[math]::Min(100,$d.PercentDiskTime);$script:Disk.Text=('DISK {0:N0}% · {1:N1} MB/s'-f$dp,($d.DiskBytesPerSec/1MB))}catch{}
 try{$n=Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface|Where-Object{$_.Name-notmatch'Loopback|isatap|Teredo'};$nb=($n|Measure-Object BytesTotalPersec -Sum).Sum;$script:Network.Text=if($nb-ge 1MB){'NET {0:N1} MB/s'-f($nb/1MB)}else{'NET {0:N0} KB/s'-f($nb/1KB)}}catch{}
 try{$b=Get-CimInstance -Namespace root/wmi -ClassName BatteryStatus|Select-Object -First 1;if($b.Charging-and$b.ChargeRate-gt 0){$w=$b.ChargeRate/1000;$script:Power.Text=('CHARGE {0:N1} W'-f$w)}elseif($b.Discharging-and$b.DischargeRate-gt 0){$w=$b.DischargeRate/1000;$script:Power.Text=('BATTERY -{0:N1} W'-f$w)}else{$script:Power.Text='CHARGE 0 W'}}catch{}
 Set-Position
}
$script:Close.Add_Click({$window.Close()})
$window.Add_MouseLeftButtonDown({if($_.LeftButton-eq[Windows.Input.MouseButtonState]::Pressed){$timer.Stop();try{$window.DragMove()}finally{$timer.Start()}}})
$timer=New-Object Windows.Threading.DispatcherTimer
$timer.Interval=[TimeSpan]::FromSeconds(2)
$timer.Add_Tick({Update-Values})
$window.Add_ContentRendered({Set-Position;Update-Values;$timer.Start()})
$window.Add_Closed({$timer.Stop()})
$window.ShowDialog()|Out-Null
