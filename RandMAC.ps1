$currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()

if(! $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) ){
	Start-Process "powershell.exe" -Verb runas -ArgumentList "-ExecutionPolicy Bypass -file $PSCommandPath"
	Exit
}

# Universally administered, unicast bits (First 2 LSBs are 0)
$ULIGBits = 0, 4, 8, "C"

function genRandMAC {
	for($i = 0; $i -lt 12; $i++){
		if($i -eq 1){
			$MAC += "{0:X}" -f (Get-Random $ULIGBits)
		}
		else{
			$MAC += "{0:X}" -f (Get-Random -min 0 -max 16)
		}
	}
	
	return $MAC
}

function formatMAC {
	# Allow for piping
	param(
		[Parameter(ValueFromPipeline = 1)]
		$input
	)
	
	for($i = 0; $i -lt 12; $i += 2){
		$formatted += $input.Substring($i, 2) + "-"
	}
	
	return $formatted.Substring(0, 17) # Remove last "-"
}

function progressLoader {
	Start-Sleep -milliseconds 500
	Write-Host "." -foregroundcolor yellow -nonewline
	Start-Sleep -milliseconds 500
	Write-Host "." -foregroundcolor yellow -nonewline
	Start-Sleep -milliseconds 500
	Write-Host "." -foregroundcolor yellow -nonewline
	Start-Sleep -milliseconds 500
}

function releaseIP {
	$adapter = Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where { $_.IpEnabled -eq $true -and $_.DhcpEnabled -eq $true}
	if($adapter){
		Write-Host "Releaseing DHCP lease" -foregroundcolor yellow -nonewline
		$adapter.ReleaseDHCPLease() | Out-Null
	
		& progressLoader
		Write-Host " DONE!" -foregroundcolor magenta
		Write-Host ""
	}
}

function setRandomMAC {
	Write-Host "Your current MAC address is: " -nonewline -foregroundcolor green
	Write-Host (Get-NetAdapter -Name "Ethernet").MacAddress -foregroundcolor black -backgroundcolor darkcyan
	Write-Host ""
	
	Write-Host "Changing MAC address for: " -foregroundcolor yellow
	Write-Host (Get-NetAdapter -Name "Ethernet").InterfaceDescription -foregroundcolor black -backgroundcolor darkcyan

	do{
		Write-Host ""
		Write-Host "Randomizing" -foregroundcolor yellow -nonewline
		
		$randMAC = genRandMAC
		Set-NetAdapter -Name "Ethernet" -MacAddress $randMAC -Confirm:0
		
		& progressLoader
	} while($randMAC -eq (Get-NetAdapter -Name "Ethernet").MacAddress) # Regenerate if the same MAC address
	
	Write-Host " DONE!" -foregroundcolor magenta
	
	Write-Host ""
	Write-Host "Your current MAC address is now: " -nonewline -foregroundcolor green
	Write-Host (Get-NetAdapter -Name "Ethernet").MacAddress -foregroundcolor black -backgroundcolor darkcyan
	Write-Host "Enjoy :)" -foregroundcolor magenta
	
	Write-Host ""
	
	# Exit if task exists
	if( (Get-ScheduledTask -TaskName "RandMAC" -ErrorAction SilentlyContinue) ){
		Exit
	}
	
	do{	
		$answer = (Read-Host "Would you like to create a scheduled task for MAC randomization? [y/n]`n(The proccess of changing the MAC address will be silent for scheduled tasks)").ToLower()
		
	}while($answer -ne "y" -and $answer -ne "n")
	
	if($answer -eq "n"){
		Write-Host "Goodbye! :)" -foregroundcolor magenta
		Start-Sleep -Seconds 2
		Exit
	}
		
}

function scheduleTask {
	
	Write-Host ""
	
	do{
		$interval = Read-Host "Please enter the desired interval for the task to run: (minutes)"
		$interval = $interval -as [int] # Make sure we only have numbers are input
		
	}while($interval -isnot [int] -or $interval -le 0)
	
	Write-Host ""
	Write-Host "Scheduling MAC address randomization every" $interval "minutes" -foregroundcolor yellow -nonewline
	
	& progressLoader
	
	$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -file $PSCommandPath"
	$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $interval)
	$principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel "Highest"
	$settings = New-ScheduledTaskSettingsSet
	
	$task = New-ScheduledTask -Action $action -Principal $principal -Trigger $trigger -Settings $settings
	Register-ScheduledTask "RandMAC" -InputObject $task
	
	Write-Host "Task created successfully!" -foregroundcolor magenta
	Pause
}

# Execute
& releaseIP
& setRandomMAC

# Create task if doesn't exist
if(! (Get-ScheduledTask -TaskName "RandMAC" -ErrorAction SilentlyContinue) ){
	& scheduleTask
}
