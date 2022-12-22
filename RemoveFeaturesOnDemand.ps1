<#
.SYNOPSIS
	Remove built-in Features On Demand from Windows 10.
	
	FileName:    RemoveFeaturesOnDemand.ps1
    Author:      Mark Messink
    Contact:     
    Created:     2020-11-24
    Updated:     2022-12-20

    Version history:
    1.0.2 - (2021-12-21) Windows 10 build 21H2, Windows 11 build 21H2
	1.0.3 - Changed logging
	1.0.4 - Add creating list of installed FOD to Installed_FOD_List.txt 
	1.0.5 - (2022-12-20) Windows 10 build 21H2, Windows 11 build 22H2

.DESCRIPTION
	<wat doet het script in meerdere regels>

.PARAMETER
	<beschrijf de parameters die eventueel aan het script gekoppeld moeten worden>

.INPUTS


.OUTPUTS
	logfiles:
	PSlog_<naam>	Log gegenereerd door een powershell script
	INlog_<naam>	Log gegenereerd door Intune (Win32)
	AIlog_<naam>	Log gegenereerd door de installer van een applicatie bij de installatie van een applicatie
	ADlog_<naam>	Log gegenereerd door de installer van een applicatie bij de de-installatie van een applicatie
	Een datum en tijd wordt automatisch toegevoegd

.EXAMPLE
	./scriptnaam.ps1

.LINK Information

.NOTES
	WindowsBuild:
	Het script wordt uitgevoerd tussen de builds LowestWindowsBuild en HighestWindowsBuild
	LowestWindowsBuild = 0 en HighestWindowsBuild 50000 zijn alle Windows 10/11 versies
	LowestWindowsBuild = 19000 en HighestWindowsBuild 19999 zijn alle Windows 10 versies
	LowestWindowsBuild = 22000 en HighestWindowsBuild 22999 zijn alle Windows 11 versies
	Zie: https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information

.NOTES
	Create new Whitelist:
	Get-WindowsCapability -Online | where state -eq installed | FT Name

.NOTES	
	Remove a FOD:
	You can remove a FOD by adding a ### to the beginning of a line
	every line ends with a comma except the last line!
#>

#################### Variabelen #####################################
$logpath = "C:\IntuneLogs"
$NameLogfile = "PSlog_RemoveFeaturesOnDemand.txt"
$LowestWindowsBuild = 0
$HighestWindowsBuild = 50000
$InstalledFODList = "Installed_FOD_List.txt"


#################### Einde Variabelen ###############################


#################### Start base script ##############################
### Niet aanpassen!!!

# Prevent terminating script on error.
$ErrorActionPreference = 'Continue'

# Create logpath (if not exist)
If(!(test-path $logpath))
{
      New-Item -ItemType Directory -Force -Path $logpath
}

# Add date + time to Logfile
$TimeStamp = "{0:yyyyMMdd}" -f (get-date)
$logFile = "$logpath\" + "$TimeStamp" + "_" + "$NameLogfile"

# Start Transcript logging
Start-Transcript $logFile -Append -Force

# Start script timer
$scripttimer = [system.diagnostics.stopwatch]::StartNew()

# Controle Windows Build
$WindowsBuild = [System.Environment]::OSVersion.Version.Build
Write-Output "------------------------------------"
Write-Output "Windows Build: $WindowsBuild"
Write-Output "------------------------------------"
If ($WindowsBuild -ge $LowestWindowsBuild -And $WindowsBuild -le $HighestWindowsBuild)
{
#################### Start base script ################################

#################### Start uitvoeren script code ####################
Write-Output "#####################################################################################"
Write-Output "### Start uitvoeren script code                                                   ###"
Write-Output "#####################################################################################"

#Create list installed FOD
[system.Environment]::OSVersion.Version | Out-File -FilePath $logpath\$InstalledFODList -Append
Get-WindowsCapability -online | where state -eq installed | Select-Object -ExpandProperty Name | Out-File -FilePath $logpath\$InstalledFODList -Append

#Create WhiteList Array
$WhiteListedFOD = New-Object -TypeName System.Collections.ArrayList

<##### Features On Demand that shouldn't be removed #####>  			
	$WhiteListedFOD.AddRange(@(	
	"Browser.InternetExplorer~",
	"Hello.Face",
	"Language", #Language.Basic, Language.Handwriting, Language.OCR, Language.TextToSpeech
	"Microsoft.Windows.Ethernet.Client", #Microsoft.Windows.Ethernet.Client.<hardware>.<Type>
	"Microsoft.Windows.Wifi.Client", #Microsoft.Windows.Wifi.Client.<hardware>.<Type>
	"Windows.Kernel",
	"Windows.Client.ShellComponents~"  # last whitelisted item no comma
	))
  
<##### Features On Demand - Windows 10 - 21H2 #####>   
	$WhiteListedFOD.AddRange(@(
	"App.Support.QuickAssist~",	
	"DirectX.Configuration.Database~",
	### "MathRecognizer~",
	"Media.WindowsMediaPlayer~", 
	"Microsoft.Windows.MSPaint~",
	"Microsoft.Windows.Notepad~",
	"Microsoft.Windows.WordPad~"  # last whitelisted item no comma
	### "OneCoreUAP.OneSync~",
	### "Print.Fax.Scan~",
	### "Print.Management.Console~"
	))

<##### Features On Demand - Windows 11 - 22H2 #####>   
	$WhiteListedFOD.AddRange(@(
	"Microsoft.Windows.Notepad.System~"  # last whitelisted item no comma
	### "OpenSSH.Client~",
	### "WMIC~" #WMI command line utility
	))

	Write-Output "-------------------------------------------------------------------------------"
    Write-Output "Starting Features on Demand removal process"	
	Write-Output "-------------------------------------------------------------------------------"
	
	# Determine packagenames from $WhiteListedFOD
	$WhiteListedFOD = foreach ($FOD in $WhiteListedFOD) {Get-WindowsCapability -Online -Name $FOD* | where state -eq installed | Select-Object -ExpandProperty Name}
	
	# determine installed Packagenames
	$InstalledFOD = Get-WindowsCapability -online -LimitAccess | where state -like installed | Select-Object -ExpandProperty Name
			
	# Loop through the list of FOD
	foreach ($FOD in $InstalledFOD) {
		Write-Output "-------------------------------------------------------------------------------"
        Write-Output "Processing FOD package: $($FOD)"
		
        # If FOD name not in FOD white list, remove FOD
        if (($FOD -in $WhiteListedFOD)) {
            Write-Output "--- Skipping excluded application package: $($FOD)"
        }
		else {
		
		    try {
                Write-Output ">>> Removing Feature on Demand package: $($FOD)"
				Get-WindowsCapability -Online -LimitAccess -ErrorAction Stop | Where-Object { $_.Name -like $FOD } | Remove-WindowsCapability -Online -ErrorAction Stop | Out-Null
                }
				
			catch [System.Exception] {
                Write-Output "!!! Removing Feature on Demand package failed: $($_.Exception.Message)"
				}
			}
	}
    # Complete
	Write-Output "-------------------------------------------------------------------------------"
    Write-Output "Completed Feature on Demand removal process"
	Write-Output "-------------------------------------------------------------------------------"

Write-Output "#####################################################################################"
Write-Output "### Einde uitvoeren script code                                                   ###"
Write-Output "#####################################################################################"
#################### Einde uitvoeren script code ####################

#################### End base script #######################

# Controle Windows Build
}Else {
Write-Output "-------------------------------------------------------------------------------------"
Write-Output "### Windows Build versie voldoet niet, de script code is niet uitgevoerd. ###"
Write-Output "-------------------------------------------------------------------------------------"
}

#Stop and display script timer
$scripttimer.Stop()
Write-Output "------------------------------------"
Write-Output "Script elapsed time in seconds:"
$scripttimer.elapsed.totalseconds
Write-Output "------------------------------------"

#Stop Logging
Stop-Transcript
#################### End base script ################################

#################### Einde Script ###################################