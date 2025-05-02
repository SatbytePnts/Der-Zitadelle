# Требуем права администратора
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Ошибка: Скрипт требует прав администратора!" -ForegroundColor Red
    Exit 1
}

# Создаем временный файл политики
$secPolicy = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[System Access]
MinimumPasswordAge = 1
MaximumPasswordAge = 90
MinimumPasswordLength = 12
PasswordHistorySize = 5
PasswordComplexity = 1
ClearTextPassword = 0
[Account Lockout]
LockoutBadCount = 5
ResetLockoutCount = 15
LockoutDuration = 30
"@

# Сохраняем во временный файл
$tempFile = [System.IO.Path]::GetTempFileName()
$secPolicy | Out-File -FilePath $tempFile -Encoding ASCII

try {
    # Применяем политику безопасности
    $dbPath = "$env:TEMP\secedit.sdb"
    secedit /configure /db $dbPath /cfg $tempFile /areas SECURITYPOLICY
    
    # Обновляем политику
    gpupdate /force | Out-Null
    
    Write-Host "Политика безопасности успешно применена!" -ForegroundColor Green
    Write-Host "Новые параметры:"
    Write-Host "----------------------------------------"
    Write-Host "Минимальная длина пароля: 12 символов"
    Write-Host "Максимальный срок пароля: 90 дней"
    Write-Host "Хранение истории паролей: 5"
    Write-Host "Сложность пароля: включена"
    Write-Host "Блокировка после 5 неудачных попыток"
    Write-Host "Сброс счетчика блокировки: через 15 минут"
    Write-Host "Длительность блокировки: 30 минут"
}
catch {
    Write-Host "Ошибка при применении политики: $_" -ForegroundColor Red
}
finally {
    # Удаляем временные файлы
    if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
    if (Test-Path $dbPath) { Remove-Item $dbPath -Force }
}

# Принудительная смена пароля для всех пользователей
Get-LocalUser | ForEach-Object {
    if ($_.PasswordExpires -eq $null) {
        Set-LocalUser -Name $_.Name -PasswordNeverExpires $false
    }
}