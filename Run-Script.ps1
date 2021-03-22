$Organization = 'https://dev.azure.com/testshadowproject'
$Project = 'https://dev.azure.com/testshadowproject/mainarea'
$PAT = 'bxcfxn4fyvffhwcp6spa4ilij3sett4mc2juubtj3r32hesh7bga'
$PoolName = 'testnamepool'

./Invoke-AgentSchedule.ps1 -Organization $Organization -Project $Project -PAT $PAT -PoolName $PoolName