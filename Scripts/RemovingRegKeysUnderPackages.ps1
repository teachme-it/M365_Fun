#===========================================================
#
# Priv Enabler.
#
# https://www.leeholmes.com/blog/2010/09/24/adjusting-token-privileges-in-powershell/
#============================================================
Function Enable-Privilege {
 param(
  ## The privilege to adjust. This set is taken from
  ## http://msdn.microsoft.com/en-us/library/bb530716(VS.85).aspx
  [ValidateSet(
   "SeAssignPrimaryTokenPrivilege", "SeAuditPrivilege", "SeBackupPrivilege",
   "SeChangeNotifyPrivilege", "SeCreateGlobalPrivilege", "SeCreatePagefilePrivilege",
   "SeCreatePermanentPrivilege", "SeCreateSymbolicLinkPrivilege", "SeCreateTokenPrivilege",
   "SeDebugPrivilege", "SeEnableDelegationPrivilege", "SeImpersonatePrivilege", "SeIncreaseBasePriorityPrivilege",
   "SeIncreaseQuotaPrivilege", "SeIncreaseWorkingSetPrivilege", "SeLoadDriverPrivilege",
   "SeLockMemoryPrivilege", "SeMachineAccountPrivilege", "SeManageVolumePrivilege",
   "SeProfileSingleProcessPrivilege", "SeRelabelPrivilege", "SeRemoteShutdownPrivilege",
   "SeRestorePrivilege", "SeSecurityPrivilege", "SeShutdownPrivilege", "SeSyncAgentPrivilege",
   "SeSystemEnvironmentPrivilege", "SeSystemProfilePrivilege", "SeSystemtimePrivilege",
   "SeTakeOwnershipPrivilege", "SeTcbPrivilege", "SeTimeZonePrivilege", "SeTrustedCredManAccessPrivilege",
   "SeUndockPrivilege", "SeUnsolicitedInputPrivilege")]
  $Privilege,
  ## The process on which to adjust the privilege. Defaults to the current process.
  $ProcessId = $pid,
  ## Switch to disable the privilege, rather than enable it.
  [Switch] $Disable
 )

 ## Taken from P/Invoke.NET with minor adjustments.
 $definition = @'
 using System;
 using System.Runtime.InteropServices;
  
 public class AdjPriv
 {
  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
   ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
  
  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
  [DllImport("advapi32.dll", SetLastError = true)]
  internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  internal struct TokPriv1Luid
  {
   public int Count;
   public long Luid;
   public int Attr;
  }
  
  internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
  internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
  internal const int TOKEN_QUERY = 0x00000008;
  internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
  public static bool EnablePrivilege(long processHandle, string privilege, bool disable)
  {
   bool retVal;
   TokPriv1Luid tp;
   IntPtr hproc = new IntPtr(processHandle);
   IntPtr htok = IntPtr.Zero;
   retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
   tp.Count = 1;
   tp.Luid = 0;
   if(disable)
   {
    tp.Attr = SE_PRIVILEGE_DISABLED;
   }
   else
   {
    tp.Attr = SE_PRIVILEGE_ENABLED;
   }
   retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
   retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
   return retVal;
  }
 }
'@

 $processHandle = (Get-Process -id $ProcessId).Handle
 $type = Add-Type $definition -PassThru
 $type[0]::EnablePrivilege($processHandle, $Privilege, $Disable)
}

#===========================================================
#
# Portion that does the work.
#
#============================================================

#This enables the Take Ownership Privilege for the current logged in User.

Enable-Privilege -Privilege SeTakeOwnershipPrivilege
Whoami /priv ## CONFIRM THAT OWNERSHIP PRIV IS ENABLED!

#This gets all keys containing KB4103721 and its subkeys, under HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages.  
#You will need to modify the KB number to reflect the KB that you are trying to remove. 
#The only things that need to be modified are the two *KB4103721* entries in the $Keys and $Subkeys lines.  
#Everything else should stay the same for all scenarios unless the current logged in user does not have admin rights.

$Parent = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages'
$Keys = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages\*KB4457127*'
$Subkeys = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages\*KB4457127*' -Recurse
$AllKeys = $Keys+$Subkeys+$Parent
$KeysToDelete = $Keys+$Subkeys

#This takes ownership of the above keys and subkeys.  The new owner will be the current logged in user.

Foreach ($node in $AllKeys)

{

$KEY = $Node.pspath.Replace('Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\','')
Write-Output $KEY

$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($Key,[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::takeownership)
$acl = $key.GetAccessControl()
$me = [System.Security.Principal.NTAccount]"$env:userdnsdomain\$env:username"
$acl.SetOwner($me)
$key.SetAccessControl($acl)

}
# After you have set owner you need to get the acl with the perms so you can modify it.  
#This will give full control permissions to the current logged in user. For all keys Below Packages, but not the Packages key itself.  
#If you add the Packages key here it pushes the permissions to all keys below it, which is not desired in this scenario. 

Foreach ($node in $KeysToDelete)

{

$KEY1 = $Node.pspath.Replace('Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\','')
Write-Output $KEY1

$key1 = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($key1,[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::ChangePermissions)
$acl = $key1.GetAccessControl()
   $InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
$rule = New-Object System.Security.AccessControl.RegistryAccessRule ("$env:userdnsdomain\$env:username","FullControl",$InheritanceFlag,"None","Allow")
$acl.SetAccessRule($rule)
$key1.SetAccessControl($acl)
 
}

#This gives Full Control Permissions to the logged on user for HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages registry key only.  
#It appears that this is needed in order to remove the keys below it when using PowerShell. 
#If you want to use a reg delete command or manually remove the keys instead of using Powershell, this step is not needed.

Foreach ($node in $Parent)

{

$KEY2 = $Node.pspath.Replace('Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\','')
Write-Output $KEY2

$key2 = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($key2,[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::ChangePermissions)
$acl = $key2.GetAccessControl()   
$rule = New-Object System.Security.AccessControl.RegistryAccessRule ("$env:userdnsdomain\$env:username","FullControl","Allow")
$acl.SetAccessRule($rule)
$key2.SetAccessControl($acl)

}

#This deletes the keys referenced in the $Keys

$Keys | Remove-Item -Recurse 

#This changes the owner of the Packages key back to the Built in Administrators group, which is the default.

Foreach ($node in $Parent)

{

$KEY3 = $Node.pspath.Replace('Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\','')
Write-Output $KEY3

$key3 = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($Key3,[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::takeownership)
$acl = $key3.GetAccessControl()
$Admin = [System.Security.Principal.NTAccount]"BUILTIN\Administrators"
$acl.SetOwner($Admin)
$key3.SetAccessControl($acl)

}

#This removes the current logged in user account from the permissions list under 
#HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages

Foreach ($node in $Parent)

{

$KEY4 = $Node.pspath.Replace('Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\','')
Write-Output $KEY4

$key4 = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($key4,[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::ChangePermissions)
$acl = $key4.GetAccessControl()   
$rule = New-Object System.Security.AccessControl.RegistryAccessRule ("$env:userdnsdomain\$env:username","FullControl","Allow")
$acl.RemoveAccessRule($rule)
$key4.SetAccessControl($acl)

}
