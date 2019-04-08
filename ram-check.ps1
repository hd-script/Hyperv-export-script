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
    unregister-ScheduledJob ramchk #removes the schedule check and postpond it run after 7 days
    $startdt = (Get-Date).AddDays(7)
    $triggerram = New-JobTrigger -Once -At $startdt -RepetitionInterval (New-TimeSpan -Hours 12) -RepetitionDuration ([timespan]::MaxValue)
    Register-ScheduledJob -Name ramchk -Trigger $triggerram -FilePath C:\scripts\ram-new.ps1
    $msg.Subject = "RAM Warning: $env:COMPUTERNAME" #getting Computer name
    $msg.Body = "Hello, `nThe server $env:COMPUTERNAME is running out of RAM. Available RAM is $freePhysicalMem GB."
    $smtp.Send($msg) 
}
else { Write-Host "no worries. $freePhysicalMem GB free." }
