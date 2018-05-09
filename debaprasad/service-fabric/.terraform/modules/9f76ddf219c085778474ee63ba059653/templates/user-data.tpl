<script>
powershell Install-Module -Name xNetworking -Force
</script>
<powershell>
$WhatIf=$false
$TempOut = join-path $env:TEMP ([System.IO.Path]::GetRandomFileName())
Write-Verbose "MOF file location: '$TempOut'"

Configuration Service_Fabric_Node
{
    Param($Config)
	Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DSCResource -ModuleName xNetworking

    WindowsFeature SMB
    {
        Name        = "FS-SMB1"
        Ensure      = "Present"
    }

    Service Firewall
    {
        Name        = "MpsSvc"
        State       = "Running"
    }

    WindowsFeature DOT_NET
    {
        Name        = "NET-Framework-45-Core"
        Ensure      = "Present"
    }

    Service RemoteRegistry
    {
        Name        = "RemoteRegistry"
        StartupType = "Automatic"
        State       = "Running"
    }

    xFirewall EnableV4PingIn
    {
        Name = 'Allow ICMPv4 protocal'
        Group= 'File and Printer Sharing'
        Protocol = 'ICMPv4'
        Ensure='Present'
        Enabled='True'
        Direction='Inbound'
        Profile = ('Domain', 'Private', 'Public')
    }
}

$Config = @{
}

Service_Fabric_Node -outputPath "$TempOut" -Config $Config -Verbose -ErrorAction Stop

function EnablePSRemoting()
{
	Enable-PSRemoting -Force
}

function EnableNetworkDiscovery()
{
	Get-NetFirewallRule -DisplayGroup 'Network Discovery'|Set-NetFirewallRule -Profile 'Private,Domain,Public' -Enabled true
}

function EnableFileAndPrinterSharing()
{
	Get-NetFirewallRule -DisplayGroup 'File and printer sharing'|Set-NetFirewallRule -Profile 'Private,Domain,Public' -Enabled true
}

function InstallXNetworkingModule
{
	Install-Module -Name xNetworking -Force
}

function CreateSFDirectory
{
	New-Item c:\Windows\Temp\ServiceFabric -type directory
}

function DownloadServiceFabricZippedPackage()
{
	Invoke-WebRequest -Uri http://go.microsoft.com/fwlink/?LinkId=730690 -OutFile c:\Windows\Temp\ServiceFabric\package.zip
}

function UnZipServiceFabricPackage()
{
	Expand-Archive -LiteralPath c:\Windows\Temp\ServiceFabric\package.zip -DestinationPath c:\Windows\Temp\ServiceFabric
}

function CheckDSCConfiguration()
{
	if ($WhatIf)
	{
		Test-DscConfiguration -Path "$TempOut" -Verbose -ErrorAction SilentlyContinue
	}
	else
	{
		Start-DscConfiguration -Path "$TempOut" -Verbose -Wait -Force -ErrorAction Stop
	}
}

function CreateSFCluster()
{
	$asg = Get-ASAutoScalingGroup -AutoScalingGroupName soumya-sf-ecs-scaling-group | ConvertTo-Json | ConvertFrom-Json
	$faultDomain = "fd:/dc1/" + $asg.Instances.Length
	$upgradeDomain = "UD" + $asg.Instances.Length

	If ($asg.Instances.Length -gt 1) {	  
	
		$currentInstanceId =  Invoke-RestMethod -uri http://169.254.169.254/latest/meta-data/instance-id
		
		$retries = 3
		$retryCount = 0
		$tried = @($currentInstanceId)
		$completed = $false
		$connectionIp = ""

		while (-not $completed) {
			try {
				#get theintanceId that is not equal to the current instance Id from the $asg.Instances array
				#$connInstanceId = ($asg.Instances.Where{ $tried -notcontains $_.InstanceId } | Select-Object -first 1).InstanceId
				$connInstanceId = (Get-EC2Instance).RunningInstance| ? {$_.Tag.Key -eq "IsServiceFabricMaster" -and $_.Tag.Value -eq "Yes"} | SELECT -Expandproperty InstanceId
				$tried += $connInstanceId
		
				#use aws powershell ec2 describe api to get the private IP of the $instanceId assign to var $connectionIp
				$connectionIp = (Get-EC2Instance -InstanceId $connInstanceId).Instances[0].PrivateIpAddress
				$connectionIp = $connectionIp + ":19000"		
		
				.\AddNode.ps1 -NodeName $currentInstanceId -NodeType NodeType0 -NodeIPAddressorFQDN $privateIp -ExistingClientConnectionEndpoint $connectionIp -UpgradeDomain $upgradeDomain -FaultDomain $faultDomain -AcceptEULA
				$completed = $true				
			} 
			catch {
				
				if ($retryCount -ge $retries) {
					Write-Verbose ("Command [{0}] failed the maximum number of {1} times." -f "AddNode", $retryCount)
					throw
				} else {
					Write-Verbose ("Command [{0}] failed for {1}. Retrying.." -f "Add Node", $connectionIp)
					$retryCount++
				}
			}
		}
		
		#connect to cluster 
		Connect-ServiceFabricCluster -ConnectionEndpoint $connectionIp		
		
		#only upgrade entire cluster if atleast 3 nodes
		$sfConfig = Get-ServiceFabricClusterConfiguration | ConvertFrom-Json
		If($sfConfig.Nodes.Length -gt 2){
			$sfConfig = Get-ServiceFabricClusterConfiguration | ConvertFrom-Json

			#add new node to cluster config
			#$sfConfig.Nodes +=$newNode
			
			#update config verion
			#$sfConfig.clusterConfigurationVersion =   $sfConfig.clusterConfigurationVersion + "." +  $asg.Instances.Length

			$version = [version]$sfConfig.ClusterConfigurationVersion;
			$sfConfig.ClusterConfigurationVersion = "{0}.{1}.{2}" -f $version.Major, $version.Minor, ($version.Build + 1)

			#dump to file updated cluster config
			$sfConfig | ConvertTo-Json -depth 100 | Out-File "clusterConfig.json"
			
			#upgrade cluster with new node					
			Start-ServiceFabricClusterConfigurationUpgrade -ClusterConfigPath "clusterConfig.json"
		}
	}  
	Else {
		$clusterConfig = (Get-Content ClusterConfig.Unsecure.OneNode.json) -join "`n" | ConvertFrom-Json
		$clusterConfig.nodes[0].iPAddress = $privateIp
		$clusterConfig.nodes[0].nodeName = $currentInstanceId
		$clusterConfig.nodes[0].faultDomain = $faultDomain
		$clusterConfig.nodes[0].upgradeDomain = $upgradeDomain
		
		$clusterConfig | ConvertTo-Json -depth 100 | Out-File "clusterConfig.json"
		.\CreateServiceFabricCluster.ps1 -ClusterConfigFilePath .\ClusterConfig.json -AcceptEULA
	}
}

try
{
	EnablePSRemoting

	Set-Item WSMan:\localhost\Client\TrustedHosts -Value * -force
	Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
	
	EnableNetworkDiscovery

	EnableFileAndPrinterSharing
	
	InstallXNetworkingModule
	
	CreateSFDirectory
	
	DownloadServiceFabricZippedPackage

	UnZipServiceFabricPackage

    $privateIp =  Invoke-RestMethod -uri http://169.254.169.254/latest/meta-data/local-ipv4 
	$currentInstanceId =  Invoke-RestMethod -uri http://169.254.169.254/latest/meta-data/instance-id
	cd c:\Windows\Temp\ServiceFabric
	
	CheckDSCConfiguration
	
	CreateSFCluster
	
}
finally
{
	Remove-Item $TempOut -Force -Recurse -ErrorAction Ignore
}
</powershell>
