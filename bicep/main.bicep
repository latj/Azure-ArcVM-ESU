// This script is given for testing purpose
//
// For a given RG, it will
//  - Deploy an Automation account using a System-assigned Managed Identity
//  - Give Contributor role to System-assigned Managed Identity to the RG 
//  - Deploy Runbooks to Automation Account

//
// Example of execution:
// az deployment group create --resource-group MyRg --template-file main.bicep

// Location
param Location string = 'West Europe'



param AutomationAccountName string = 'aa-ESU-automation'


resource AutomationAccount 'Microsoft.Automation/automationAccounts@2020-01-13-preview' = {
  name: AutomationAccountName
  location: Location
  identity: {
    type: 'SystemAssigned'
  }
  properties:{
    sku: {
      name: 'Basic'
    }
  }
}


resource Az_ResourceGraph 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  name: '${AutomationAccountName}/Az.ResourceGraph'
  dependsOn: [
    AutomationAccount
  ]
  properties: {
    contentLink: {
      uri: 'https://www.powershellgallery.com/api/v2/package/Az.ResourceGraph/0.11.0'
      version: '0.11.0'
    }
  }
}


resource Runbook_Create_Enable_ESU_Licens 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  name: '${AutomationAccount.name}/Create-Enable-ESU-Licens'
  location: Location
  properties:{
    runbookType: 'PowerShell'
    logProgress: false
    logVerbose: false
    logActivityTrace: 0
    publishContentLink: {
      uri: 'https://raw.githubusercontent.com/latj/Azure-ArcVM-ESU/main/runbooks/Create-Enable-ESU-Licens.ps1'      
    }
  }
}

resource Runbook_Deactivate_Remove_ESU_licens 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  name: '${AutomationAccount.name}/Deactivate-Remove-ESU-licens'
  location: Location
  properties:{
    runbookType: 'PowerShell'
    logProgress: false
    logVerbose: false
    logActivityTrace: 0
    publishContentLink: {
      uri: 'https://raw.githubusercontent.com/latj/Azure-ArcVM-ESU/main/runbooks/Deactivate-Remove-ESU-Licens.ps1'        
    }
  }
}


resource DailySchedule 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = {
  name: '${AutomationAccount.name}/Schedules-Create-Enable-ESU-Licens'
  properties:{
    description: 'Schedule daily'
    startTime: ''
    frequency: 'Day'
    interval: 1
  }
}

param Sched1Guid string = newGuid()
resource ScheduleRunbook_Create_Enable_ESU_Licens 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  name: '${AutomationAccount.name}/${Sched1Guid}'
  properties:{
    schedule:{
      name: split(DailySchedule.name, '/')[1]
    }
    runbook:{
      name: split(Runbook_Create_Enable_ESU_Licens.name, '/')[1]
    }
  }
}

param Sched2Guid string = newGuid()
resource ScheduleRunbook_Runbook_Deactivate_Remove_ESU_licens 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  name: '${AutomationAccount.name}/${Sched2Guid}'
  properties:{
    schedule:{
      name: split(DailySchedule.name, '/')[1]
    }
    runbook:{
      name: split(Runbook_Deactivate_Remove_ESU_licens.name, '/')[1]
    }
  }
}






