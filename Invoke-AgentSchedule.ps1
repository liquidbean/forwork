[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [String]$Organization,

    [Parameter(Mandatory = $true)]
    [String]$Project,

    [Parameter(Mandatory = $true)]
    [String]$PoolName,

    [Parameter(Mandatory = $true)]
    [String]$PAT,

    [Parameter(Mandatory = $true)]
    [Int]$InitialAgentCount = 1
) 


$AzureDevOpsAuthenicationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($PAT)")) }

Function Get-RandomAlphanumericString {
    [CmdletBinding()]
    Param (
        [int] $length = 6
    )
    Begin {
    }
    Process {
        Write-Output ( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count $length  | % { [char]$_ }) )
    }	
}
function Get-PoolId {
    param (
        [Parameter(Mandatory = $true)]
        [String]$PoolName,

        [Parameter(Mandatory = $true)]
        [String]$Organization,

        [Parameter(Mandatory = $true)]
        [String]$PAT
    )
    $AzureDevOpsAuthenicationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($PAT)")) }
    $uri = "$Organization/_apis/distributedtask/pools?poolName=$PoolName&api-version=6.0"
    $GetId = Invoke-RestMethod -Uri $uri -Method 'GET' -Headers $AzureDevOpsAuthenicationHeader -ContentType "application/json" 
    
    $PoolId = $GetId.value.id
    
    return $PoolId
}

function Get-AgentId {
    param (
        [Parameter(Mandatory = $true)]
        [String]$PoolId,

        [Parameter(Mandatory = $true)]
        [String]$Organization,

        [Parameter(Mandatory = $true)]
        [String]$PAT
    )
    $AzureDevOpsAuthenicationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($PAT)")) }
    $uri = "$Organization/_apis/distributedtask/pools/$PoolId/agents?api-version=6.0"
    $GetId = Invoke-RestMethod -Uri $uri -Method 'GET' -Headers $AzureDevOpsAuthenicationHeader -ContentType "application/json" 
    
    $Agentids = $GetId.value.id
    
    return $Agentids
}

$PoolId = Get-PoolId -PoolName $PoolName -Organization $Organization -PAT $PAT

$uri = "$Organization/_apis/distributedtask/pools/$PoolId/jobrequests"

$get = Invoke-RestMethod -Uri $uri -Method 'GET' -Headers $AzureDevOpsAuthenicationHeader -ContentType "application/json" 
$GetCount = $get.value | Where-Object -Property 'matchedAgents' -NE $null | Where-Object -Property 'assignTime' -EQ $null

if ($GetCount -eq $null) {
    $AgentId = Get-AgentId -PoolId $PoolId -Organization $Organization -PAT $PAT
    foreach ($Id in $AgentId) {
        $uri = "$Organization/_apis/distributedtask/pools/$PoolId/agents/$Id" + "?includeAssignedRequest=true&includeLastCompletedRequest=true&api-version=6.0"
        $GetJob = Invoke-RestMethod -Uri $uri -Method 'GET' -Headers $AzureDevOpsAuthenicationHeader -ContentType "application/json" 
        if ($GetJob.assignedRequest -eq $null) {
            $AgentCount = Get-AgentId -PoolId $PoolId -Organization $Organization -PAT $PAT
            if ($AgentCount.Length -gt $InitialAgentCount) {
                docker stop $GetJob.name
                docker rm $GetJob.name
            }  
        }
    }
}
else {
    $ContainersList = docker container ls
    $ContainerName = ('azureagent-' + (Get-RandomAlphanumericString)).ToLower()
    if($ContainersList -match $ContainerName){
        $ContainerName = ('azureagent-' + (Get-RandomAlphanumericString)).ToLower()
    }else {
        Start-Job {param($ContainerName, $Organization, $PAT, $PoolName)docker run --name $ContainerName -e AZP_URL=$Organization -e AZP_TOKEN=$PAT -e AZP_AGENT_NAME=$ContainerName -e AZP_POOL=$PoolName dockeragent:latest} -ArgumentList $ContainerName,$Organization,$PAT,$PoolName
    }   
}
