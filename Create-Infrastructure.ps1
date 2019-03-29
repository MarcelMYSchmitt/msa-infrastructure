#Requires -Version 3.0

Param(
    [Parameter(Mandatory=$True)]
    [string]
    $FileName

    #[Parameter()]
    #[string]
    #$HasThumbPrint
)

#stop the script on first error
$ErrorActionPreference = 'Stop'

#******************************************************************************
#dependencies
#******************************************************************************


. "$PSScriptRoot/Common-Functions.ps1"


#******************************************************************************
#test passing variables from json to script
#******************************************************************************


$Configuration = Get-Content -Raw -Path "$PSScriptRoot/environments/$FileName.json" | ConvertFrom-Json

$CompanyTag = $Configuration.CompanyTag
$LocationTag = $Configuration.LocationTag
$EnvironmentTag = $Configuration.EnvironmentTag
$ProjectTag = $Configuration.ProjectTag
$IsAutoInflateEnabled = $Configuration.IsAutoInflateEnabled
$MaximumThroughputUnits = $Configuration.MaximumThroughputUnits
$SubscriptionId = $Configuration.SubscriptionId


#******************************************************************************
#login into azure using cert and app registration
#******************************************************************************


#if ($HasThumbPrint) { 
#    $certSubject = "CN=$ServicePrincipalName"
#    $thumbprint = (Get-ChildItem cert:\CurrentUser\My\ | Where-Object {$_.Subject -match $certSubject }).Thumbprint
#    Write-Host "Got thumbprint from certificate: $thumbprint"
#    Login-AzureRmAccount -ServicePrincipal -CertificateThumbprint $thumbprint -ApplicationId $ClientId -TenantId $DirectoryId
#} else {
#    Login-AzureRmAccount;
#}

#select subscription
Write-Host "Selecting subscription: $SubscriptionId";
Select-AzureRmSubscription -SubscriptionID $SubscriptionId;


#******************************************************************************
#prepare everything
#******************************************************************************

#at the moment we only allow 'ne' and 'we' as locations
if ($LocationTag -eq "we") {
    $ResourceGroupLocation = "West Europe"
    $LocationTag = "we"
    $HubLocation = "westeurope"
} 
elseif ($LocationTag -eq "ne"){
    $LocationTag = "ne"
    $ResourceGroupLocation = "North Europe"
    $HubLocation = "northeurope"
} else {
    Write-Host "Only 'we' and 'ne' are supported for location tags, default value is 'we'!"
    $ResourceGroupLocation = "West Europe"
    $LocationTag = "we"
    $HubLocation = "westeurope"
}

#naming of resources
$ResourceGroupName="$CompanyTag-$LocationTag-$EnvironmentTag-$ProjectTag-rg"
$KeyVaultName="$CompanyTag-$LocationTag-$EnvironmentTag-$ProjectTag-vt"


#******************************************************************************
#script body
#******************************************************************************


CreateResourceGroupIfNotPresent -ResourceGroupName $ResourceGroupName -ResourceGroupLocation $ResourceGroupLocation -LocationTag $LocationTag
CreateKeyVaultIfNotPresent -KeyVaultName $KeyVaultName -ResourceGroupName $ResourceGroupName -ResourceGroupLocation $ResourceGroupLocation -LocationTag $LocationTag -ServicePrincipalToAuthorize $ServicePrincipalName

#create azure container registry
$acrParameters = New-Object -TypeName Hashtable
$acrParameters["EnvironmentTag"] = $EnvironmentTag
$acrParameters["LocationTag"] = $LocationTag
$acrParameters["ProjectTag"] = $ProjectTag
$acrParameters["CompanyTag"] = $CompanyTag
$acrParameters["acrSku"] = "Basic"
$acrParameters["acrAdminUserEnabled"] = $True
$acrParametersTemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "./armtemplates/infrastructure.acr.json"))
DeployTemplate -ResourceGroupName $ResourceGroupName -TemplateFileFullPath $acrParametersTemplateFile -TemplateParameters $acrParameters

#create eventhub 
$eventHubTemplateParameters = New-Object -TypeName Hashtable
$eventHubTemplateParameters["EnvironmentTag"] = $EnvironmentTag
$eventHubTemplateParameters["LocationTag"] = $LocationTag
$eventHubTemplateParameters["ProjectTag"] = $ProjectTag
$eventHubTemplateParameters["CompanyTag"] = $CompanyTag
#$eventHubTemplateParameters["IsAutoInflateEnabled"] = $IsAutoInflateEnabled
#$eventHubTemplateParameters["MaximumThroughputUnits"] = $MaximumThroughputUnits
$eventHubTemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "./armtemplates/infrastructure.eventhub.json"))
DeployTemplate -ResourceGroupName $ResourceGroupName -TemplateFileFullPath $eventHubTemplateFile -TemplateParameters $eventHubTemplateParameters

#possible use of key vault for storing keys and retrieving for setting environment variables    
$eventHubSecretsTemplateParameters = New-Object -TypeName Hashtable
$eventHubSecretsTemplateParameters["EnvironmentTag"] = $EnvironmentTag
$eventHubSecretsTemplateParameters["LocationTag"] = $LocationTag
$eventHubSecretsTemplateParameters["ProjectTag"] = $ProjectTag
$eventHubSecretsTemplateParameters["CompanyTag"] = $CompanyTag
$eventHubSecretsTemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "./armtemplates/keyvault.eventhub.json"))
DeployTemplate -ResourceGroupName $ResourceGroupName -TemplateFileFullPath $eventHubSecretsTemplateFile -TemplateParameters $eventHubSecretsTemplateParameters

#create application insights 
$appInsightsParameters = New-Object -TypeName Hashtable
$appInsightsParameters["EnvironmentTag"] = $EnvironmentTag
$appInsightsParameters["LocationTag"] = $LocationTag
$appInsightsParameters["ProjectTag"] = $ProjectTag
$appInsightsParameters["CompanyTag"] = $CompanyTag
$appInsightsParametersTemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "./armtemplates/infrastructure.appinsights.json"))
DeployTemplate -ResourceGroupName $ResourceGroupName -TemplateFileFullPath $appInsightsParametersTemplateFile -TemplateParameters $appInsightsParameters

#add application insights instrumentation key to key vault
$appInsightsSecretsParameters = New-Object -TypeName Hashtable
$appInsightsSecretsParameters["CompanyTag"] = $CompanyTag
$appInsightsSecretsParameters["EnvironmentTag"] = $EnvironmentTag
$appInsightsSecretsParameters["LocationTag"] = $LocationTag
$appInsightsSecretsParameters["ProjectTag"] = $ProjectTag
$appInsightsSecretsParametersTemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "./armtemplates/keyvault.appinsights.json"))
DeployTemplate -ResourceGroupName $ResourceGroupName -TemplateFileFullPath $appInsightsSecretsParametersTemplateFile -TemplateParameters $appInsightsSecretsParameters

#$EventHubSendConnectionString = (Get-AzureKeyVaultSecret -VaultName $KeyVaultName -SecretName eventHubSendConnectionString).SecretValueText
#$EventHubListenConnectionString = (Get-AzureKeyVaultSecret -VaultName $KeyVaultName -SecretName eventHubListenConnectionString).SecretValueText
#$StorageAccessKey = (Get-AzureKeyVaultSecret -VaultName $KeyVaultName -SecretName storageAccessKey).SecretValueText
#$AppInsightsInstrumentationKey = (Get-AzureKeyVaultSecret -VaultName $KeyVaultName -SecretName appInsightsInstrumentationKey).SecretValueText

#Write-Host "EventHubSendConnectionString=$EventHubSendConnectionString"
#Write-Host "EventHubListenConnectionString=$EventHubListenConnectionString"
#Write-Host "StorageAccessKey=$StorageAccessKey"
#Write-Host "AppInsightsInstrumentationKey=$AppInsightsInstrumentationKey"