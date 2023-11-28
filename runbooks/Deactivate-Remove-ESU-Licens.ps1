###############
# DESCRIPTION #
###############



# Prerequisites: 
#  1) Automation Account must have a system-managed identity
#  2) System-managed identity must be Contributor on VM's subscriptions scopes


#################
# CONFIGURATION #
#################



##########
# SCRIPT #
##########

Import-Module Az.ResourceGraph

# Connect to Azure with Automation Account system-assigned managed identity
Disable-AzContextAutosave -Scope Process
$AzureContext = (Connect-AzAccount -Identity -WarningAction Ignore).context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext

# Get current automation account
$automationAccountsQuery = @{
    Query = "resources
| where type == 'microsoft.automation/automationaccounts'"
}
$automationAccounts = Search-AzGraph @automationAccountsQuery

foreach ($automationAccount in $automationAccounts)
{
    Select-AzSubscription -SubscriptionId $automationAccount.subscriptionId
    $Job = Get-AzAutomationJob -ResourceGroupName $automationAccount.resourceGroup -AutomationAccountName $automationAccount.name -Id $PSPrivateMetadata.JobId.Guid -ErrorAction SilentlyContinue
    if (!([string]::IsNullOrEmpty($Job)))
    {
        $automationAccountSubscriptionId = $automationAccount.subscriptionId
        $automationAccountRg = $Job.ResourceGroupName
        $automationAccountName = $Job.AutomationAccountName
        break;
    }
}


# Setting variabels

$subId = $automationAccount.subscriptionId

$ArcLicensesQuery = "Resources | where type == 'microsoft.hybridcompute/licenses' | extend licenseId = tolower(tostring(id)) | where subscriptionId == '$subId'"
$ArcLicensesQueryResponse = Search-AzGraph -Query $ArcLicensesQuery

$ArcLicensesProfileQuery = "Resources | where type =~ 'microsoft.hybridcompute/machines/licenseProfiles' | extend machineId = tolower(tostring(id)) | extend licenseId = tolower(tostring(properties.esuProfile.assignedLicense)) | where subscriptionId == '$subId'"
$ArcLicensesProfileQueryResponse = Search-AzGraph -Query $ArcLicensesProfileQuery

foreach ($ArcLicenses in $ArcLicensesQueryResponse) {
    $licensesId = $ArcLicenses.licenseId
    $ArcLicensesFound = 'false'

    foreach ($ArcLicensesProfile in $ArcLicensesProfileQueryResponse){
        Write-Output "Profileid: "$ArcLicensesProfile.licenseId
        if ($ArcLicensesProfile.licenseId -eq $licensesId) { $ArcLicensesFound = 'true' } 
    }


    if ($ArcLicensesFound -ne 'true') {
    
        Write-Output "Deactivate: "$licensesId
        $location = $ArcLicensesProfile.location
        Write-Output $location
        # Remove ESU licenses
        $RemoveresId = $licensesId
        $RemoveresourceIdPath = "${RemoveresId}?api-version=2023-06-20-preview"
        $RemoveLicensReq = Invoke-AzRestMethod -path $RemoveresourceIdPath -Method Delete
        Write-Output "Removestatuscode "$RemoveLicensReq
        # Deactivate ESU licenses not inuse for reference
        <#
        $DeactivateLicensPayload = @{ 
            location = $location
            properties= @{ 
                licenseDetails= @{ 
                state= 'Deactivated'
                }         
            } 
        } 
        $DeactivateresId = $licensesId
        $DeactivateresourceIdPath = "${DeactivateresId}?api-version=2023-06-20-preview"
        $DeactivateLicensReq = Invoke-AzRestMethod -path $DeactivateresourceIdPath -Method Patch -payload (ConvertTo-Json -Depth 100 $DeactivateLicensPayload)
        Write-Output "Deactivate statuscode "$DeactivateLicensReq
        #>
    }



}



Write-Output "Done"
