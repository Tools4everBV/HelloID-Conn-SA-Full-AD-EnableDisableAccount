# Enforce TLS1.2 JK 20200722
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 
#HelloID variables
$PortalBaseUrl = "https://CUSTOMER.helloid.com"
$apiKey = "API_KEY"
$apiSecret = "API_SECRET"
$delegatedFormAccessGroupName = "Users"
 
# Create authorization headers with HelloID API key
$pair = "$apiKey" + ":" + "$apiSecret"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$key = "Basic $base64"
$headers = @{"authorization" = $Key}
# Define specific endpoint URI
if($PortalBaseUrl.EndsWith("/") -eq $false){
    $PortalBaseUrl = $PortalBaseUrl + "/"
}
 
 
 
$variableName = "ADusersSearchOU"
$variableGuid = ""
 
try {
    $uri = ($PortalBaseUrl +"api/v1/automation/variables/named/$variableName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
 
    if([string]::IsNullOrEmpty($response.automationVariableGuid)) {
        #Create Variable
        $body = @{
            name = "$variableName";
            value = '[{ "OU": "OU=Employees,OU=Users,OU=Enyoi,DC=enyoi-media,DC=local"},{ "OU": "OU=Disabled,OU=Users,OU=Enyoi,DC=enyoi-media,DC=local"},{"OU": "OU=External,OU=Users,OU=Enyoi,DC=enyoi-media,DC=local"}]';
            secret = "false";
            ItemType = 0;
        }
 
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/automation/variable")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $variableGuid = $response.automationVariableGuid
    } else {
        $variableGuid = $response.automationVariableGuid
    }
 
    $variableGuid
} catch {
    $_
}
 
 
 
$taskName = "AD-user-generate-table-wildcard"
$taskGetUsersGuid = ""
 
try {
    $uri = ($PortalBaseUrl +"api/v1/automationtasks?search=$taskName&container=1")
    $response = (Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false) | Where-Object -filter {$_.name -eq $taskName}
 
    if([string]::IsNullOrEmpty($response.automationTaskGuid)) {
        #Create Task
 
        $body = @{
            name = "$taskName";
            useTemplate = "false";
            powerShellScript = @'
try {
    $searchValue = $formInput.searchUser
    $searchQuery = "*$searchValue*"
     
     
    if([String]::IsNullOrEmpty($searchValue) -eq $true){
        Hid-Add-TaskResult -ResultValue []
    }else{
        Hid-Write-Status -Message "SearchQuery: $searchQuery" -Event Information
        Hid-Write-Status -Message "SearchBase: $searchOUs" -Event Information
        HID-Write-Summary -Message "Searching for: $searchQuery" -Event Information
         
        $ous = $searchOUs | ConvertFrom-Json
        $users = foreach($item in $ous) {
            Get-ADUser -Filter {Name -like $searchQuery -or DisplayName -like $searchQuery -or userPrincipalName -like $searchQuery -or email -like $searchQuery} -SearchBase $item.ou -properties *
        }
         
        $users = $users | Sort-Object -Property DisplayName
        $resultCount = @($users).Count
        Hid-Write-Status -Message "Result count: $resultCount" -Event Information
        HID-Write-Summary -Message "Result count: $resultCount" -Event Information
         
        if($resultCount -gt 0){
            foreach($user in $users){
                $returnObject = @{SamAccountName=$user.SamAccountName; displayName=$user.displayName; UserPrincipalName=$user.UserPrincipalName; Description=$user.Description; Department=$user.Department; Title=$user.Title; Company=$user.company}
                Hid-Add-TaskResult -ResultValue $returnObject
            }
        } else {
            Hid-Add-TaskResult -ResultValue []
        }
    }
} catch {
    HID-Write-Status -Message "Error searching AD user [$searchValue]. Error: $($_.Exception.Message)" -Event Error
    HID-Write-Summary -Message "Error searching AD user [$searchValue]" -Event Failed
     
    Hid-Add-TaskResult -ResultValue []
}
 
'@;
            automationContainer = "1";
            variables = @(@{name = "searchOUs"; value = "{{variable.ADusersSearchOU}}"; typeConstraint = "string"; secret = "False"})
        }
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/automationtasks/powershell")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $taskGetUsersGuid = $response.automationTaskGuid
 
    } else {
        #Get TaskGUID
        $taskGetUsersGuid = $response.automationTaskGuid
    }
} catch {
    $_
}
 
$taskGetUsersGuid
 
 
 
$dataSourceName = "AD-user-generate-table-wildcard"
$dataSourceGetUsersGuid = ""
 
try {
    $uri = ($PortalBaseUrl +"api/v1/datasource/named/$dataSourceName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
 
    if([string]::IsNullOrEmpty($response.dataSourceGUID)) {
        #Create DataSource
        $body = @{
            name = "$dataSourceName";
            type = "3";
            model = @(@{key = "Company"; type = 0}, @{key = "Department"; type = 0}, @{key = "Description"; type = 0}, @{key = "displayName"; type = 0}, @{key = "SamAccountName"; type = 0}, @{key = "Title"; type = 0}, @{key = "UserPrincipalName"; type = 0});
            automationTaskGUID = "$taskGetUsersGuid";
            input = @(@{description = ""; translateDescription = "False"; inputFieldType = "1"; key = "searchUser"; type = "0"; options = "1"})
        }
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/datasource")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
         
        $dataSourceGetUsersGuid = $response.dataSourceGUID
    } else {
        #Get DatasourceGUID
        $dataSourceGetUsersGuid = $response.dataSourceGUID
    }
} catch {}
$dataSourceGetUsersGuid
 
 
 
$taskName = "AD-user-generate-table-attributes-basic"
$taskGetUserDetailsGuid = ""
 
try {
    $uri = ($PortalBaseUrl +"api/v1/automationtasks?search=$taskName&container=1")
    $response = (Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false) | Where-Object -filter {$_.name -eq $taskName}
 
    if([string]::IsNullOrEmpty($response.automationTaskGuid)) {
        #Create Task
 
        $body = @{
            name = "$taskName";
            useTemplate = "false";
            powerShellScript = @'
try {
    $userPrincipalName = $formInput.selectedUser.UserPrincipalName
    HID-Write-Status -Message "Searching AD user [$userPrincipalName]" -Event Information
     
    $adUser = Get-ADuser -Filter { UserPrincipalName -eq $userPrincipalName } -Properties * | select displayname, samaccountname, userPrincipalName, mail, employeeID, Enabled
    HID-Write-Status -Message "Finished searching AD user [$userPrincipalName]" -Event Information
     
    foreach($tmp in $adUser.psObject.properties)
    {
        $returnObject = @{name=$tmp.Name; value=$tmp.value}
        Hid-Add-TaskResult -ResultValue $returnObject
    }
     
    HID-Write-Status -Message "Finished retrieving AD user [$userPrincipalName] basic attributes" -Event Success
    HID-Write-Summary -Message "Finished retrieving AD user [$userPrincipalName] basic attributes" -Event Success
} catch {
    HID-Write-Status -Message "Error retrieving AD user [$userPrincipalName] basic attributes. Error: $($_.Exception.Message)" -Event Error
    HID-Write-Summary -Message "Error retrieving AD user [$userPrincipalName] basic attributes" -Event Failed
     
    Hid-Add-TaskResult -ResultValue []
}
'@;
            automationContainer = "1";
        }
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/automationtasks/powershell")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $taskGetUserDetailsGuid = $response.automationTaskGuid
 
    } else {
        #Get TaskGUID
        $taskGetUserDetailsGuid = $response.automationTaskGuid
    }
} catch {
    $_
}
 
$taskGetUserDetailsGuid
 
 
 
$dataSourceName = "AD-user-generate-table-attributes-basic"
$dataSourceGetUserDetailsGuid = ""
 
try {
    $uri = ($PortalBaseUrl +"api/v1/datasource/named/$dataSourceName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
 
    if([string]::IsNullOrEmpty($response.dataSourceGUID)) {
        #Create DataSource
        $body = @{
            name = "$dataSourceName";
            type = "3";
            model = @(@{key = "name"; type = 0}, @{key = "value"; type = 0});
            automationTaskGUID = "$taskGetUserDetailsGuid";
            input = @(@{description = ""; translateDescription = "False"; inputFieldType = "1"; key = "selectedUser"; type = "0"; options = "1"})
        }
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/datasource")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
         
        $dataSourceGetUserDetailsGuid = $response.dataSourceGUID
    } else {
        #Get DatasourceGUID
        $dataSourceGetUserDetailsGuid = $response.dataSourceGUID
    }
} catch {
    $_
}
 
$dataSourceGetUserDetailsGuid
 
 
$taskName = "AD-user-get-attribute-enabled"
$taskGetUserEnabledGuid = ""
 
try {
    $uri = ($PortalBaseUrl +"api/v1/automationtasks?search=$taskName&container=1")
    $response = (Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false) | Where-Object -filter {$_.name -eq $taskName}
 
    if([string]::IsNullOrEmpty($response.automationTaskGuid)) {
        #Create Task
 
        $body = @{
            name = "$taskName";
            useTemplate = "false";
            powerShellScript = @'
$UserPrincipalName = $formInput.selectedUser.UserPrincipalName
HID-Write-Status -Message "Searching AD user [$userPrincipalName]" -Event Information
 
try {
    $adUser = Get-ADuser -Filter { UserPrincipalName -eq $userPrincipalName } -Properties enabled | select enabled
    HID-Write-Status -Message "Finished searching AD user [$userPrincipalName]" -Event Information
    HID-Write-Summary -Message "Found AD user [$userPrincipalName]" -Event Information
     
    $enabled = $adUser.enabled
     
    Hid-Write-Status -Message "Account enabled: $enabled" -Event Information
    HID-Write-Summary -Message "Account enabled: $enabled" -Event Information
     
    Hid-Add-TaskResult -ResultValue @{ enabled = $enabled }
} catch {
    HID-Write-Status -Message "Error retrieving AD user [$userPrincipalName] account status. Error: $($_.Exception.Message)" -Event Error
    HID-Write-Summary -Message "Error retrieving AD user [$userPrincipalName] account status" -Event Failed
     
    Hid-Add-TaskResult -ResultValue []
}
'@;
            automationContainer = "1";
        }
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/automationtasks/powershell")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $taskGetUserEnabledGuid = $response.automationTaskGuid
 
    } else {
        #Get TaskGUID
        $taskGetUserEnabledGuid = $response.automationTaskGuid
    }
} catch {
    $_
}
 
$taskGetUserEnabledGuid
 
 
 
$dataSourceName = "AD-user-get-attribute-enabled"
$dataSourceGetUserEnabledGuid = ""
 
try {
    $uri = ($PortalBaseUrl +"api/v1/datasource/named/$dataSourceName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
 
    if([string]::IsNullOrEmpty($response.dataSourceGUID)) {
        #Create DataSource
        $body = @{
            name = "$dataSourceName";
            type = "3";
            model = @(@{key = "enabled"; type = 0});
            automationTaskGUID = "$taskGetUserEnabledGuid";
            input = @(@{description = ""; translateDescription = "False"; inputFieldType = "1"; key = "selectedUser"; type = "0"; options = "1"})
        }
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/datasource")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
         
        $dataSourceGetUserEnabledGuid = $response.dataSourceGUID
    } else {
        #Get DatasourceGUID
        $dataSourceGetUserEnabledGuid = $response.dataSourceGUID
    }
} catch {
    $_
}
 
$dataSourceGetUserEnabledGuid
 
 
$formName = "AD Account - (De)Activate"
$formGuid = ""
 
try
{
    try {
        $uri = ($PortalBaseUrl +"api/v1/forms/$formName")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
    } catch {
        $response = $null
    }
 
    if(([string]::IsNullOrEmpty($response.dynamicFormGUID)) -or ($response.isUpdated -eq $true))
    {
        #Create Dynamic form
        $form = @"
[
  {
    "label": "Select user account",
    "fields": [
      {
        "key": "searchfield",
        "templateOptions": {
          "label": "Search",
          "placeholder": "Username or email address"
        },
        "type": "input",
        "summaryVisibility": "Hide element",
        "requiresTemplateOptions": true
      },
      {
        "key": "gridUsers",
        "templateOptions": {
          "label": "Select user",
          "required": true,
          "grid": {
            "columns": [
              {
                "headerName": "DisplayName",
                "field": "displayName"
              },
              {
                "headerName": "UserPrincipalName",
                "field": "UserPrincipalName"
              },
              {
                "headerName": "Department",
                "field": "Department"
              },
              {
                "headerName": "Title",
                "field": "Title"
              },
              {
                "headerName": "Description",
                "field": "Description"
              }
            ],
            "height": 300,
            "rowSelection": "single"
          },
          "dataSourceConfig": {
            "dataSourceGuid": "$dataSourceGetUsersGuid",
            "input": {
              "propertyInputs": [
                {
                  "propertyName": "searchUser",
                  "otherFieldValue": {
                    "otherFieldKey": "searchfield"
                  }
                }
              ]
            }
          },
          "useFilter": false
        },
        "type": "grid",
        "summaryVisibility": "Show",
        "requiresTemplateOptions": true
      }
    ]
  },
  {
    "label": "(De)activate",
    "fields": [
      {
        "key": "gridDetails",
        "templateOptions": {
          "label": "Basic attributes",
          "required": false,
          "grid": {
            "columns": [
              {
                "headerName": "Name",
                "field": "name"
              },
              {
                "headerName": "Value",
                "field": "value"
              }
            ],
            "height": 350,
            "rowSelection": "single"
          },
          "dataSourceConfig": {
            "dataSourceGuid": "$dataSourceGetUserDetailsGuid",
            "input": {
              "propertyInputs": [
                {
                  "propertyName": "selectedUser",
                  "otherFieldValue": {
                    "otherFieldKey": "gridUsers"
                  }
                }
              ]
            }
          },
          "useFilter": false
        },
        "type": "grid",
        "summaryVisibility": "Hide element",
        "requiresTemplateOptions": true
      },
      {
        "key": "enabled",
        "templateOptions": {
          "label": "AD account status",
          "useSwitch": true,
          "checkboxLabel": "active",
          "useDataSource": true,
          "displayField": "enabled",
          "dataSourceConfig": {
            "dataSourceGuid": "$dataSourceGetUserEnabledGuid",
            "input": {
              "propertyInputs": [
                {
                  "propertyName": "selectedUser",
                  "otherFieldValue": {
                    "otherFieldKey": "gridUsers"
                  }
                }
              ]
            }
          },
          "useFilter": false
        },
        "type": "boolean",
        "summaryVisibility": "Show",
        "requiresTemplateOptions": true
      }
    ]
  }
]
"@
 
        $body = @{
            Name = "$formName";
            FormSchema = $form
        }
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/forms")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
 
        $formGuid = $response.dynamicFormGUID
    } else {
        $formGuid = $response.dynamicFormGUID
    }
} catch {
    $_
}
 
$formGuid
 
 
 
 
$delegatedFormAccessGroupGuid = ""
 
try {
    $uri = ($PortalBaseUrl +"api/v1/groups/$delegatedFormAccessGroupName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
    $delegatedFormAccessGroupGuid = $response.groupGuid
} catch {
    $_
}
 
$delegatedFormAccessGroupGuid
 
 
 
$delegatedFormName = "AD Account - (De)Activate"
$delegatedFormGuid = ""
 
try {
    try {
        $uri = ($PortalBaseUrl +"api/v1/delegatedforms/$delegatedFormName")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
    } catch {
        $response = $null
    }
 
    if([string]::IsNullOrEmpty($response.delegatedFormGUID)) {
        #Create DelegatedForm
        $body = @{
            name = "$delegatedFormName";
            dynamicFormGUID = "$formGuid";
            isEnabled = "True";
            accessGroups = @("$delegatedFormAccessGroupGuid");
            useFaIcon = "True";
            faIcon = "fa fa-unlock";
        }   
 
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/delegatedforms")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
 
        $delegatedFormGuid = $response.delegatedFormGUID
    } else {
        #Get delegatedFormGUID
        $delegatedFormGuid = $response.delegatedFormGUID
    }
} catch {
    $_
}
 
$delegatedFormGuid
 
 
 
 
$taskActionName = "AD-user-set-enabled"
$taskActionGuid = ""
 
try {
    $uri = ($PortalBaseUrl +"api/v1/automationtasks?search=$taskActionName&container=8")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
 
    if([string]::IsNullOrEmpty($response.automationTaskGuid)) {
        #Create Task
 
        $body = @{
            name = "$taskActionName";
            useTemplate = "false";
            powerShellScript = @'
try {
    $adUser = Get-ADuser -Filter { UserPrincipalName -eq $userPrincipalName }
    HID-Write-Status -Message "Found AD user [$userPrincipalName]" -Event Information
    HID-Write-Summary -Message "Found AD user [$userPrincipalName]" -Event Information
} catch {
    HID-Write-Status -Message "Could not find AD user [$userPrincipalName]. Error: $($_.Exception.Message)" -Event Error
    HID-Write-Summary -Message "Failed to find AD user [$userPrincipalName]" -Event Failed
}
 
if($blnenabled -eq 'true'){
    try {
        Enable-ADAccount -Identity $adUser
         
        HID-Write-Status -Message "Finished enable AD user [$userPrincipalName]" -Event Success
        HID-Write-Summary -Message "Successfully enabled AD user [$userPrincipalName]" -Event Success
    } catch {
        HID-Write-Status -Message "Could not enable AD user [$userPrincipalName]. Error: $($_.Exception.Message)" -Event Error
        HID-Write-Summary -Message "Failed to enable AD user [$userPrincipalName]" -Event Failed
    }
}
     
if($blnenabled -eq 'false'){
    try {
        Disable-ADAccount -Identity $adUser
         
        HID-Write-Status -Message "Finished disable AD user [$userPrincipalName]" -Event Success
        HID-Write-Summary -Message "Successfully disabled AD user [$userPrincipalName]" -Event Success
    } catch {
        HID-Write-Status -Message "Could not disable AD user [$userPrincipalName]. Error: $($_.Exception.Message)" -Event Error
        HID-Write-Summary -Message "Failed to disable AD user [$userPrincipalName]" -Event Failed
    }
}
 
'@;
            automationContainer = "8";
            objectGuid = "$delegatedFormGuid";
            variables = @(@{name = "blnenabled"; value = "{{form.enabled}}"; typeConstraint = "string"; secret = "False"},
                        @{name = "userPrincipalName"; value = "{{form.gridUsers.UserPrincipalName}}"; typeConstraint = "string"; secret = "False"});
        }
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/automationtasks/powershell")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $taskActionGuid = $response.automationTaskGuid
 
    } else {
        #Get TaskGUID
        $taskActionGuid = $response.automationTaskGuid
    }
} catch {
    $_
}
 
$taskActionGuid