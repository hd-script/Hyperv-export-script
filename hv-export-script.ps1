Get-Date
$start=Get-Date
$passwd = 'YOURPASSWORD'
net use * /delete /y
net use W: \\BACKUPSERVERIP\c$\winhv1 /user:administrator $passwd /Persistent:Yes /Y
$failcount = 0
$NetworkSharePath = "\\BACKUPSERVERIP\c$\winhv1"
$ExportPath = "D:\backup"
$limit =  (Get-Date).AddDays(-15) # backups older than 15 days will be deleted
$BackupServerName = "BACKUPSERVERNAME" 
. C:\scripts\email-rep.ps1

$tblname=get-date -Format M
$tblname = $tblname -replace '\s',''
$tblname +="hv1"

#Folder name creation in backup server
New-Item -Path W:\$tblname -ItemType directory

#database creation 
$sqlConnection = new-object System.Data.SqlClient.SqlConnection “server=DBSERVERIP;database=dbname;Integrated Security=false;User ID = dbuser; Password = DBPASSWORD”
$sqlConnection.Open()
$sqlCommand = $sqlConnection.CreateCommand()
$sqlCommand.CommandText = “create table dbo.$tblname(VMName varchar(100),starttm varchar(70),endtm varchar(70),Exporttm varchar(30),exportsz varchar(30),rexportsz varchar(30),compare varchar(20),totaltm varchar(30));”
$sqlReader = $sqlCommand.ExecuteReader()
$sqlConnection.Close()

#getting the list of VMs that are running
$list = (Get-VM |where {$_.state -eq 'Running'} | Select Name -ExpandProperty Name)


foreach ($i in $list)
{
    Write-Host " Exporting $i "
    $sqlConnection.Open()
    $vmts = Get-Date
    $path = "$ExportPath\$i"
    $networkpath = "$NetworkSharePath\$tblname\$i"
    if(!(Test-Path $path))
    {
        Export-VM -Name $i -Path  $ExportPath
        $vmte = Get-Date
        $vmexe = New-TimeSpan -Start $vmts -End $vmte
        Write-Output "Export time of VM $i is $($vmexe.Days) Days: $($vmexe.Hours) Hrs: $($vmexe.Minutes) Min: $($vmexe.Seconds) Sec"
        $exporttm = "$($vmexe.Days) Days $($vmexe.Hours) Hrs: $($vmexe.Minutes) Min: $($vmexe.Seconds) Sec"
        Get-ChildItem $ExportPath -Directory <#norecurse#> | foreach {
            $directoryName = $_.Name
            $lfoldersz = (Get-ChildItem "$ExportPath\$directoryName" -recurse | Measure-Object -property length -sum)
            $localsz = $lfoldersz.sum
            $lfoldersz = "{0:N2}" -f ($lfoldersz.sum / 1GB)
            $lfoldersz = [math]::Round($lfoldersz)
            Write-Host " Local backup size is $lfoldersz GB"
            $RemoteDriveSize = Get-PSDrive W
            $RemoteDriveSize = $RemoteDriveSize.Free
            $RemoteDriveSize = "{0:N2}" -f ($RemoteDriveSize / 1GB)
            $RemoteDriveSizer = [math]::Round($RemoteDriveSize)
            Write-Host " remote disk space is $RemoteDriveSize gb"
            if($RemoteDriveSizer -le $lfoldersz)
            {
                $Neededspace = $lfoldersz - $RemoteDriveSize
                Write-Host " needed space $Neededspace "
                $msg.Subject = "Backup Warning: $env:COMPUTERNAME Backup drive Full" #getting Computer name
                $msg.Body = "Hello, `nPlease free-up $Neededspace GB in $BackupServerName to continue the backup process of $directoryName VM"
                $smtp.Send($msg) 
                #Read-Host "Press Enter"
                Start-Sleep -Seconds 1800
                Copy-Item $ExportPath\$directoryName $NetworkSharePath\$tblname 
                
            }
            Elseif(!(Test-Path $networkpath))
            {
                Write-Host "Begining file transfer of $i VM to backup server"
                Get-Date            
                Copy-Item $ExportPath\$i $NetworkSharePath\$tblname -Recurse
            }
            else { Write-Host " VM $i already exist in $networkpath" -ForegroundColor Green }
            Write-Host "$i VM copied successfully"
            $rfoldersz = (Get-ChildItem $NetworkSharePath\$tblname\$directoryName -recurse | Measure-Object -property length -sum)
            $remotesz = $rfoldersz.sum
            $rfoldersz = "{0:N2}" -f ($rfoldersz.sum / 1GB) + " GB"
            $lfoldersz = "{0:N2}" -f ($localsz / 1GB) + " GB"
            #Write-Host "Remote backup size $rfoldersz " 
        }
        if($localsz -eq $remotesz)
        {
            $res = "TRUE"
            Write-Output " The VM $directoryName is equal in source and destination."
            Write-Output " Removing export backup... "
            Remove-Item $ExportPath\$directoryName -Recurse
            
        }
        else
        {
            $res = "FALSE"
            $failcount++
            $msg.Subject = "Backup Error: $env:COMPUTERNAME" #getting Computer name
            $msg.Body = "Hello, `nThe VM $directoryName is not equal in source and destination."
            $smtp.Send($msg) 
            Write-Host " The VM $directoryName is not equal in source and destination." -BackgroundColor Red
            Write-Output " Removing export backup... "
            Remove-Item $ExportPath\$directoryName -Recurse
            
        }
        $sqlCommand.CommandText = "INSERT INTO dbo.$tblname(VMName,starttm,endtm,Exporttm,exportsz,rexportsz,compare) VALUES ('$directoryName','$vmts','$vmte','$exporttm','$lfoldersz','$rfoldersz','$res')"
        $sqlReader = $sqlCommand.ExecuteReader()
        
    }
    else
    {
        Write-host " VM $i already exist in local backup folder" -foregroundcolor "Yellow"
        if(!(Test-Path $networkpath))
        {
            Copy-Item $ExportPath\$directoryName $NetworkSharePath\$tblname -Recurse
        } 
        Remove-Item $ExportPath\$directoryName -Recurse
    }
    $sqlConnection.Close()
}

Get-Date

$end = Get-Date
$exectime = New-TimeSpan -Start $start -End $end
Write-Output "Script execution time is: $($exectime.Days) Days: $($exectime.Hours) Hrs: $($exectime.Minutes) Min: $($exectime.Seconds) Sec"
$totaltm = "$($exectime.Days) Days: $($exectime.Hours) Hrs: $($exectime.Minutes) Min: $($exectime.Seconds) Sec"
$sqlConnection.Open()
$sqlCommand = $sqlConnection.CreateCommand()
$sqlCommand.CommandText += "INSERT INTO dbo.$tblname(totaltm) VALUES ('$totaltm')"
$sqlReader = $sqlCommand.ExecuteReader()
$sqlConnection.Close()
if($failcount -eq 0)
{
    $msg.Subject = "Backup Notification: $env:COMPUTERNAME" #getting Computer name
    $msg.Body = "Hello, `n$env:COMPUTERNAME server backup completed Successfully."
    $smtp.Send($msg) 
    get-childitem -Path $NetworkSharePath -Recurse -Force |? {$_.psiscontainer -and $_.lastwritetime -le $limit } | Remove-Item -Force -Recurse
}
else
{
    $msg.Subject = "Backup Error: $env:COMPUTERNAME" #getting Computer name
    $msg.Body = "Hello, `n$env:COMPUTERNAME server backup completed with error."
    $smtp.Send($msg) 
    Write-Host "Backup completed with error" -ForegroundColor Black -BackgroundColor Red
}
$failcount = 0
Remove-PSDrive W
Write-Output "-----------------------------------------------------------------------"