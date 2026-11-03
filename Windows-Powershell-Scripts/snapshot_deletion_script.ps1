$OutputFileName = "SnapshotDeletionReport_$($(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')).csv"
$FirstLine = "SUBSCRIPTION,RESOURCE GROUP,SNAPSHOTNAME,STATUS"
$FirstLine | Out-File -FilePath $OutputFileName -Encoding UTF8
 
function Update-Output {
    param ([string]$message)
    $Default = "$SubscriptionName,$ResourceGroup,$SnapshotName"
    $Output = "$Default,$message"
    Add-Content -Path $OutputFileName -Value $Output
}
 
$csvPath = "SnapshotCreationReport_20260909T045508Z.csv"
$SubscriptionNames = Import-Csv -Path $csvPath | ForEach-Object { $_.SUBSCRIPTION }
$ResourceGroups = Import-Csv -Path $csvPath | ForEach-Object { $_."RESOURCE GROUP" }
$SnapshotNames = Import-Csv -Path $csvPath | ForEach-Object { $_.SNAPSHOTNAME }
 
for ( $i = 0; $i -lt $SnapshotNames.Length; $i++) {
$CurrentSub = (Get-AzContext).Subscription.Name
$Subscription = $($SubscriptionNames[$i])
$ResourceGroup = $($ResourceGroups[$i])
$SnapshotName = $($SnapshotNames[$i])
 
if ($CurrentSub -ne $Subscription){Set-AzContext -SubscriptionId $Subscription | Out-Null}
$SubscriptionName = (Get-AzContext).Subscription.Name
$Snapshot = Get-AzSnapshot -ResourceGroupName $ResourceGroup -SnapshotName $SnapshotName
if ($Snapshot){
    try{
        Remove-AzSnapshot -ResourceGroupName $ResourceGroup -SnapshotName $SnapshotName -Force -ErrorAction stop
        Update-Output "DELETED"
    }
    catch{
        Update-Ouput "ERROR $_"
    }
}else {Update-output "SNAPSHOTNOTFOUND $SnapshotName"}
}