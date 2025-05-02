# Отключение макросов в Office (Word и Excel)
$officePaths = @(
    "HKCU:\Software\Policies\Microsoft\Office\16.0\Word\Security",
    "HKCU:\Software\Policies\Microsoft\Office\16.0\Excel\Security"
)
foreach ($path in $officePaths) {
    New-Item -Path $path -Force | Out-Null
    Set-ItemProperty -Path $path -Name "VBAWarnings" -Value 4
}
Write-Host "Office macros disabled"

# Отключение AutoPlay
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Value 255
Write-Host "AutoPlay disabled."

# Полная блокировка входящего/исходящего трафика

Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block -DefaultOutboundAction Block
Write-Host "All network traffic blocked."

# Отключение SMBv1
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart
Write-Host "SMBv1 disabled"


# Аудит процессов и объектов
auditpol /set /subcategory:"Файловая система" /success:enable /failure:enable
auditpol /set /subcategory:"Создано приложением" /success:enable /failure:enable
auditpol /set /subcategory:"Создание процесса" /success:enable /failure:enable
auditpol /set /subcategory:"Вход в систему" /success:enable /failure:enable
auditpol /set /subcategory:"Блокировка учетной записи" /success:enable /failure:enable
auditpol /set /subcategory:"Другие события доступа к объекту" /success:enable /failure:enable
auditpol /set /subcategory:"События RPC" /success:enable /failure:enable
auditpol /set /subcategory:"Выход из системы" /success:enable /failure:enable
auditpol /set /subcategory:"Другие события входа и выхода" /success:enable /failure:enable
Write-Host "Auditing enabled."