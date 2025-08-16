$script = $myinvocation.mycommand.Definition

# Rerun script in 64bit process if 64bit system -- required for Defender exceptions
if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    & (join-path ($pshome -replace "syswow64", "sysnative")\powershell.exe) -file "$script"
    exit $lastexitcode
}

# Setup
$ProjectD2InstallPath         = Split-Path -Parent $script
$Diablo2InstallPath           = Split-Path -Path $ProjectD2InstallPath -Parent
$CompatibilityExecutables     = @("Game.exe", "Diablo II.exe", "PlugY.exe")
$ExploitProtectionExecutables = @("Game.exe", "Diablo II.exe", "PD2Launcher.exe", "Updater.exe", "PlugY.exe")
$HighPerformanceExecutables   = @("Game.exe", "Diablo II.exe")
$DefenderExclusionPaths       = @($($Diablo2InstallPath))


#################################################
# User settings -- admin not required
#################################################

# Remove Windows Graphics setting
Write-Host "Removing GPU preference settings"
foreach ($exe in $HighPerformanceExecutables) {
    reg.exe Delete "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" /v "$($ProjectD2InstallPath)\$($exe)" /f
}
Write-Host "Successfully removed GPU preferences"


#################################################
# Computer settings -- requires admin+elevation
#################################################
# Rerun script as elevated if it's not already
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
	Start-Process powershell -Verb runas -ArgumentList "& '$script'"
	exit $lastexitcode
}
#################################################


# Remove compatibility mode settings
Write-Host "Removing Compatibility Mode settings"
foreach ($exe in $CompatibilityExecutables) {
	reg.exe Delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "$($ProjectD2InstallPath)\$($exe)" /f
}
Write-Host "Successfully removed Compatibility Mode settings"

# Remove Exploit Protection overrides
Write-Host "Removing Exploit Protection overrides"
foreach ($exe in $ExploitProtectionExecutables) {    
    reg.exe Delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$($exe)" /f
}
Write-Host "Successfully removed Exploit Protection overrides"

# Remove Defender exception
Write-Host "Removing Windows Defender exclusions"
foreach ($path in $DefenderExclusionPaths) {
	Remove-MpPreference -ExclusionPath "$($path)"
}
Write-Host "Successfully removed Windows Defender exclusions"

Write-Host "Successfully removed Windows Permissions for PD2 executables"
pause
