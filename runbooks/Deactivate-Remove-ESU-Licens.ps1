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

$ArcVMQuery = "Resources | where type == 'microsoft.hybridcompute/machines' | where subscriptionId == '$subId' | extend cpu=tostring(properties.detectedProperties.processorCount), edition=tostring(properties.licenseProfile.esuProfile.serverType), osSku=tostring(properties.osSku), licenseAssignmentState=tostring(properties.licenseProfile.esuProfile.licenseAssignmentState)| where osSku contains 'Windows Server 2012' | where licenseAssignmentState contains 'NotAssigned' | project name, cpu, edition, osSku, location, resourceGroup, licenseAssignmentState"

$ArcVMQueryResponse = Search-AzGraph -Query $ArcVMQuery


foreach ($ArcVm in $ArcVMQueryResponse) {
    $vmname = $ArcVm.name
    $location = $ArcVm.location
    $resourceGroupName = $ArcVm.resourceGroup
    Write-Output "Onboarding: "$ArcVm.name", "$ArcVm.ResourceGroup", "$location", "$subId

    $ArcVmCpu = $ArcVm.cpu
    if ($ArcVmCpu -lt 8 -and $ArcVM.edition -eq 'Standard') {$ArcVmCpu = 8}

    # Privision ESU licenses
    $ProvisionLicensPayload = @{ 
        location = $location
        properties= @{ 
            licenseDetails= @{ 
            state= 'Activated'
            target= 'Windows Server 2012 R2'
            Edition= $ArcVM.edition
            Type= 'vCore'
            Processors= $ArcVmCpu
            }         
        } 
    } 
    $ProvisionresId = "/subscriptions/$subId/resourceGroups/$resourceGroupName/providers/Microsoft.HybridCompute/licenses/"
    $ProvisionresourceIdPath = "${ProvisionresId}${vmname}?api-version=2023-06-20-preview"
   
    $ProvisionLicensReq = Invoke-AzRestMethod -path $ProvisionresourceIdPath -Method Put -payload (ConvertTo-Json -Depth 100 $ProvisionLicensPayload)
  
    Write-Output "Provisiong statuscode "$ProvisionLicensReq


    # Linking ESU Lisens to Arc Server
    $ProvisionLicensObj = ($ProvisionLicensReq.Content) | ConvertFrom-Json

    $LinkLicensPayload = @{ 
        location = $location
        properties= @{ 
            esuProfile= @{ 
                assignedLicense= $ProvisionLicensObj.Id
            }         
        } 
    } 



    $LinkresId = "/subscriptions/$subId/resourceGroups/$resourceGroupName/providers/Microsoft.HybridCompute/machines/"
    $LinkresourceIdPath = "${LinkresId}${vmname}/licenseProfiles/default?api-version=2023-06-20-preview"

    $LinkLicensReq = Invoke-AzRestMethod -path $LinkresourceIdPath -Method Put -payload (ConvertTo-Json -Depth 100 $LinkLicensPayload)
    Write-Output "Link statuscode "$LinkLicensReq

}



Write-Output "Done"
