<# 
.SYNOPSIS
  Настройка локальной «GPO»–изоляции:
    • Разрешить запуск только dcox.exe
    • Блокировать чтение/запись внешних носителей
    • Отключить AutoPlay
    • Блокировать весь исходящий/входящий трафик (интернет)
    • Отключить PowerShell-скрипты и включить Constrained Language
    • Включить Controlled Folder Access (Defender)
    • Отключить макросы в Office
    • Включить аудит процессов и объектов
#>

# Проверка запуска от Admin
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error "Запустите PowerShell от имени администратора!"
  exit 1
}

# 1. AppLocker: разрешить только dcox.exe
Write-Host "1. Настраиваем AppLocker..."
# Запустить сервис Application Identity
Set-Service -Name AppIDSvc -StartupType Automatic
Start-Service AppIDSvc
# Создать политику: разрешить C:\Program Files\dcox\dcox.exe, затем дефолтный запрет
$allowRule = New-AppLockerFileHashRule -Path "C:\Program Files\dcox\dcox.exe" `
    -User "Everyone" -RuleType Allow -FileHashType SHA256
$defaultDeny = New-AppLockerPolicy -DefaultRuleType Deny -RuleType Executable
# Собираем финальную политику
$policy = New-AppLockerPolicy -RuleCollection @($allowRule) -RuleType Executable -FallbackAction Deny
Set-AppLockerPolicy -PolicyObject $policy -Merge -ErrorAction Stop

# 2. Блокировка внешних носителей и AutoPlay
Write-Host "2. Блокируем накопители и отключаем AutoPlay..."
# REMOVABLE STORAGE ACCESS
$remKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices"
New-Item -Path $remKey -Force | Out-Null
# 1 = Deny
Set-ItemProperty -Path $remKey -Name "Deny_Read"  -Value 1 -Type DWord
Set-ItemProperty -Path $remKey -Name "Deny_Write" -Value 1 -Type DWord
# AUTOPLAY
$apKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
New-Item -Path $apKey -Force | Out-Null
Set-ItemProperty -Path $apKey -Name "NoViewOnDrive"      -Value 0xFFFFFFFF -Type DWord
Set-ItemProperty -Path $apKey -Name "NoDriveTypeAutoRun" -Value 0xFF       -Type DWord

# 3. Настройка Windows Firewall — блок всего трафика
Write-Host "3. Создаем правила брандмауэра..."
# Удалим старые похожие правила
Get-NetFirewallRule -DisplayName "Block Internet Outbound" -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule
# Исходящие
New-NetFirewallRule -DisplayName "Block Internet Outbound" `
    -Direction Outbound -Action Block -Profile Domain,Private,Public
# Входящие (если нужно)
New-NetFirewallRule -DisplayName "Block Internet Inbound" `
    -Direction Inbound  -Action Block -Profile Domain,Private,Public

# 4. Отключаем PowerShell–скрипты и включаем Constrained Language
Write-Host "4. Жесткая политика PowerShell..."
Set-ExecutionPolicy Restricted -Scope LocalMachine -Force
$psReg = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell"
New-Item -Path $psReg -Force | Out-Null
Set-ItemProperty -Path $psReg -Name "EnableScripts"    -Value 0 -Type DWord
Set-ItemProperty -Path $psReg -Name "LanguageMode"     -Value "ConstrainedLanguage" -Type String

# 5. Включаем Controlled Folder Access (Exploit Guard)
Write-Host "5. Включаем Controlled Folder Access..."
Import-Module Defender
Set-MpPreference -EnableControlledFolderAccess Enabled

# 6. Запрет макросов в Office (Word, Excel, PowerPoint)
Write-Host "6. Блокируем макросы в Office..."
# Общие Policy для версии Office 2016/2019/365
$officeRoot = "HKLM:\SOFTWARE\Policies\Microsoft\office"
$apps = "word","excel","powerpoint"
Foreach ($app in $apps) {
  $key = "$officeRoot\$app\security\vbaprotection"
  New-Item -Path $key -Force | Out-Null
  # 1 = Disable all macros without notification
  Set-ItemProperty -Path $key -Name "level" -Value 1 -Type DWord
}

# 7. Включаем аудит создания процессов и доступа к объектам
Write-Host "7. Включаем аудит..."
# Аудит процессов
auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable
# Аудит доступа к файлам/папкам (Object Access)
auditpol /set /subcategory:"File System"     /success:enable /failure:enable
auditpol /set /subcategory:"Registry"        /success:enable /failure:enable

Write-Host "Все политики успешно применены. Перезагрузите машину для вступления в силу.`n"

