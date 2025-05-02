# Замените "Username" на имя нужного пользователя
$user = "Username"
$exeFiles = @("C:\Windows\System32\cmd.exe", "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe")

foreach ($file in $exeFiles) {
    $acl = Get-ACL $file
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($user, "ExecuteFile", "Deny")
    $acl.AddAccessRule($rule)
    Set-ACL -Path $file -AclObject $acl
}