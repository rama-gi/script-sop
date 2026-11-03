$DateTime=$($(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
$OutputFileName = "SnapshotCreationReport_$DateTime.csv"
$FirstLine = "SUBSCRIPTION,RESOURCE GROUP,VM,SNAPSHOTNAME,STATUS"
$FirstLine | Out-File -FilePath $OutputFileName -Encoding UTF8
 
function Update-Output {
    param ([string]$message)
    $Default = "$SubscriptionName,$ResourceGroup,$VMName,$SnapshotName"
    $Output = "$Default,$message"
    Add-Content -Path $OutputFileName -Value $Output
}
 
$csvPath = "servers_list-20261025.csv"
$SubscriptionNames = Import-Csv -Path $csvPath | ForEach-Object { $_.SUBSCRIPTION }
$ResourceGroups = Import-Csv -Path $csvPath | ForEach-Object { $_."RESOURCE GROUP" }
$VMs = Import-Csv -Path $csvPath | ForEach-Object { $_.NAME }
 
for ( $i = 0; $i -lt $VMs.Length; $i++) {
$CurrentSub = (Get-AzContext).Subscription.Name
$Subscription = $($SubscriptionNames[$i])
$ResourceGroup = $($ResourceGroups[$i])
$VMName = $($VMs[$i])
 
if ($CurrentSub -ne $Subscription){Set-AzContext -SubscriptionName $Subscription | Out-Null}
$SubscriptionName = (Get-AzContext).Subscription.Name
 
# Get VM
$vm = Get-AzVM -ResourceGroupName $ResourceGroup -Name $VMName
if ($vm){
    Write-Host "VM $VMName found, Getting ready to create Snapshot !"
    # Get OS Disk ID
    $osDiskId = $vm.StorageProfile.OsDisk.ManagedDisk.Id
    $osDiskName = $vm.StorageProfile.OsDisk.Name
    $SnapshotName = "$($osDiskName)_snapshot_$($DateTime)"
 
    # Create snapshot configuration
    $snapshotConfig = New-AzSnapshotConfig -Location $vm.Location -SourceUri $osDiskId -CreateOption Copy
 
    # Create the snapshot
    try{
    New-AzSnapshot -ResourceGroupName $ResourceGroup -SnapshotName $SnapshotName -Snapshot $snapshotConfig -ErrorAction stop
    Update-Output "CREATED"
    }
    Catch{
        Update-Output "FAILED, $_"
    }
}else{$SnapshotName="SNAPSHOTNOTCREATED";Update-Ouput "VMNOTFOUND"}
}