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

# Set Windows Graphics to run game in high-performance mode
Write-Host "Setting GPU preferences to use Dedicated GPU"
foreach ($exe in $HighPerformanceExecutables) {
    reg.exe Add "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" /v "$($ProjectD2InstallPath)\$($exe)" /d "GpuPreference=2;" /f
}
Write-Host "Successfully set GPU preferences"


#################################################
# Computer settings -- requires admin+elevation
#################################################
# Rerun script as elevated if it's not already
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
	Start-Process powershell -Verb runas -ArgumentList "& '$script'"
	exit $lastexitcode
}
#################################################


# Set compatibility mode settings
Write-Host "Setting Compatibility Mode to WINXP SP3"
foreach ($exe in $CompatibilityExecutables) {
	reg.exe Add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "$($ProjectD2InstallPath)\$($exe)" /d "~ RUNASADMIN WINXPSP3" /f
}
Write-Host "Successfully set Compatibility Mode"

# Create Exploit Protection overrides
Write-Host "Setting Exploit Protection overrides"
foreach ($exe in $ExploitProtectionExecutables) {
    Set-Processmitigation -Name "$($ProjectD2InstallPath)\$($exe)" -Disable DEP,EmulateAtlThunks,ForceRelocateImages,RequireInfo,BottomUp,      `
                                                                            HighEntropy,StrictHandle,DisableWin32kSystemCalls,AuditSystemCall,  `
                                                                            DisableExtensionPoints,BlockDynamicCode,AllowThreadsToOptOut,       `
                                                                            AuditDynamicCode,CFG,SuppressExports,StrictCFG,MicrosoftSignedOnly, `
                                                                            AllowStoreSignedBinaries,AuditMicrosoftSigned,AuditStoreSigned,     `
                                                                            EnforceModuleDependencySigning,DisableNonSystemFonts,AuditFont,     `
                                                                            BlockRemoteImageLoads,BlockLowLabelImageLoads,PreferSystem32,       `
                                                                            AuditRemoteImageLoads,AuditLowLabelImageLoads,AuditPreferSystem32,  `
                                                                            EnableExportAddressFilter,AuditEnableExportAddressFilter,           `
                                                                            EnableExportAddressFilterPlus,AuditEnableExportAddressFilterPlus,   `
                                                                            EnableImportAddressFilter,AuditEnableImportAddressFilter,           `
                                                                            EnableRopStackPivot,AuditEnableRopStackPivot,EnableRopCallerCheck,  `
                                                                            AuditEnableRopCallerCheck,EnableRopSimExec,AuditEnableRopSimExec,   `
                                                                            SEHOP,AuditSEHOP,SEHOPTelemetry,TerminateOnError,                   `
                                                                            DisallowChildProcessCreation,AuditChildProcess,UserShadowStack,     `
                                                                            UserShadowStackStrictMode,AuditUserShadowStack
}
Write-Host "Successfully set Exploit Protection overrides"

# Create Defender exception
Write-Host "Adding Windows Defender exclusions"
foreach ($path in $DefenderExclusionPaths) {
	Add-MpPreference -ExclusionPath "$($path)"
}
Write-Host "Successfully added Windows Defender exclusions"

Write-Host "Successfully set Windows Permissions for PD2 executables"
pause
