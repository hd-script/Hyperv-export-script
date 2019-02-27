. C:\scripts\ram-email.ps1
$system = Get-WmiObject win32_OperatingSystem
$totalPhysicalMem = $system.TotalVisibleMemorySize
$totalPhysicalMem /= 1048576
#Write-Host $totalPhysicalMem
$freePhysicalMem = $system.FreePhysicalMemory
$freePhysicalMem /= 1048576
$requiredFree = 32 # Minimum RAM set to 32GB
if($freePhysicalMem -lt $requiredFree)
{
    Write-Host "Out of ram"
    $msg.Subject = "RAM Warning: $env:COMPUTERNAME" #getting Computer name
    $msg.Body = "Hello, `nThe server $env:COMPUTERNAME is running out of RAM. Available RAM is $freePhysicalMem GB."
    $smtp.Send($msg) 
}
else { Write-Host "no worries. $freePhysicalMem GB free." }
