function Get-Age
{
	param(
		[datetime]$start,
		[datetime]$end = (Get-Date)
	)

	$timespan = New-TimeSpan -Start $start -End $end
	$years = [Math]::Round($timespan.Days / 365, 1)
	$months = [Math]::Round($timespan.Days / 30, 1)
	$days = $timespan.Days
	$hours = $timespan.Hours
	$minutes = $timespan.Minutes
	$seconds = $timespan.Seconds

	if ($years -gt 1)
	{
		$age = "$years years"
	}
	elseif ($years -eq 1)
	{
		$age = "$years year"
	}
	elseif ($months -gt 1)
	{
		$age = "$months months"
	}
	elseif ($months -eq 1)
	{
		$age = "$months month"
	}
	elseif ($days -gt 1)
	{
		$age = "$days days"
	}
	elseif ($days -eq 1)
	{
		$age = "$days day"
	}
	elseif ($hours -gt 1)
	{
		$age = "$hours hrs"
	}
	elseif ($hours -eq 1)
	{
		$age = "$hours hr"
	}
	elseif ($minutes -gt 1)
	{
		$age = "$minutes mins"
	}
	elseif ($minutes -eq 1)
	{
		$age = "$minutes min"
	}
	elseif ($seconds -gt 1)
	{
		$age = "$seconds secs"
	}
	elseif ($seconds -eq 1)
	{
		$age = "$seconds sec"
	}

	if ($age)
	{
		return $age
	}
}

Function Get-RegKeyInfo {
    <#
    .SYNOPSIS
    Gets details about a registry key.

    .DESCRIPTION
    Gets very low level details about a registry key.

    .PARAMETER Path
    The path to the registry key to get the details for. This should be a string with the hive and key path split by
    ':', e.g. HKLM:\Software\Microsoft, HKEY_CURRENT_USER:\Console, etc. The Hive can be in the short form like HKLM or
    the long form HKEY_LOCAL_MACHINE.

    .EXAMPLE
    Get-RegKeyInfo -Path HKLM:\SYSTEM\CurrentControlSet
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [String[]]
        $Path
    )

    begin {
		if ([bool]([System.Management.Automation.PSTypeName]'Registry.Key').Type -eq $false)
		{
        Add-Type -TypeDefinition @'
using Microsoft.Win32.SafeHandles;
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

namespace Registry
{
    internal class NativeHelpers
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct KEY_BASIC_INFORMATION
        {
            public Int64 LastWriteTime;
            public UInt32 TitleIndex;
            public Int32 NameLength;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 1)] public char[] Name;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct KEY_FLAGS_INFORMATION
        {
            // This struct isn't really documented and most of the snippets online just show the UserFlags field. For
            // whatever reason it seems to be 12 bytes in size with the flags in the 2nd integer value. The others I
            // have no idea what they are for.
            public UInt32 Reserved1;
            public KeyFlags UserFlags;
            public UInt32 Reserved2;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct KEY_FULL_INFORMATION
        {
            public Int64 LastWriteTime;
            public UInt32 TitleIndex;
            public Int32 ClassOffset;
            public Int32 ClassLength;
            public Int32 SubKeys;
            public Int32 MaxNameLen;
            public Int32 MaxClassLen;
            public Int32 Values;
            public Int32 MaxValueNameLen;
            public Int32 MaxValueDataLen;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 1)] public char[] Class;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct KEY_HANDLE_TAGS_INFORMATION
        {
            public UInt32 HandleTags;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct KEY_LAYER_INFORMATION
        {
            public UInt32 IsTombstone;
            public UInt32 IsSupersedeLocal;
            public UInt32 IsSupersedeTree;
            public UInt32 ClassIsInherited;
            public UInt32 Reserved;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct KEY_TRUST_INFORMATION
        {
            public UInt32 TrustedKey;
            public UInt32 Reserved;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct KEY_VIRTUALIZATION_INFORMATION
        {
            public UInt32 VirtualizationCandidate;
            public UInt32 VirtualizationEnabled;
            public UInt32 VirtualTarget;
            public UInt32 VirtualStore;
            public UInt32 VirtualSource;
            public UInt32 Reserved;
        }

        public enum KeyInformationClass : uint
        {
            Basic = 0,
            Node = 1,
            Full = 2,
            Name = 3,
            Cached = 4,
            Flags = 5,
            Virtualization = 6,
            HandleTags = 7,
            Trust = 8,
            Layer = 9,
        }
    }

    internal class NativeMethods
    {
        [DllImport("NtDll.dll")]
        public static extern UInt32 NtQueryKey(
            SafeHandle KeyHandle,
            NativeHelpers.KeyInformationClass KeyInformationClass,
            IntPtr KeyInformation,
            Int32 Length,
            out Int32 ResultLength
        );

        [DllImport("Advapi32.dll", CharSet = CharSet.Unicode)]
        public static extern Int32 RegOpenKeyExW(
            SafeHandle hKey,
            string lpSubKey,
            KeyOptions ulOptions,
            KeyAccessRights samDesired,
            out SafeRegistryHandle phkResult
        );

        [DllImport("NtDll.dll")]
        public static extern Int32 RtlNtStatusToDosError(
            UInt32 Status
        );
    }

    internal class SafeMemoryBuffer : SafeHandleZeroOrMinusOneIsInvalid
    {
        public SafeMemoryBuffer() : base(true) { }
        public SafeMemoryBuffer(int cb) : base(true)
        {
            base.SetHandle(Marshal.AllocHGlobal(cb));
        }
        public SafeMemoryBuffer(IntPtr handle) : base(true)
        {
            base.SetHandle(handle);
        }

        protected override bool ReleaseHandle()
        {
            Marshal.FreeHGlobal(handle);
            return true;
        }
    }

    [Flags]
    public enum KeyAccessRights : uint
    {
        QueryValue = 0x00000001,
        SetValue = 0x00000002,
        CreateSubKey = 0x00000004,
        EnumerateSubKeys = 0x00000008,
        Notify = 0x00000010,
        CreateLink = 0x00000020,
        Wow6464Key = 0x00000100,
        Wow6432Key = 0x00000200,

        Delete = 0x00010000,
        ReadControl = 0x00020000,
        WriteDAC = 0x00040000,
        WriteOwner = 0x00080000,
        StandardRightsRequired = Delete | ReadControl | WriteDAC | WriteOwner,
        AccessSystemSecurity = 0x01000000,

        Read = ReadControl | QueryValue | EnumerateSubKeys | Notify,
        Execute = Read,
        Write = ReadControl | SetValue | CreateSubKey,
        AllAccess = StandardRightsRequired | 0x3F
    }

    [Flags]
    public enum KeyFlags : uint
    {
        None = 0x00000000,
        Volatile = 0x00000001,
        Symlink = 0x00000002,
    }

    [Flags]
    public enum KeyOptions : uint
    {
        None = 0x00000000,
        Volatile = 0x00000001,
        CreateLink = 0x00000002,
        BackupRestore = 0x00000004,
        OpenLink = 0x00000008,
    }

    public class KeyInformation
    {
        public DateTime LastWriteTime { get; internal set; }
        public UInt32 TitleIndex { get; internal set; }
        public string Name { get; internal set; }
        public string Class { get; internal set; }
        public Int32 SubKeys { get; internal set; }
        public Int32 ValueCount { get; internal set ; }
        public KeyFlags Flags { get; internal set; }
        public bool VirtualizationCandidate { get; internal set; }
        public bool VirtualizationEnabled { get; internal set; }
        public bool VirtualTarget { get; internal set; }
        public bool VirtualStore { get; internal set; }
        public bool VirtualSource { get; internal set; }
        public UInt32 HandleTags { get; internal set; }
        public bool TrustedKey { get; internal set; }

        /*  Parameter is invalid
        public bool IsTombstone { get; internal set; }
        public bool IsSupersedeLocal { get; internal set; }
        public bool IsSupersedeTree { get; internal set; }
        public bool ClassIsInherited { get; internal set; }
        */
    }

    public class Key
    {
        public static SafeRegistryHandle OpenKey(SafeHandle key, string subKey, KeyOptions options,
            KeyAccessRights access)
        {
            SafeRegistryHandle handle;
            Int32 res = NativeMethods.RegOpenKeyExW(key, subKey, options, access, out handle);
            if (res != 0)
                throw new Win32Exception(res);

            return handle;
        }

        public static KeyInformation QueryInformation(SafeHandle handle)
        {
            KeyInformation info = new KeyInformation();

            using (var buffer = NtQueryKey(handle, NativeHelpers.KeyInformationClass.Basic))
            {
                var obj = (NativeHelpers.KEY_BASIC_INFORMATION)Marshal.PtrToStructure(
                    buffer.DangerousGetHandle(), typeof(NativeHelpers.KEY_BASIC_INFORMATION));

                IntPtr nameBuffer = IntPtr.Add(buffer.DangerousGetHandle(), 16);
                byte[] nameBytes = new byte[obj.NameLength];
                Marshal.Copy(nameBuffer, nameBytes, 0, nameBytes.Length);

                info.LastWriteTime = DateTime.FromFileTimeUtc(obj.LastWriteTime);
                info.TitleIndex = obj.TitleIndex;
                info.Name = Encoding.Unicode.GetString(nameBytes, 0, nameBytes.Length);
            }

            using (var buffer = NtQueryKey(handle, NativeHelpers.KeyInformationClass.Full))
            {
                var obj = (NativeHelpers.KEY_FULL_INFORMATION)Marshal.PtrToStructure(
                    buffer.DangerousGetHandle(), typeof(NativeHelpers.KEY_FULL_INFORMATION));

                IntPtr classBuffer = IntPtr.Add(buffer.DangerousGetHandle(), obj.ClassOffset);
                byte[] classBytes = new byte[obj.ClassLength];
                Marshal.Copy(classBuffer, classBytes, 0, classBytes.Length);

                info.Class = Encoding.Unicode.GetString(classBytes, 0, classBytes.Length);
                info.SubKeys = obj.SubKeys;
                info.ValueCount = obj.Values;
            }

            using (var buffer = NtQueryKey(handle, NativeHelpers.KeyInformationClass.Flags))
            {
                var obj = (NativeHelpers.KEY_FLAGS_INFORMATION)Marshal.PtrToStructure(
                    buffer.DangerousGetHandle(), typeof(NativeHelpers.KEY_FLAGS_INFORMATION));

                info.Flags = obj.UserFlags;
            }

            using (var buffer = NtQueryKey(handle, NativeHelpers.KeyInformationClass.Virtualization))
            {
                var obj = (NativeHelpers.KEY_VIRTUALIZATION_INFORMATION)Marshal.PtrToStructure(
                    buffer.DangerousGetHandle(), typeof(NativeHelpers.KEY_VIRTUALIZATION_INFORMATION));

                info.VirtualizationCandidate = obj.VirtualizationCandidate == 1;
                info.VirtualizationEnabled = obj.VirtualizationEnabled == 1;
                info.VirtualTarget = obj.VirtualTarget == 1;
                info.VirtualStore = obj.VirtualStore == 1;
                info.VirtualSource = obj.VirtualSource == 1;
            }

            using (var buffer = NtQueryKey(handle, NativeHelpers.KeyInformationClass.HandleTags))
            {
                var obj = (NativeHelpers.KEY_HANDLE_TAGS_INFORMATION)Marshal.PtrToStructure(
                    buffer.DangerousGetHandle(), typeof(NativeHelpers.KEY_HANDLE_TAGS_INFORMATION));

                info.HandleTags = obj.HandleTags;
            }

            using (var buffer = NtQueryKey(handle, NativeHelpers.KeyInformationClass.Trust))
            {
                var obj = (NativeHelpers.KEY_TRUST_INFORMATION)Marshal.PtrToStructure(
                    buffer.DangerousGetHandle(), typeof(NativeHelpers.KEY_TRUST_INFORMATION));

                info.TrustedKey = obj.TrustedKey == 1;
            }

            /*  Parameter is invalid
            using (var buffer = NtQueryKey(handle, NativeHelpers.KeyInformationClass.Layer))
            {
                var obj = (NativeHelpers.KEY_LAYER_INFORMATION)Marshal.PtrToStructure(
                    buffer.DangerousGetHandle(), typeof(NativeHelpers.KEY_LAYER_INFORMATION));

                info.IsTombstone = obj.IsTombstone == 1;
                info.IsSupersedeLocal = obj.IsSupersedeLocal == 1;
                info.IsSupersedeTree = obj.IsSupersedeTree == 1;
                info.ClassIsInherited = obj.ClassIsInherited == 1;
            }
            */

            return info;
        }

        private static SafeMemoryBuffer NtQueryKey(SafeHandle handle, NativeHelpers.KeyInformationClass infoClass)
        {
            int resultLength;
            UInt32 res = NativeMethods.NtQueryKey(handle, infoClass, IntPtr.Zero, 0, out resultLength);
            // STATUS_BUFFER_OVERFLOW or STATUS_BUFFER_TOO_SMALL
            if (!(res == 0x80000005 || res == 0xC0000023))
                throw new Win32Exception(NativeMethods.RtlNtStatusToDosError(res));

            SafeMemoryBuffer buffer = new SafeMemoryBuffer(resultLength);
            try
            {
                res = NativeMethods.NtQueryKey(handle, infoClass, buffer.DangerousGetHandle(), resultLength,
                    out resultLength);

                if (res != 0)
                    throw new Win32Exception(NativeMethods.RtlNtStatusToDosError(res));
            }
            catch
            {
                buffer.Dispose();
                throw;
            }

            return buffer;
        }
    }
}
'@
		}
    }

    process {
        $resolvedPaths = $Path

        foreach ($regPath in $resolvedPaths) {
            if (-not $regPath.Contains(':')) {
                $exp = [ArgumentException]"Registry path must contain hive and keys split by :"
                $PSCmdlet.WriteError([Management.Automation.ErrorRecord]::new(
                    $exp, $exp.GetType().FullName, 'InvalidArgument', $regPath
                ))
                continue
            }
            $hive, $subKey = $regPath -split ':', 2
            $hiveId = switch ($hive) {
                { $_ -in @('HKCR', 'HKEY_CLASES_ROOT') } { 0x80000000 }
                { $_ -in @('HKCU', 'HKEY_CURRENT_USER') } { 0x80000001 }
                { $_ -in @('HKLM', 'HKEY_LOCAL_MACHINE') } { 0x80000002 }
                { $_ -in @('HKU', 'HKEY_USERS') } { 0x80000003 }
                { $_ -in @('HKPD', 'HKEY_PERFORMANCE_DATA') } { 0x80000004 }
                { $_ -in @('HKPT', 'HKEY_PERFORMANCE_TEXT') } { 0x80000050 }
                { $_ -in @('HKPN', 'HKEY_PERFORMANCE_NLSTEXT') } { 0x80000060 }
                { $_ -in @('HKCC', 'HKEY_CURRENT_CONFIG') } { 0x80000005 }
                { $_ -in @('HKDD', 'HKEY_DYN_DATA') } { 0x80000006 }
                { $_ -in @('HKCULS', 'HKEY_CURRENT_USER_LOCAL_SETTINGS') } { 0x80000007 }
            }
            if (-not $hiveId) {
                $exp = [ArgumentException]"Registry hive path is invalid"
                $PSCmdlet.WriteError([Management.Automation.ErrorRecord]::new(
                    $exp, $exp.GetType().FullName, 'InvalidArgument', $regPath
                ))
                continue
            }
            if ($subKey.StartsWith('\')) {
                $subKey = $subKey.Substring(1)
            }

            $hive = [Microsoft.Win32.SafeHandles.SafeRegistryHandle]::new([IntPtr]::new($hiveId), $false)
            $key = $null
            try {
                # We can't use the PowerShell provider because it doesn't set OpenLink which means we couldn't detect
                # if the path was a link as the handle would be for the target.
                $key = [Registry.Key]::OpenKey($hive, $subKey, 'OpenLink', 'QueryValue')
                [Registry.Key]::QueryInformation($key)
            }
            catch {
                $PSCmdlet.WriteError([Management.Automation.ErrorRecord]::new(
                    $_.Exception, $_.Exception.GetType().FullName, 'NotSpecified', $regPath
                ))
                continue
            }
            finally {
                $key.Dispose()
            }
        }
    }
}

$cloneTag = Get-ItemProperty -Path HKLM:\SYSTEM\Setup | Select-Object -ExpandProperty CloneTag
$cloneTag = [DateTime]::ParseExact($cloneTag, "ddd MMM dd HH:mm:ss yyyy", [System.Globalization.CultureInfo]::InvariantCulture)
$cloneTag = "$(Get-Date $cloneTag -Format yyyy-MM-dd) $(Get-Age -Start $cloneTag) ago"

$w32TimeRegKeyLastWriteTime = Get-RegKeyInfo -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\w32time' | Select-Object -ExpandProperty LastWriteTime
$w32TimeRegKeyLastWriteTime = "$(Get-Date $w32TimeRegKeyLastWriteTime -Format yyyy-MM-dd) $(Get-Age -Start $w32TimeRegKeyLastWriteTime) ago"

$profileCreationTime = Get-Item -Path $env:USERPROFILE -Force | Select-Object -ExpandProperty CreationTime
$profileCreationTime = "$(Get-Date $profileCreationTime -Format yyyy-MM-dd) $(Get-Age -Start $profileCreationTime) ago"

$osInstallDateFromRegistry = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name InstallDate
$osInstallDateFromRegistry = ([datetime]'1/1/1970').AddSeconds($osInstallDateFromRegistry)
$osInstallDateFromRegistry = "$(Get-Date $osInstallDateFromRegistry -Format yyyy-MM-dd) $(Get-Age -Start $osInstallDateFromRegistry) ago"

$win32_OperatingSystem = Get-CimInstance -Query 'SELECT InstallDate FROM Win32_OperatingSystem'
$osInstallDateFromWMI = $win32_OperatingSystem.InstallDate
$osInstallDateFromWMI = "$(Get-Date $osInstallDateFromWMI -Format yyyy-MM-dd) $(Get-Age -Start $osInstallDateFromWMI) ago"

$dates = [PSCustomObject]@{
    CloneTag = $cloneTag
    OsInstallDateFromRegistry = $osInstallDateFromRegistry
    OsInstallDateFromWMI = $osInstallDateFromWMI
    ProfileCreationTime = $profileCreationTime
    W32TimeRegKeyLastWriteTime = $w32TimeRegKeyLastWriteTime
}

$dates | sort-object