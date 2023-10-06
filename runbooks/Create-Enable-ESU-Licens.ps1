###############
# DESCRIPTION #
###############

# This script searchs VMs with key tag "POLICY_UPDATE"
# If a VM has a "POLICY_UPDATE" key tag, an update deployment will be created on the current automation account.
# The VM will be patched weekly based on its "POLICY_UPDATE" tag value

# Syntax of "POLICY_UPDATE" key tag:
# DaysOfWeek;startTime;rebootPolicy;excludedPackages;reportingMail

# Example #1 - POLICY_UPDATE: Sunday;05h20 PM;Always;*java*,*nagios*;
# Example #2 - POLICY_UPDATE: Friday;07h00 PM;IfRequired;;TeamA@abc.com

# rebootPolicy possible values: Always, Never, IfRequired
# excludedPackages: optional parameter, comma separated if multiple.
# reportingMail: optional parameter

# Prerequisites: 
#  1) Automation Account must have a system-managed identity
#  2) System-managed identity must be Contributor on VM's subscriptions scopes
#  3) Virtual Machines must be connected to Log Analytics Workspace linked to the Automation Account. 

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
$resourceGroupName = "Arc-box"
$vmname = "ArcBoxWin2k12"
#$location = (Get-AzConnectedMachine -name ArcboxWin2k12 -ResourceGroupName $resourceGroupName).Location

$ArcVMQuery = "Resources | where type == 'microsoft.hybridcompute/machines' | where subscriptionId == '$subId' | extend cpu=tostring(properties.detectedProperties.processorCount), edition=tostring(properties.licenseProfile.esuProfile.serverType), osSku=tostring(properties.osSku)| where osSku contains 'Windows Server 2012' | project name, cpu, edition, osSku, location"
$ArcVMQueryResponse = Search-AzGraph -query $ArcVMQuery
foreach ($ArcVm in $ArcVMQueryResponse) {
    $vmname = $ArcVm.name
    $ArcVmCpu = $ArcVm.cpu
    if ($ArcVmCpu -lt 8 -and $ArcVM.edition -eq 'Datacenter') {$ArcVmCpu = 8}

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
  
    echo "Provisiong statuscode "$ProvisionLicensReq.StatusCode


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
    echo "Link statuscode "$LinkLicensReq.StatusCode

}



Write-Output "Done"
