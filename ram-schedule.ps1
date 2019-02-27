#The following command creates a job trigger that runs a scheduled job once every 12 hours for an indefinite period of time. 
$triggerram = New-JobTrigger -Once -At "2/22/2019 11:20AM" -RepetitionInterval (New-TimeSpan -Hours 12) -RepetitionDuration ([timespan]::MaxValue)
Register-ScheduledJob -Name ramchk -Trigger $triggerram -FilePath C:\scripts\ram-check.ps1
#Unregister-ScheduledJob ramchk
#Receive-Job ramchk
