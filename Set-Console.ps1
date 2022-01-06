param(
	[switch]$UpdateShortcuts = $true, # Change to $true for shortcuts (.lnk) to be updated in addition to the registry changes. Creates backups (*.lnk.bak) before changing the existing shortcut.
	[switch]$KeepBackupShortcuts = $false, # If $true, keeps the backup *.lnk.bak. If $false, removes the backup *.lnk.bak file.
	[int]$fontSize = 18
)

function Set-DefaultTerminalApp
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "WindowsTerminal"
		)]
		[switch]
		$WindowsTerminal,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "ConsoleHost"
		)]
		[switch]
		$ConsoleHost
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"WindowsTerminal"
		{
			if (Get-AppxPackage -Name Microsoft.WindowsTerminal)
			{
				if (-not (Test-Path -Path "HKCU:\Console\%%Startup"))
				{
					New-Item -Path "HKCU:\Console\%%Startup" -Force
				}

				# Find the current GUID of Windows Terminal
				$PackageFullName = (Get-AppxPackage -Name Microsoft.WindowsTerminal).PackageFullName
				Get-ChildItem -Path "HKLM:\SOFTWARE\Classes\PackagedCom\Package\$PackageFullName\Class" | ForEach-Object -Process {
					if ((Get-ItemPropertyValue -Path $_.PSPath -Name ServerId) -eq 0)
					{
						New-ItemProperty -Path "HKCU:\Console\%%Startup" -Name DelegationConsole -PropertyType String -Value $_.PSChildName -Force
					}

					if ((Get-ItemPropertyValue -Path $_.PSPath -Name ServerId) -eq 1)
					{
						New-ItemProperty -Path "HKCU:\Console\%%Startup" -Name DelegationTerminal -PropertyType String -Value $_.PSChildName -Force
					}
				}
			}
		}
		"ConsoleHost"
		{
			New-ItemProperty -Path "HKCU:\Console\%%Startup" -Name DelegationConsole -PropertyType String -Value "{00000000-0000-0000-0000-000000000000}" -Force
			New-ItemProperty -Path "HKCU:\Console\%%Startup" -Name DelegationTerminal -PropertyType String -Value "{00000000-0000-0000-0000-000000000000}" -Force
		}
	}
}

Set-DefaultTerminalApp -WindowsTerminal

# https://renenyffenegger.ch/notes/Windows/registry/tree/HKEY_CURRENT_USER/console/index

$fontSize = $fontSize * 65536

$settings = @{
"2560x1440 windowsize" = 0x4b00e6;
"2560x1440 buffersize" = 0xbb800e6;
"1920x1200 windowsize" = 0x3e00ab;
"1920x1200 buffersize" = 0xbb800ab;
"1920x1080 windowsize" = 0x3700ac;
"1920x1080 buffersize" = 0xbb800ac;
"1680x1050 windowsize" = 0x360096;
"1680x1050 buffersize" = 0xbb80096;
"1600x1200 windowsize" = 0x3e008f;
"1600x1200 buffersize" = 0xbb8008f;
"1600x900 windowsize"  = 0x2d008f;
"1600x900 buffersize"  = 0xbb8008f;
"1440x900 windowsize"  = 0x2d0080;
"1440x900 buffersize"  = 0xbb80080;
"1366x768 windowsize"  = 0x260079;
"1366x768 buffersize"  = 0xbb80079;
"1280x1024 windowsize" = 0x340071;
"1280x1024 buffersize" = 0xbb80071;
"1152x864 windowsize"  = 0x2b0066;
"1152x864 buffersize"  = 0xbb80066;
"1024x768 windowsize"  = 0x26005a;
"1024x768 buffersize"  = 0xbb8005a;
"800x600 windowsize"   = 0x1d0046;
"800x600 buffersize"   = 0xbb80046;
"FaceName"             = "Lucida Console";
"FontFamily"           = 0x36;
"FontSize"             = $fontSize;
"FontWeight"           = 0x190;
"HistoryBufferSize"    = 0x32;
"HistoryNoDup"         = 0x1;
"InsertMode"           = 0x1;
"QuickEdit"            = 0x1;
"ScreenColors"         = 0x7;
"WindowPosition"       = 0x0;
"PSColorTable00"       = 0x562401;
"PSColorTable07"       = 0xf0edee;
"CMDColorTable00"      = 0x0;
"CMDColorTable07"      = 0xc0c0c0;
}

# HKCU\Console has the default values, and HCKU\Console\<window title> has settings for a console window with that window title.
# These values are not used if a shortcut (.lnk) file itself has console settings defined in it.

$paths = @(`
"HKCU:Console",`
"HKCU:Console\Command Prompt",`
"HKCU:Console\%SystemRoot%_system32_cmd.exe",`
"HKCU:Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe",`
"HKCU:Console\%SystemRoot%_SysWOW64_WindowsPowerShell_v1.0_powershell.exe",`
"HKCU:Console\Windows PowerShell (x86)",`
"HKCU:Console\Windows PowerShell",`
"HKCU:Console\C:_Program Files_PowerShell_7-preview_pwsh.exe"
"HKCU:Console\C:_Program Files_PowerShell_7_pwsh.exe"
)

# Settings in a shortcut override settings in the registry
# Since there is no way to edit the console settings in an existing shortcut,
# the simplest way is to delete the existing one, create a new one, and it will use the registry settings
# By default, the script will first backup the existing shortcuts, if they exist, before creating a new one.

$shortcuts = @(`
"$ENV:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\PowerShell\PowerShell 7-preview (x64).lnk",`
"$ENV:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\PowerShell\PowerShell 7 (x64).lnk",`
"$ENV:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Windows PowerShell.lnk",`
"$ENV:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Windows PowerShell (x86).lnk",`
"$ENV:ALLUSERSPROFILE\Start Menu\Programs\Accessories\Windows PowerShell\Windows PowerShell.lnk",`
"$ENV:ALLUSERSPROFILE\Start Menu\Programs\Accessories\Windows PowerShell\Windows PowerShell (x86).lnk",`
"$ENV:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Accessories\Windows PowerShell\Windows PowerShell.lnk",`
"$ENV:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Accessories\Windows PowerShell\Windows PowerShell (x86).lnk",`
"$ENV:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\System Tools\Windows PowerShell.lnk",`
"$ENV:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk",`
"$ENV:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell (x86).lnk",`
"$ENV:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\System Tools\Command Prompt.lnk",`
"$ENV:USERPROFILE\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\StartMenu\Windows PowerShell.lnk",`
"$ENV:USERPROFILE\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Windows PowerShell.lnk",`
"$ENV:USERPROFILE\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\StartMenu\Command Prompt.lnk",`
"$ENV:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Accessories\Command Prompt.lnk",`
"$ENV:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk",`
"$ENV:SYSTEMDRIVE\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk",`
"$ENV:SYSTEMDRIVE\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk",`
"$ENV:SYSTEMDRIVE\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell (x86).lnk",`
"$ENV:SYSTEMDRIVE\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\System Tools\Command Prompt.lnk"
)

# Unlike some other methods, this method will get the correct screen resolution even in an RDP session.
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
$resolution = ([string][Windows.Forms.Screen]::PrimaryScreen.Bounds.Width + "x" + [string][Windows.Forms.Screen]::PrimaryScreen.Bounds.Height)

Write-Host "`nResolution:  $resolution"
If ($settings."$resolution windowsize" -eq $null)
{
    Write-Host "There are no settings defined for this resolution. Defaulting to values for 1366x768."
    $resolution = "1366x768"
}

# Create the registry keys if they do not exist
$paths | ForEach-Object {
	If (!(Test-Path -Path $_))
	{
		"`nCreating key $_"
        New-Item -path $_ -ItemType Registry -Force | Out-Null
	}
}

# Set console settings in the registry
$paths | ForEach-Object {

	# Configure window size and buffer size registry values based on values defined earlier in the script
    Write-Host "`n$_"
    Write-Host ("`tWindowSize = " + $settings."$resolution windowsize")
    Write-Host ("`tScreenBufferSize = " + $settings."$resolution buffersize")

    New-ItemProperty -Path $_ -Name WindowSize -Value $settings."$resolution windowsize" -PropertyType DWORD -Force | Out-Null
	New-ItemProperty -Path $_ -Name ScreenBufferSize -Value $settings."$resolution buffersize" -PropertyType DWORD -Force | Out-Null

	if ($_ -match "PowerShell")
	{
		# Configure PowerShell windows to use default white text on blue background
        Write-Host "`n$_"
        Write-Host "`tColorTable00 =" $settings.PSColorTable00
        Write-Host "`tColorTable07 =" $settings.PSColorTable07

        New-ItemProperty -Path $_ -Name ColorTable00 -Value $settings.PSColorTable00 -PropertyType DWORD -Force | Out-Null
		New-ItemProperty -Path $_ -Name ColorTable07 -Value $settings.PSColorTable07 -PropertyType DWORD -Force | Out-Null
	}
	else
	{
		# Configures CMD windows to use default white text on black background
        Write-Host "`n$_"
        Write-Host "`tColorTable00 =" $settings.CMDColorTable00
        Write-Host "`tColorTable07 =" $settings.CMDColorTable07

        New-ItemProperty -Path $_ -Name ColorTable00 -Value $settings.CMDColorTable00 -PropertyType DWORD -Force | Out-Null
		New-ItemProperty -Path $_ -Name ColorTable07 -Value $settings.CMDColorTable07 -PropertyType DWORD -Force | Out-Null
	}

	# Configure font, window position, history buffer, insert mode and quickedit
	Write-Host "`n$_"
    Write-Host "`tFaceName =" $settings.FaceName
    Write-Host "`tFontFamily =" $settings.FontFamily
    Write-Host "`tFontSize =" $settings.FontSize
    Write-Host "`tFontWeight =" $settings.FontWeight
    Write-Host "`tHistoryBufferSize =" $settings.HistoryBufferSize
    Write-Host "`tHistoryNoDup =" $settings.HistoryNoDup
    Write-Host "`tInsertMode =" $settings.InsertMode
    Write-Host "`tQuickEdit =" $settings.QuickEdit
	Write-Host "`tScreenColors =" $settings.ScreenColors
    Write-Host "`tWindowPosition =" $settings.WindowPosition

	New-ItemProperty -Path $_ -Name FaceName -Value $settings.FaceName -Force | Out-Null
	New-ItemProperty -Path $_ -Name FontFamily -Value $settings.FontFamily -PropertyType DWORD -Force | Out-Null
	New-ItemProperty -Path $_ -Name FontSize -Value $settings.FontSize -PropertyType DWORD -Force | Out-Null
	New-ItemProperty -Path $_ -Name FontWeight -Value $settings.FontWeight -PropertyType DWORD -Force | Out-Null
	New-ItemProperty -Path $_ -Name HistoryBufferSize -Value $settings.HistoryBufferSize -PropertyType DWORD -Force | Out-Null
	New-ItemProperty -Path $_ -Name HistoryNoDup -Value $settings.HistoryNoDup -PropertyType DWORD -Force | Out-Null
	New-ItemProperty -Path $_ -Name InsertMode -Value $settings.InsertMode -PropertyType DWORD -Force | Out-Null
	New-ItemProperty -Path $_ -Name QuickEdit -Value $settings.QuickEdit -PropertyType DWORD -Force | Out-Null
	New-ItemProperty -Path $_ -Name ScreenColors -Value $settings.ScreenColors -PropertyType DWORD -Force | Out-Null
	New-ItemProperty -Path $_ -Name WindowPosition -Value $settings.WindowPosition -PropertyType DWORD -Force | Out-Null
}

$objShell = New-Object -comobject Wscript.Shell

If ($UpdateShortcuts)
{
	$shortcuts | ForEach-Object {

		If (Test-Path -Path $_)
		{
			# Copy instead of rename as renaming creates orphaned Start Menu/Taskbar links
			Write-Host "`nBackup: $_.bak"
			Copy-Item -Path $_ -Destination "$_.bak" -Force

			# If $BackupShortcuts is true, check that the backup was created before removing the existing one
			Write-Host "Remove: $_"
			Remove-Item -Path $_ -Force

			Write-Host "Create: $_"
			$shortCut = $objShell.CreateShortCut($_)

			if ($_.EndsWith('PowerShell 7 (x64).lnk'))
	        {
	            $shortCut.Description = "PowerShell 7 (x64)"
		    	$shortCut.TargetPath  = "%ProgramFiles%\PowerShell\7\pwsh.exe"
	            $shortCut.Arguments   = "-NoLogo"
	        }
			elseif ($_.EndsWith('PowerShell 7-preview (x64).lnk'))
	        {
	            $shortCut.Description = "PowerShell 7-preview (x64)"
		    	$shortCut.TargetPath  = "%ProgramFiles%\PowerShell\7-preview\pwsh.exe"
	            $shortCut.Arguments   = "-NoLogo"
	        }
			elseif ($_.EndsWith('Windows PowerShell.lnk'))
	        {
	            $shortCut.Description = "Windows PowerShell"
		    	$shortCut.TargetPath  = "%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe"
	            $shortCut.Arguments   = "-NoLogo"
	        }
			elseif ($_.EndsWith('Windows PowerShell (x86).lnk'))
	        {
	            $shortCut.Description = "Windows PowerShell (x86)"
		    	$shortCut.TargetPath  = "%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
	            $shortCut.Arguments   = "-NoLogo"
	        }
			elseif ($_.EndsWith('Command Prompt.lnk'))
	        {
	            $shortCut.Description = "Command Prompt"
		    	$shortCut.TargetPath  = "%windir%\system32\cmd.exe"
	        }

			$shortCut.WindowStyle      = 1 # 1 = Normal
			$shortCut.Save()

			If ($KeepBackupShortcuts -eq $false)
			{
				If (Test-Path -Path "$_.bak")
				{
					Write-Host "Remove: $_.bak"
					Remove-Item -Path "$_.bak" -Force
				}
			}
		}
	}
}
