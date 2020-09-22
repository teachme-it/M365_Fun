#Make VMs

Param($Vmname)

$vmpath = "D:\M365x792721_VMs\"

$fullName = 'M365_792721_'+ $Vmname

New-VM -Name $fullName  -MemoryStartupBytes 2048MB -Path $vmpath

New-VHD -Path "$vmpath\$fullname\$fullname.vhdx" -SizeBytes 127GB -Dynamic

Add-VMHardDiskDrive -VMName $fullName -Path $vmpath\$fullname\$fullname.vhdx

Set-VMDvdDrive -VMName $fullName -ControllerNumber 1 -Path "E:\OneDrive - Microsoft\ISOs & Installers\ISOs\Windows 10\Windows_10_1909_June2020.iso"
Add-VMNetworkAdapter -VMName $fullName -SwitchName LabSwitch_External
