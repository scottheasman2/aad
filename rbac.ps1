# Get the start time
$startTime = Get-Date

Connect-AzAccount

$subscriptions = $null
$subscription = $null
$roleAssignments = $null
$managementGroup = $null
$managementGroups = $null
$resourceGroups = $null

$subscriptions = Get-AzSubscription | Where-Object { $_.Name -notlike '*Access to Azure Active Directory*' -and $_.Name -notlike '*sub-swx*' }
$managementGroups = Get-AzManagementGroup

$subscriptionCount = $subscriptions.Count
$subscriptionIndex = 0

$managementGroupCount = $managementGroups.Count
$managementGroupIndex = 0

$totalCount = $subscriptionCount + $managementGroupCount
$totalIndex = 0

$roleAssignments = foreach ($subscription in $subscriptions) {
    $subscriptionIndex++
    $totalIndex++
    Write-Progress -Id 1 -Activity "Overall Progress" -Status "Processing Subscriptions and Management Groups ($totalIndex/$totalCount)" -PercentComplete (($totalIndex / $totalCount) * 100)
    Write-Progress -Id 2 -Activity "Processing Subscriptions" -Status "Processing $($subscription.Name) ($subscriptionIndex/$subscriptionCount)" -PercentComplete (($subscriptionIndex / $subscriptionCount) * 100)
    Set-AzContext -Subscription $subscription | Out-Null
    Get-AzRoleAssignment | Select-Object DisplayName, SignInName, RoleDefinitionName, ObjectType, @{Name='SubscriptionName';Expression={$subscription.Name}}, @{Name='Management Group Name';Expression={'N/A'}},@{Name='Inherited';Expression={
        if ($_.Scope -eq "/") {"Root Inherited"}
        elseif ($_.Scope.StartsWith("/subscriptions/")) {"This Resource"}
        elseif ($_.Scope.StartsWith("/providers/Microsoft.Management/")) {$_.Scope.Split("/")[-1]}
        else {"Unknown"}
    }}, @{Name='Date';Expression={$currentDate}}
    
    $resourceGroups = Get-AzResourceGroup
    $resourceGroupCount = $resourceGroups.Count
    $resourceGroupIndex = 0
    foreach ($resourceGroup in $resourceGroups) {
        $resourceGroupIndex++
        Write-Progress -Id 3 -Activity "Processing Resource Groups in $($subscription.Name)" -Status "Processing $($resourceGroup.ResourceGroupName) ($resourceGroupIndex/$resourceGroupCount)" -PercentComplete (($resourceGroupIndex / $resourceGroupCount) * 100)
        Get-AzRoleAssignment -Scope $resourceGroup.ResourceId | Select-Object DisplayName, SignInName, RoleDefinitionName, ObjectType, @{Name='SubscriptionName';Expression={$subscription.Name}}, @{Name='ResourceGroupName';Expression={$resourceGroup.ResourceGroupName}}, @{Name='Inherited';Expression={
            if ($_.Scope -eq "/") {"Root Inherited"}
            elseif ($_.Scope.StartsWith("/subscriptions/")) {"This Resource"}
            elseif ($_.Scope.StartsWith("/providers/Microsoft.Management/")) {$_.Scope.Split("/")[-1]}
            else {"Unknown"}
        }}, @{Name='Date';Expression={$currentDate}}
    }
}

$roleAssignments += foreach ($managementGroup in $managementGroups) {
    $managementGroupIndex++
    $totalIndex++
    Write-Progress -Id 1 -Activity "Overall Progress" -Status "Processing Subscriptions and Management Groups ($totalIndex/$totalCount)" -PercentComplete (($totalIndex / $totalCount) * 100)
    Write-Progress -Id 4 -Activity "Processing Management Groups" -Status "Processing $($managementGroup.DisplayName) ($managementGroupIndex/$managementGroupCount)" -PercentComplete (($managementGroupIndex / $managementGroupCount) * 100)
    Set-AzContext -TenantId $managementGroup.TenantId | Out-Null
    Get-AzRoleAssignment -Scope $managementGroup.Id | Select-Object ID, DisplayName, SignInName, Name, RoleDefinitionName, ObjectType, @{Name='SubscriptionName';Expression={'N/A'}}, @{Name='Management Group Name';Expression={$ManagementGroup.DisplayName}}, @{Name='Inherited';Expression={
        if ($_.Scope -eq "/") {"Root Inherited"}
        elseif ($_.Scope.StartsWith($managementGroup.Id)) {"This Resource"}
        elseif ($_.Scope.StartsWith("/providers/Microsoft.Management/")) {$_.Scope.Split("/")[-1]}
        else {"Unknown"}
    }}, @{Name='ManagementGroupName';Expression={$managementGroup.DisplayName}}, @{Name='Date';Expression={$currentDate}}
}

$roleassignments | Export-Excel -Path "C:\Devops\powershell-scripts\Azure\RBAC\Test\RbacPerms-$((Get-Date).ToString('MM-dd-yyyy')).xlsx" -WorksheetName "rbac" -TableStyle "Medium2"
Copy-Item -Path "C:\Devops\powershell-scripts\Azure\RBAC\Test\RbacPerms-$((Get-Date).ToString('MM-dd-yyyy')).xlsx" -Destination "C:\Devops\powershell-scripts\Azure\RBAC\Test\RbacPerms.xlsx"

# Calculate the elapsed time
$endTime = Get-Date
$elapsedTime = $endTime - $startTime

Write-Host "Total time elapsed: $elapsedTime"
