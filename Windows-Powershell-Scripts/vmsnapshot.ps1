# vCenter Details
$vCenter = "vc.0fbf0a6056b1420aba757d.eastus.avs.azure.com"

# Files
$ServerList = ".\servers.csv"
$ReportFile = ".\AVS_snapshot_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

# Snapshot Details
$SnapshotName = "PrePatch_$(Get-Date -Format 'yyyyMMdd_HHmm')"
$SnapshotDescription = "Automatic snapshot before patching"

Write-Host "Connecting to vCenter..." -ForegroundColor Cyan

$Credential = Get-Credential
Connect-VIServer -Server $vCenter -Credential $Credential -ErrorAction Stop

$Results = @()

$VMs = Import-Csv $ServerList

foreach ($Entry in $VMs)
{
    $VMName = $Entry.VMName

    Write-Host "Processing VM: $VMName" -ForegroundColor Yellow

    try
    {
        $VM = Get-VM -Name $VMName -ErrorAction Stop

        # Check for existing snapshot
        $ExistingSnapshot = Get-Snapshot -VM $VM -ErrorAction SilentlyContinue

        if ($ExistingSnapshot)
        {
            $Results += [PSCustomObject]@{
                VMName          = $VMName
                VMSizeGB        = ""
                Datastore       = ""
                FreeSpaceGB     = ""
                RequiredSpaceGB = ""
                Status          = "Skipped - Snapshot Exists"
            }

            Write-Host "$VMName already has snapshot(s). Skipping." -ForegroundColor Magenta
            continue
        }

        # Get datastore
        $Datastore = $VM | Get-Datastore | Select-Object -First 1

        if (-not $Datastore)
        {
            throw "No datastore found for VM."
        }

        # Simple numeric values
        $VMSizeGB = [decimal]$VM.ProvisionedSpaceGB
        $FreeSpaceGB = [decimal]$Datastore.FreeSpaceGB
        $RequiredSpaceGB = $VMSizeGB * 3

        Write-Host "VM Size      : $VMSizeGB GB"
        Write-Host "Datastore    : $($Datastore.Name)"
        Write-Host "Free Space   : $FreeSpaceGB GB"
        Write-Host "Required     : $RequiredSpaceGB GB"

        if ($FreeSpaceGB -ge $RequiredSpaceGB)
        {
            Write-Host "$VMName - Creating Snapshot" -ForegroundColor Green

            New-Snapshot `
                -VM $VM `
                -Name $SnapshotName `
                -Description $SnapshotDescription `
                -Memory:$false `
                -Quiesce:$false `
                -Confirm:$false `
                -ErrorAction Stop | Out-Null

            $Status = "Snapshot Created"
        }
        else
        {
            Write-Host "$VMName - Insufficient datastore space" -ForegroundColor Red
            $Status = "Skipped - Insufficient Space"
        }

        $Results += [PSCustomObject]@{
            VMName          = $VMName
            VMSizeGB        = $VMSizeGB
            Datastore       = $Datastore.Name
            FreeSpaceGB     = $FreeSpaceGB
            RequiredSpaceGB = $RequiredSpaceGB
            Status          = $Status
        }
    }
    catch
    {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red

        $Results += [PSCustomObject]@{
            VMName          = $VMName
            VMSizeGB        = ""
            Datastore       = ""
            FreeSpaceGB     = ""
            RequiredSpaceGB = ""
            Status          = "Failed - $($_.Exception.Message)"
        }
    }
}

$Results | Export-Csv $ReportFile -NoTypeInformation

Disconnect-VIServer -Confirm:$false

Write-Host ""
Write-Host "Completed." -ForegroundColor Green
Write-Host "Report: $ReportFile"