#####################################################################################################
# vrli_vmotion.ps1 <user> <password> <vm name>
# This script is triggered by vRLI WebHook and VMotions a VM to another host in the cluster
# Destination host is chosen randomly and for for CLU02/3 host is selected from respective OS host group
# For CLU05 VMotion is not triggered since DRS is disabled (VMs not VMotion friendly)
#####################################################################################################

Param(
  [string]$user,
  [string]$pass,
  [string]$vmname
)

# Config
$vc = "10.223.2.103"

if (!(Get-module | where {$_.Name -eq "VMware.VimAutomation.Core"})) {Import-Module VMware.VimAutomation.Core}

# Check command line args
Write-Output "$(get-date -f s): ============== VMotion start ===============" 
if (($user -eq "") -or ($pass -eq "") -or ($vmname -eq ""))
{
	Write-Output "$(get-date -f s): Arguments missing - aborting" 
	Exit
}
Write-Output "$(get-date -f s): Arguments received $user pw $vmname" 

# Connect to VC and get vm
Connect-VIServer $vc -user $user -password $pass | Out-Null
$vm = Get-VM -name $vmname -ErrorAction SilentlyContinue

if ($vm -ne $null){		# Proceed if VM is found

	# Gather VM, Cluster and Host Info
	$os= $vm.extensiondata.config.GuestFullName
	$curHost = $vm | Get-VMhost
	$curClu = $vm | Get-Cluster
	$vmHosts = $curClu | Get-VMhost | Sort
	
	# Select random destination host from the cluster- has some filtering for CLU02/3 due to DRS host groups based on OS type
	do{
		if ($curClu -like "CLU02*"){
			if ($os -like "*windows*"){
				$randMin = 10
				$randMax = 15
			} else {
				$randMin = 0
				$randMax = 9
			}
		} elseif ($curClu -like "CLU03*"){
			if ($os -like "*windows*"){
				$randMin = 6
				$randMax = 11
			} else {
				$randMin = 0
				$randMax = 5
			}
		} else {
			$randMin = 0
			$randMax = $vmHosts.Count
		}
		$randVal = Get-Random -Minimum $randMin -Maximum $randMax
		$destHost = $vmHosts[$randVal]
	}
	while (($curHost -eq $destHost) -or ($destHost.ConnectionState -ne "Connected"))
	
	# VMotion VM if not in CLU05 - DRS is disable for Cluster 5
	If ($curClu -like "CLU05*"){
		Write-Output "$(get-date -f s): $vm is in CLU05 cluster - no VMotion" 
	} else {
		Write-Output "$(get-date -f s): VMotion $vm $curClu $curHost $destHost" 
		Move-VM -VM $vm -Destination $DestHost | Out-Null
	}
	
} else {	# VM not found
	Write-Output "$(get-date -f s): VM not found - $vmname" 
}

# Batch End
Write-Output "$(get-date -f s): ==============  VMotion end  ===============`n" 
Disconnect-VIServer -Confirm:$false
