Project Purpose: 
This project is a tool suite written in PowerShell to help System Administrators and Information Assurance Officers with any DOD RMF and Information Assurance (IA) related processes.  This suite is able to convert scan results into Plans of Actions and Milestones (POAMs), archive event logs, compare package hardware lists to actual hardware lists, check the status of Information Assurance Vulnerability Management items (IAVMs), execute Security Technical Implementation Guidelines (STIGs), convert benchmark STIGs to Group Policy Objects and many other IA related actions.

Major Technologies Employed: 
This tool suite is programmed in PowerShell, which is derived from the Dot Net Framework.  It can execute on any windows based system that has PowerShell V2 installed.  It utilizes a GNU Public License (GPL) library for many of its internal Object Oriented functions.

Related DoD Programs/Systems: 
There are no other Programs of record or identifiable systems that are related to this tool suite.

Participation Plans: 
Members of this project should have a deep developmental background utilizing Dot Net (preferably C#) and knowledge of the way PowerShell operates.  Members must also have knowledge of common System Administrator tasks.
 
The suite is available online at:
https://software.forge.mil/sf/projects/diacap_tools 

Go Home -> File Releases -> Cyber Security Tool Suite -> Latest version

The scripts come as a suite, so just unzip them anywhere you would like.  Once that is done, you'll need to let PowerShell know it can execute scripts.  You can do that by opening PowerShell as an admin, and running the following command:
 
PS C:\>set-executionpolicy unrestricted
 
It should prompt you for confirmation.  Just enter Y and hit enter.  Once that is done, you should have full access to the scripts.  Most of them can be run either via command line parameters are with the built in user interface.  There is also a setup.bat file in the root directory that will accomplish the same.  Most of the scripts require the PowerShell console to be run as an administrator and Microsoft Office needs to be installed for export purposes.
 
Below is a quick rundown of the scripts and what they do.  I'm assuming you unzipped to 'C:\Scripts' so that is the path you'll see.  Most of the scripts will accept the following command line parameters, or the GUI can be used if these are not provided.   Executing the script by just calling its name (.\scriptName.ps1) will use the GUI.
 
hostCsvPath - the path to a csv file that contains hostnames, if available.
computers - a comma separated string of hostnames
OU - a string specifying an Active Directory OU container for the hosts that need to be processed.
 
You can also execute
PS c:\> get-help .\scriptname.ps1 to view the internal documentation.
-------------------------------------------------------------------------------
.\acheievement.ps1


-------------------------------------------------------------------------------
.\applyPolicies.ps1
This is a script that will attempt to apply machine and user policies without the user logging on.  This will push multiple SCAP, GPO or Registry.pol settings to all profiles on a system and the machine profile.

Parameters:
	hostCsvPath - The path the a CSV File containing hosts
	computers - A comma separated list of hostnames
	OU - An Organizational Unit in Active Directory to pull host names from
	userGpoPath - A path to a GPO to pull user settings from
	machineGpoPath - A path to a GPO to pull machine settings from
	userGpo - A domain GPO to pull user settings from
	machineGpo - A domain GPO to pull machine settings from
	xccdfPath - A path to a SCAP Xccdf file to pull user and machine settings from.
	ovalPath - A path to a SCAP Oval file to pull user and machine settings from.
	profile - The profile within the SCAP file to use
	manualExec - Whether of not to auto-execute
	force - 

Example:
	.\ApplyPolicies.ps1
	This will present the user with a gui to choose the hosts and policies to apply.

-------------------------------------------------------------------------------
.\archiveEventlogs.ps1


-------------------------------------------------------------------------------
.\cleanScapFolder.ps1
This is a script that will clean up dead entries in a scap results folder

Parameters:
	scanPath - The path to the root SCC Results folder
	removeOld - If present, the out-dated scan results will be deleted.
	manualExec - Whether of not to auto-execute

Example:
	.\cleanScapFolder.ps1 -scanPath "c:\scc\results\scap\"
	This example will clean the designated path

-------------------------------------------------------------------------------
.\cleanUsbHistory.ps1
This script will clean up the history of usb devices connected to a selected machine

Parameters:
	hostCsvPath - The path the a CSV File containing hosts
	computers - A comma separated list of hostnames
	OU - An Organizational Unit in Active Directory to pull host names from
	test - If present, the script will only display what it would have deleted
	reboot - If present, the system will be rebooted after the updates are made.

-------------------------------------------------------------------------------
.\console.ps1
[Incomplete script!] This is a template for new scripts

Parameters:
	computerName - 
	port - 
	username - 
	password - 

Example:
	.\template.ps1
	This will bring up the new script

-------------------------------------------------------------------------------
.\fileVerification.ps1
This script will generate hashes for submitted folder paths to determine if the files have changed.

Parameters:
	CheckFolder - Folder which needs to be scanned for file changes
	KnownGoodFolder - Optional path to compare a folder against with known good files
	HashAlgorithm - Hashing algorithm to use to compare files.  SHA-1 is the only option on a FIPS compliant system
	reportScans - The number of previous scan results to include in the HTML report output.  Defaults to 10
	ignore - Files extensions to ignore
	executables - Only scan executables (*.exe, *.bat, *.com, *.cmd, and *.dll)
	Recurse - Causes the script to check all subfolders of the given folders.
	Update - The script will automatically correct any mismatches or missing files it finds (use with caution)
	RemoveExtras - The script will remove any extra files found in the CheckFolder
	CopyBackExtras - The script will copy any extra files found in the CheckFolder location back to the KnownGoodFolder location

Example:
	.\fileVerification.ps1 -checkFolder "c:\testFolder" -knownGoodFolder "c:\good" -recurse
	This will compare two folders and generate an xml report

-------------------------------------------------------------------------------
.\findDormantAccounts.ps1
This script will search for and display accounts that have not been logged in for a selected number of days.  This script searches for both local and active directory accounts

Parameters:
	hostCsvPath - The path the a CSV File containing hosts
	computers - A comma separated list of hostnames
	OU - An Organizational Unit in Active Directory to pull host names from
	age - The age that determines an account is dormant
	userOU - An Organization Unit in Active Driectory to pull users from

-------------------------------------------------------------------------------
.\fixDotNet.ps1
This is a script will attempt to fix issues with dot net and certificate issues which prevent windows udpate from installing updates.

Parameters:
	hostCsvPath - The path the a CSV File containing hosts
	computers - A comma separated list of hostnames
	OU - An Organizational Unit in Active Directory to pull host names from
	stig - Whether to set the computer to a STIG approved setting or a known good setting

-------------------------------------------------------------------------------
.\genHelp.ps1
This script generates a document with the help information for all the scripts in the suite.


Example:
	.\genHelp.ps1
	This will create a readme.txt file in the docs folder of the suite and will create the html based api documentation

-------------------------------------------------------------------------------
.\hwSwLists.ps1
This is a script that will pull the hardware and software lists for a list of computers

Parameters:
	hostCsvPath - The path the a CSV File containing hosts
	computers - A comma separated list of hostnames
	OU - An Organizational Unit in Active Directory to pull host names from
	manualExec - Whether of not to auto-execute

-------------------------------------------------------------------------------
.\iavmStatus.ps1
This is a script that will scan computers and determine the status of an IAVM (KB HotFix).  It can accept a single or multiple hosts via AD calls, CSV files and command line parameters

Parameters:
	hostCsvPath - The path the a CSV File containing hosts
	computers - A comma separated list of hostnames
	OU - An Organizational Unit in Active Directory to pull host names from
	IAVM - The KB###### to be scanned for

Example:
	.\iavmStatus.ps1 -computers "ws184894-q03,ws179702-q20" -IAVM "KB982018,KB2979570"
	This example will attempt to scan the computers entered into the command line for the two hotfixes

-------------------------------------------------------------------------------
.\imagePatcher.ps1


-------------------------------------------------------------------------------
.\manageLocalAdmins.ps1
This is a script that will manage the local admins on a machine

Parameters:
	hostCsvPath - The path the a CSV File containing hosts
	computers - A comma separated list of hostnames
	OU - An Organizational Unit in Active Directory to pull host names from
	action - Action to take on the accounts found (List, Delete, Disable, Enable)
	newAdmin - Create a new administrator with the specified username
	newPass - Create a new administrator with the specified password
INPUTS 
There are no inputs that can be directed to this script

-------------------------------------------------------------------------------
.\mergeNessus.ps1
This is a script will merge multiple nessus scan files into one for upload into vram

Parameters:
	scanPath - The path to a folder containing all the scan results
	targetSize - The target size for the uncompressed xml file.  The resultant file is approximately 1/10 the size of this.
	recurse - Whether or not to recurse into the subdirectories

Example:
	.\mergeNessus.ps1 -scanPath ".\scans\"
	This example will merge all the nessus files in the scans directory

-------------------------------------------------------------------------------
.\mineSweeper.ps1
This is a mine sweeper app

Parameters:
	side - The number of cells per side, defaults to 16
	mines - The number of mines to find, defaults to 40
	easy - Sets the game to be an 8x8 grid, with 10 mines to find
	medium - 
	hard - Sets the game to be an 24x24 grid, with 99 mines to find
	expert - Sets the game to be an 32x32 grid, with 150 mines to find

Examples:
	.\minesweeper.ps1
	This example will load the game

	.\minesweeper.ps1 -hard
	This example will load the hard game

-------------------------------------------------------------------------------
.\missingScans.ps1
This is a script that will generate a report showing which hosts have open IAVMs per VRAM

Parameters:
	hostFilePath - 
	hostMapFilePath - The path to a CSV Export from hostMap matching all hosts to their applicable packages.  The csv file must have the following columns (minus the quotes)
'Hostname'
'IPv4 Address'
'MAC Address'
'Package ID'
	logoPath - 

Example:
	.\vram2AcasVulnClass.ps1 -acasFilePath "C:\scans\acasHosts.csv" -vramFilePath "C:\scans\vramAudits.csv" -hostMapFilePath "C:\scans\hostMapPackages.csv"
	This example will generate a report based off the specified csv files

-------------------------------------------------------------------------------
.\packageManager.ps1
[Incomplete script!] This script helps manage DIACAP Package Evidence Submission.


Example:
	.\packageManager.ps1
	This will bring up the packageManager manager console.

-------------------------------------------------------------------------------
.\parseEventlogs.ps1


-------------------------------------------------------------------------------
.\pixelData.ps1
This script returns the pixel color information for a pixel under the mouse cursor.


Example:
	.\pixelData.ps1
	This starts the pixel data tool

-------------------------------------------------------------------------------
.\policyManager.ps1
[Incomplete script!] This is a template for new scripts


Example:
	.\template.ps1
	This will bring up the new script

-------------------------------------------------------------------------------
.\portScan.ps1
[Incomplete script!] This is a template for new scripts

Parameters:
	hostCsvPath - 
	computers - 
	OU - 
	filter - 

Example:
	.\template.ps1
	This will bring up the new script

-------------------------------------------------------------------------------
.\preventSleep.ps1
This is a script will attempt to change the power scheme on a remote computer and prevent sleep.  It can accept a single or multiple hosts via AD calls, CSV files and command line parameters

Parameters:
	hostCsvPath - The path the a CSV File containing hosts
	computers - A comma separated list of hostnames
	OU - An Organizational Unit in Active Directory to pull host names from

Example:
	.\preventSleep.ps1 -computers "hostname1,hostname2"
	This example will attempt to prevent sleep on the computers entered into the command line

-------------------------------------------------------------------------------
.\processManager.ps1
[Incomplete script!] This is a template for new scripts


Example:
	.\template.ps1
	This will bring up the new script

-------------------------------------------------------------------------------
.\restartSystem.ps1
This is a script will attempt to restart systems at a designated time

Parameters:
	hostCsvPath - The path the a CSV File containing hosts
	computers - A comma separated list of hostnames
	OU - An Organizational Unit in Active Directory to pull host names from
	time - The time to restart the system
	type - The shutdown type to use (LogOff, Reboot, ForcedShutdown, etc).

Example:
	.\restratSystem.ps1 -computers "hostname1,hostname2" -type ForcedReboot
	This example will attempt to restart the computers entered into the command line

-------------------------------------------------------------------------------
.\scan4wifiBluetooth.ps1
This is a script will scan for systems that have active bluetooth or wifi adapters

Parameters:
	hostCsvPath - The path the a CSV File containing hosts
	computers - A comma separated list of hostnames
	OU - An Organizational Unit in Active Directory to pull host names from

Example:
	.\scan4wifiBluetooth.ps1 -computers "hostname1,hostname2"
	This example will attempt to prevent sleep on the computers entered into the command line

-------------------------------------------------------------------------------
.\scans2poam.ps1
This is a script will parse scan results and generate an excel POAM.  It can accept StigViewer Checklists, ACAS .Nessus files and SCAP XCCDF files

Parameters:
	ScanLocation - The path to the scan results
	recurse - Whether or not to recurse into the subdirectories for the scanLocation parameter

Example:
	.\scans2poam.ps1 -ScanLocation "C:\scans\" -Recurse
	This example will scan the files in the path listed and save the poam

-------------------------------------------------------------------------------
.\scap2report.ps1
This is a script that will generate a report based on the current SCAP Scans

Parameters:
	ipaPath - 
	scapPath - 
	reset - 
	skip - 
	out - 
	first - 
	selPackage - 

Example:
	.\scap2report.ps1 -acasFilePath "C:\scans\acasHosts.csv" -vramFilePath "C:\scans\vramAudits.csv" -hostMapFilePath "C:\scans\hostMapPackages.csv"
	This example will generate a report based off the specified csv files

-------------------------------------------------------------------------------
.\secureWipe.ps1
This script will securely wipe a user selected hard drive.  It does this by creating a random, temporary file that fills up all the free space on the partition.

Parameters:
	targetPartition - 
	wipeType - 
	arraySize - 
	spaceToLeave - 

Example:
	.\wipe -targetPartition "c:\" -wipeType Random
	This will wipe the c: drive with random data

-------------------------------------------------------------------------------
.\server.ps1


-------------------------------------------------------------------------------
.\serviceQuotes.ps1
This is a script that will analyze a list of hosts and ensure all services with spaces are properly quoted

Parameters:
	hostCsvPath - The path to a csv file with hosts listed
	computers - A parameter of comman separated host names
	OU - An ou to pull hosts from
	test - Whether to only test run, or to actually execute

Example:
	.\serviceQuotes.ps1 -computers "host1,host2,host3"
	This example will udpate the hosts found in the hosts parameter

-------------------------------------------------------------------------------
.\setup.ps1
[Incomplete script!] This is a template for new scripts

Parameter:
	reload - 

Example:
	.\template.ps1
	This will bring up the new script

-------------------------------------------------------------------------------
.\setWallpaper.ps1
[ALPHA LEVEL SCRIPT!] This is a script that will set the users wallpaper to be a data dump of pertinent host information like hostname, disk usage and logon times.

Parameters:
	Color - The color to set the background to.  Defaults to CornflourBlue
	class - 

Examples:
	.\setWallpaper.ps1
	This example will set the background to cornFlourBlue and dump the system information in white text

	.\setWallpaper.ps1 -color red
	This example will set the background to red and dump the system information in white text

-------------------------------------------------------------------------------
.\software2stig.ps1
This is a script that will scan computers and determine which STIGs need to be executed.  It can accept a single or multiple hosts via AD calls, CSV files and command line parameters

Parameters:
	hostCsvPath - The path the a CSV File containing hosts
	computers - A comma separated list of hostnames
	OU - An Organizational Unit in Active Directory to pull host names from

Example:
	.\software2stig.ps1 -computers "hostname1,hostname2"
	This example will attempt to scan the computers entered into the command line

-------------------------------------------------------------------------------
.\stig2gpo.ps1
This is a script will parse either a STIG or SCAP Results and generate a GPO.  It can accept either STIG or SCAP XCCDF/OVAL files

Parameters:
	profile - which profile, if any, should be selected from the STIG
	xccdfPath - The path to the XCCDF being parsed
	ovalPath - The path to the OVAL being parsed

Example:
	.\stig2gpo.ps1 -xccdfPath "C:\stigs\U_Windows_7_V1R22_STIG_Benchmark-xccdf.xml" -ovalPath "C:\stigs\U_Windows_7_V1R22_STIG_Benchmark-oval.xml"
	This example will parse the files in the path listed and save the gpo

-------------------------------------------------------------------------------
.\stigWindows.ps1
This is a script that will apply the Non-GPO settings to STIG the asset.  It can accept a single or multiple hosts via AD calls, CSV files and command line parameters

Parameters:
	hostCsvPath - The path the a CSV File containing hosts
	computers - A comma separated list of hostnames
	OU - An Organizational Unit in Active Directory to pull host names from
	skip - STIG Steps that do not need to be completed
	test - Only execute specified STIG Steps (opposite of skip)

Example:
	.\stigWin7.ps1 -computers "hostname1,hostname2"
	This example will stig the computers entered into the command line

-------------------------------------------------------------------------------
.\systemManager.ps1
[Incomplete script!] This is a template for new scripts


Example:
	.\template.ps1
	This will bring up the new script

-------------------------------------------------------------------------------
.\template.ps1
[Incomplete script!] This is a template for new scripts


Example:
	.\template.ps1
	This will bring up the new script

-------------------------------------------------------------------------------
.\updateHosts.ps1
This is a script that will execute updates on a list of hosts

Parameters:
	hostCsvPath - The path the a CSV File containing hosts
	computers - A comma separated list of hostnames
	OU - An Organizational Unit in Active Directory to pull host names from
	cmd - A command to execute on the remote hosts
	winrm - Enabled Windows Remoting on the remote host
	audit - Fix Audit settings on remote host
	gpupdate - Force remote system to process a gupdate -force
	acas - Try to update the host to get ACAS Credentialed scans working
	office - Renamed user profiles to 'profile.old' in an effort to correct the MS Office SCAP Benchmarks
	win10 - Prevent the windows 10 upgrade from being enabled on the remote host
	hideKB - Prevent a windows KB from being installed
	showKB - Allow a previously hidden windows KB to be installed
	kb - The KB referenced in the show and hide parameters

-------------------------------------------------------------------------------
.\updateStig.ps1
This Script is designed to make updating to a new STIG Checklist 
   version faster and easier.  It will move the asset data and all comments,
   finding details, status, severity override and justifications from the
   oldFile to the newFile.  The Script assumes that the vulnerability ids
   are consistent from file to file.  It does not perform any checking for
   STIG items which may have been updated between versions and that will
   still need to be performed manually.  
   Before running this script, the DISA STIG Viewer must be used to save a
   new .ckl file with the new version of the STIG.

   WARNING: It is highly recommended that you use a copy of the old file.  
   this script has no sanity checking and will happily copy nothing back into 
   the old file from the new file if they are listed backwards in the command.

Parameters:
	oldFile - The original Stig Checklist file (.ckl) which contains the comments, etc.
	newFile - The new, empty Stig file (.ckl) which is to receive the comments, etc.

Example:
	.\CopyToNewSTIG.ps1 -oldFile C:\Users\john.laska\Desktop\uRDTE_Application_Security_and_Development_STIG_V3R9.ckl -newFile C:\Users\john.laska\Desktop\uRDTE_Application_Security_and_Development_STIG_V3R10.ckl
	This would copy all of the data from the file for V3R9 to the file for V3R10

-------------------------------------------------------------------------------
.\userCount.ps1
[Incomplete script!] This is a template for new scripts

Parameters:
	ou - 
	cOu - 
	uOu - 

Example:
	.\template.ps1
	This will bring up the new script

-------------------------------------------------------------------------------
.\vram2AcasScanPolicy.ps1
This script will create an ACAS Scan Policy for the audits that VRAM needs input from

Parameter:
	auditPath - The path to the VRAM Audits (csv format)

Example:
	.\vram2AcasScanPolicy.ps1 -auditPath "c:\audits.csv"
	This example will clean the designated path

-------------------------------------------------------------------------------
.\vram2acasVulnerabilities.ps1
This is a script that will generate a report showing which hosts have open IAVMs per VRAM

Parameters:
	acasFilePath - The path to a CSV export from ACAS of all open findings for the department
	vramFilePath - The path to a CSV Export from VRAM showing all audits with their applicable ACAS Plugin Ids
	hostMapFilePath - The path to a CSV Export from hostMap matching all hosts to their applicable packages.  The csv file must have the following columns (minus the quotes)
'Hostname'
'IPv4 Address'
'MAC Address'
'Package ID'
	logoPath - 
	repository - 

Example:
	.\vram2AcasVulnClass.ps1 -acasFilePath "C:\scans\acasHosts.csv" -vramFilePath "C:\scans\vramAudits.csv" -hostMapFilePath "C:\scans\hostMapPackages.csv"
	This example will generate a report based off the specified csv files

-------------------------------------------------------------------------------
.\wakeOnLan.ps1
This is a script will attempt to wake up computers via network calls.  It can accept a single or multiple hosts via AD calls, CSV files and command line parameters

Parameters:
	hostCsvPath - The path the a CSV File containing hosts
	computers - A comma separated list of hostnames
	OU - An Organizational Unit in Active Directory to pull host names from

Example:
	.\wakeOnLan.ps1 -computers "hostname1,hostname2"
	This example will attempt to wake up the computers entered into the command line

-------------------------------------------------------------------------------
.\wsusOffline.ps1
This script will create DVD ISOs with all windows update patches installed.

Parameters:
	reDownload - If present, patches will be redownloaded even if they have been previously downloaded
	threads - The number of threads to be made available for file downloads.  Defaults to 10
	refreshDays - How old should the microsoft CAB file be kept before forcing new downloads

Examples:
	.\wsusOffline.ps1
	This example will create update ISO images for all supported windows products

	.\wsusOffline.ps1 -reDownload -threads 15
	This example will create update ISO images for all supported windows products by redownloading all patches and utilizing 15 download streams

