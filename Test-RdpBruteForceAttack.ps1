param(
	[string]$publicIpAddress,
	[int]$numLoginAttempts
)

function Test-Port
{
	Param(
		$address,
		$port,
		$timeout = 2000
	)
	$socket = New-Object System.Net.Sockets.TcpClient
	try
	{
		$result = $socket.BeginConnect($address, $port, $NULL, $NULL)
		if (!$result.AsyncWaitHandle.WaitOne($timeout, $False))
		{
			throw [System.Exception]::new('Connection Timeout')
		}
		$socket.EndConnect($result) | Out-Null
		$socket.Connected
	}
	finally
	{
		$socket.Close()
	}
}

function Connect-Mstsc
{
	<#
	.SYNOPSIS
	Function to connect an RDP session without the password prompt

	.DESCRIPTION
	This function provides the functionality to start an RDP session without having to type in the password

	.PARAMETER ComputerName
	This can be a single computername or an array of computers to which RDP session will be opened

	.PARAMETER User
	The user name that will be used to authenticate

	.PARAMETER Password
	The password that will be used to authenticate

	.PARAMETER Credential
	The PowerShell credential object that will be used to authenticate against the remote system

	.PARAMETER Admin
	Sets the /admin switch on the mstsc command: Connects you to the session for administering a server

	.PARAMETER MultiMon
	Sets the /multimon switch on the mstsc command: Configures the Remote Desktop Services session monitor layout to be identical to the current client-side configuration

	.PARAMETER FullScreen
	Sets the /f switch on the mstsc command: Starts Remote Desktop in full-screen mode

	.PARAMETER Public
	Sets the /public switch on the mstsc command: Runs Remote Desktop in public mode

	.PARAMETER Width
	Sets the /w:<width> parameter on the mstsc command: Specifies the width of the Remote Desktop window

	.PARAMETER Height
	Sets the /h:<height> parameter on the mstsc command: Specifies the height of the Remote Desktop window

	.NOTES
	Name:        Connect-Mstsc
	Author:      Jaap Brasser
	DateUpdated: 2016-10-28
	Version:     1.2.5
	Blog:        http://www.jaapbrasser.com

	.LINK
	http://www.jaapbrasser.com

	.EXAMPLE
	. .\Connect-Mstsc.ps1

	Description
	-----------
	This command dot sources the script to ensure the Connect-Mstsc function is available in your current PowerShell session

	.EXAMPLE
	Connect-Mstsc -ComputerName server01 -User contoso\jaapbrasser -Password (ConvertTo-SecureString 'supersecretpw' -AsPlainText -Force)

	Description
	-----------
	A remote desktop session to server01 will be created using the credentials of contoso\jaapbrasser

	.EXAMPLE
	Connect-Mstsc server01,server02 contoso\jaapbrasser (ConvertTo-SecureString 'supersecretpw' -AsPlainText -Force)

	Description
	-----------
	Two RDP sessions to server01 and server02 will be created using the credentials of contoso\jaapbrasser

	.EXAMPLE
	server01,server02 | Connect-Mstsc -User contoso\jaapbrasser -Password (ConvertTo-SecureString 'supersecretpw' -AsPlainText -Force) -Width 1280 -Height 720

	Description
	-----------
	Two RDP sessions to server01 and server02 will be created using the credentials of contoso\jaapbrasser and both session will be at a resolution of 1280x720.

	.EXAMPLE
	server01,server02 | Connect-Mstsc -User contoso\jaapbrasser -Password (ConvertTo-SecureString 'supersecretpw' -AsPlainText -Force) -Wait

	Description
	-----------
	RDP sessions to server01 will be created, once the mstsc process is closed the session next session is opened to server02. Using the credentials of contoso\jaapbrasser and both session will be at a resolution of 1280x720.

	.EXAMPLE
	Connect-Mstsc -ComputerName server01:3389 -User contoso\jaapbrasser -Password (ConvertTo-SecureString 'supersecretpw' -AsPlainText -Force) -Admin -MultiMon

	Description
	-----------
	A RDP session to server01 at port 3389 will be created using the credentials of contoso\jaapbrasser and the /admin and /multimon switches will be set for mstsc

	.EXAMPLE
	Connect-Mstsc -ComputerName server01:3389 -User contoso\jaapbrasser -Password (ConvertTo-SecureString 'supersecretpw' -AsPlainText -Force) -Public

	Description
	-----------
	A RDP session to server01 at port 3389 will be created using the credentials of contoso\jaapbrasser and the /public switches will be set for mstsc

	.EXAMPLE
	Connect-Mstsc -ComputerName 192.168.1.10 -Credential $Cred

	Description
	-----------
	A RDP session to the system at 192.168.1.10 will be created using the credentials stored in the $cred variable.

	.EXAMPLE
	Get-AzureVM | Get-AzureEndPoint -Name 'Remote Desktop' | ForEach-Object { Connect-Mstsc -ComputerName ($_.Vip,$_.Port -join ':') -User contoso\jaapbrasser -Password (ConvertTo-SecureString 'supersecretpw' -AsPlainText -Force) }

	Description
	-----------
	A RDP session is started for each Azure Virtual Machine with the user contoso\jaapbrasser and password supersecretpw

	.EXAMPLE
	PowerShell.exe -Command "& {. .\Connect-Mstsc.ps1; Connect-Mstsc server01 contoso\jaapbrasser (ConvertTo-SecureString 'supersecretpw' -AsPlainText -Force) -Admin}"

	Description
	-----------
	An remote desktop session to server01 will be created using the credentials of contoso\jaapbrasser connecting to the administrative session, this example can be used when scheduling tasks or for batch files.
	#>
	[cmdletbinding(SupportsShouldProcess, DefaultParametersetName = 'UserPassword')]
	param (
		[Parameter(Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true,
			Position = 0)]
		[Alias('CN')]
		[string[]]     $ComputerName,
		[Parameter(ParameterSetName = 'UserPassword', Mandatory = $true, Position = 1)]
		[Alias('U')]
		[string]       $User,
		[Parameter(ParameterSetName = 'UserPassword', Mandatory = $true, Position = 2)]
		[Alias('P')]
		[string]       $Password,
		[Parameter(ParameterSetName = 'Credential', Mandatory = $true, Position = 1)]
		[Alias('C')]
		[PSCredential] $Credential,
		[Alias('A')]
		[switch]       $Admin,
		[Alias('MM')]
		[switch]       $MultiMon,
		[Alias('F')]
		[switch]       $FullScreen,
		[Alias('Pu')]
		[switch]       $Public,
		[Alias('W')]
		[int]          $Width,
		[Alias('H')]
		[int]          $Height,
		[Alias('WT')]
		[switch]       $Wait
	)

	begin
	{
		[string]$MstscArguments = ''
		switch ($true)
		{
			{$Admin} {$MstscArguments += '/admin '}
			{$MultiMon} {$MstscArguments += '/multimon '}
			{$FullScreen} {$MstscArguments += '/f '}
			{$Public} {$MstscArguments += '/public '}
			{$Width} {$MstscArguments += "/w:$Width "}
			{$Height} {$MstscArguments += "/h:$Height "}
		}

		if ($Credential)
		{
			$User = $Credential.UserName
			$Password = $Credential.GetNetworkCredential().Password
		}
	}
	process
	{
		foreach ($Computer in $ComputerName)
		{

			# Remove the port number for CmdKey otherwise credentials are not entered correctly
			if ($Computer.Contains(':'))
			{
				$ComputerCmdkey = ($Computer -split ':')[0]
			}
			else
			{
				$ComputerCmdkey = $Computer
			}

			$cmdKeyProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
			$cmdKeyProcess = New-Object System.Diagnostics.Process

			#$cmdKeyProcessInfo.RedirectStandardError = $true
			$cmdKeyProcessInfo.RedirectStandardOutput = $true
			$cmdKeyProcessInfo.UseShellExecute = $false
			$cmdKeyProcessInfo.FileName = "$($env:SystemRoot)\system32\cmdkey.exe"
			$cmdKeyProcessInfo.Arguments = "/generic:TERMSRV/$ComputerCmdkey /user:$User /pass:$($Password)"
			$cmdKeyProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
			$cmdKeyProcess.StartInfo = $cmdKeyProcessInfo
			if ($PSCmdlet.ShouldProcess($ComputerCmdkey, 'Adding credentials to store'))
			{
				[void]$cmdKeyProcess.Start()
			}

			$mstscProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
			$mstscProcess = New-Object System.Diagnostics.Process

			$mstscProcessInfo.FileName = "$($env:SystemRoot)\system32\mstsc.exe"
			$mstscProcessInfo.Arguments = "$MstscArguments /v $Computer"
			$mstscProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
			$mstscProcess.StartInfo = $mstscProcessInfo
			if ($PSCmdlet.ShouldProcess($Computer, 'Connecting mstsc'))
			{
				[void]$mstscProcess.Start()
				if ($Wait)
				{
					$null = $mstscProcess.WaitForExit(500)
				}
			}
		}
	}
}

$port = 3389

if (Test-Port -address $publicIpAddress -port $port -timeout 1000)
{
	Write-Output "Successfully port pinged port $port at $publicIpAddress"
}
else
{
	Write-Output "Failed to port ping port $port at $publicIpAddress"
	exit
}

$existingMstscProcesses = Get-Process -Name mstsc

$computerName = "$($publicIpAddress):$($port)"

for ($i = 0; $i -lt $numLoginAttempts; $i++)
{
	$userName = -join ((65..90) + (97..122) | Get-Random -Count 8 | ForEach-Object {[char]$_})
	$password = $userName
	Connect-Mstsc -ComputerName $computerName -User $userName -Password $password -Admin -Wait
	Write-Output "$($i+1) of $numLoginAttempts login attempts completed"
}

Get-Process -Name mstsc | Where-Object {$_.Id -notin $existingMstscProcesses.Id} | Stop-Process -Force