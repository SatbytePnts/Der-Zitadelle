# Имя обычного пользователя
$targetUser = "User"

# 1. AppLocker: разрешить только Word и Excel
Write-Host "1. AppLocker: разрешаем только Word и Excel..."
# Запустить службу Application Identity
Set-Service -Name AppIDSvc -StartupType Automatic
Start-Service AppIDSvc

# Пути к Word и Excel
$wordPath = "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE"
$excelPath = "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE"

# Создать разрешающие правила только для пользователя
$rules = @()
$rules += New-AppLockerFilePathRule -Path $wordPath -User $targetUser -RuleType Allow -RuleCollectionType Executable
$rules += New-AppLockerFilePathRule -Path $excelPath -User $targetUser -RuleType Allow -RuleCollectionType Executable

# Создать AppLocker политику
$policy = New-AppLockerPolicy -RuleCollection @($rules) -User $targetUser -RuleType Executable

# Применить политику (только для этого пользователя)
Set-AppLockerPolicy -PolicyObject $policy -Merge -ErrorAction Stop

# 2. Блокировка внешних носителей
Write-Host "2. Блокировка чтения/записи внешних носителей..."
$remKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices"
New-Item -Path $remKey -Force | Out-Null
Set-ItemProperty -Path $remKey -Name "Deny_Read"  -Value 1 -Type DWord
Set-ItemProperty -Path $remKey -Name "Deny_Write" -Value 1 -Type DWord

# 3. Отключение AutoPlay
Write-Host "3. Отключаем AutoPlay..."
$apKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
New-Item -Path $apKey -Force | Out-Null
Set-ItemProperty -Path $apKey -Name "NoDriveTypeAutoRun" -Value 0xFF -Type DWord

# 4. Блокировка интернета (весь исходящий и входящий трафик)
Write-Host "4. Блокируем интернет..."
New-NetFirewallRule -DisplayName "Block Outbound" -Direction Outbound -Action Block -Profile Domain,Private,Public
New-NetFirewallRule -DisplayName "Block Inbound"  -Direction Inbound  -Action Block -Profile Domain,Private,Public

# 5. Ограничение PowerShell только для User
Write-Host "5. Отключаем PowerShell-скрипты и включаем Constrained Language для пользователя..."
$psKey = "HKU:\"
$profile = Get-WmiObject -Class Win32_UserProfile | Where-Object { $_.LocalPath -like "*\$targetUser" }
if ($profile) {
    $sid = $profile.SID
    $regBase = "Registry::HKEY_USERS\$sid\Software\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell"
    New-Item -Path $regBase -Force | Out-Null
    Set-ItemProperty -Path $regBase -Name "ExecutionPolicy" -Value "Restricted"

    # Ограничим язык
    $langKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell"
    New-Item -Path $langKey -Force | Out-Null
    Set-ItemProperty -Path $langKey -Name "EnableScripts" -Value 0 -Type DWord
    Set-ItemProperty -Path $langKey -Name "LanguageMode" -Value "ConstrainedLanguage" -Type String
} else {
    Write-Warning "Не найден SID для пользователя '$targetUser'"
}

# 6. Включение Controlled Folder Access
Write-Host "6. Включаем Controlled Folder Access..."
Set-MpPreference -EnableControlledFolderAccess Enabled

# 7. Отключение макросов в Office (только для пользователя)
Write-Host "7. Отключаем макросы в Office..."
$officeApps = "word","excel","powerpoint"
foreach ($app in $officeApps) {
    $key = "Registry::HKEY_USERS\$sid\Software\Policies\Microsoft\office\$app\security\vbaprotection"
    New-Item -Path $key -Force | Out-Null
    Set-ItemProperty -Path $key -Name "level" -Value 1 -Type DWord
}

# 8. Включение аудита
Write-Host "8. Включаем аудит..."
auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable
auditpol /set /subcategory:"File System" /success:enable /failure:enable
auditpol /set /subcategory:"Registry" /success:enable /failure:enable

Write-Host "`n✅ Политики успешно применены для пользователя '$targetUser'. Перезагрузите систему."
