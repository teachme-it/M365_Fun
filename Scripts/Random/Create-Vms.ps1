#Make VMs
New-VM -Name M365_792721_1  -MemoryStartupBytes 2048MB -Path D:\M365x792721_VMs
New-VHD -Path D:\M365x792721_VM\M365_792721_1\M365_792721_1.vhdx -SizeBytes 127GB -Dynamic

Add-VMHardDiskDrive -VMName M365_792721_1 -Path D:\M365x792721_VM\M365_792721_1\M365_792721_1.vhdx

Set-VMDvdDrive -VMName DC -ControllerNumber 1 -Path "E:\OneDrive - Microsoft\ISOs & Installers\ISOs\Windows 10\Windows_10_2004.iso"