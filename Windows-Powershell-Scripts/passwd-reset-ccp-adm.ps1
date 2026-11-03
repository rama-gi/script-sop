$InventoryFile = ".\AzureVirtualMachines.csv"
$ResetListFile = ".\VMResetList.csv"

$VMUser = "ccp-adm"
$VMPassword = "Linuxinstall@123"

Write-Host "Logging into Azure..." -ForegroundColor Cyan

az login

if ($LASTEXITCODE -ne 0)
{
    Write-Host "Azure Login Failed." -ForegroundColor Red
    exit
}

$Inventory = Import-Csv $InventoryFile
$ResetVMs  = Import-Csv $ResetListFile

$SuccessVMs = @()
$FailedVMs = @()

foreach ($Item in $ResetVMs)
{
    $VM = $Item.VMNAME.Trim()

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "Processing VM : $VM"
    Write-Host "========================================" -ForegroundColor Yellow

    $VMInfo = $Inventory | Where-Object {
        $_.NAME.Trim().ToUpper() -eq $VM.ToUpper()
    } | Select-Object -First 1

    if (!$VMInfo)
    {
        Write-Host "$VM not found in AzureVirtualMachines.csv" -ForegroundColor Red

        $FailedVMs += [PSCustomObject]@{
            VMName = $VM
            Status = "VM Not Found"
        }

        continue
    }

    $Subscription = $VMInfo.SUBSCRIPTION
    $RG = $VMInfo.'RESOURCE GROUP'

    Write-Host "Subscription : $Subscription"
    Write-Host "Resource Group : $RG"

    az account set --subscription "$Subscription"

    if ($LASTEXITCODE -ne 0)
    {
        Write-Host "Unable to switch subscription" -ForegroundColor Red

        $FailedVMs += [PSCustomObject]@{
            VMName = $VM
            Status = "Subscription Error"
        }

        continue
    }

    az vm user update `
        --resource-group "$RG" `
        --name "$VM" `
        --username "$VMUser" `
        --password "$VMPassword"

    if ($LASTEXITCODE -eq 0)
    {
        Write-Host "SUCCESS - Password reset completed" -ForegroundColor Green

        $SuccessVMs += [PSCustomObject]@{
            VMName = $VM
            Status = "Success"
        }
    }
    else
    {
        Write-Host "FAILED - Password reset failed" -ForegroundColor Red

        $FailedVMs += [PSCustomObject]@{
            VMName = $VM
            Status = "Failed"
        }
    }
}

Write-Host ""
Write-Host "========================================="
Write-Host "PASSWORD RESET SUMMARY"
Write-Host "========================================="

Write-Host ""
Write-Host "SUCCESSFUL SERVERS ($($SuccessVMs.Count))" -ForegroundColor Green
$SuccessVMs | Format-Table

Write-Host ""
Write-Host "FAILED SERVERS ($($FailedVMs.Count))" -ForegroundColor Red
$FailedVMs | Format-Table

