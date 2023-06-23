#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

# download this script
# curl.exe -LO https://raw.githubusercontent.com/leandroscardua/Windows-Containerd/master/install_containerd_nerdctl.ps1
# .\install_containerd_nerdctl.ps1
#

Write-Host "Checking for the Windows Feature is already installed" -ForegroundColor DarkCyan

$feature = Get-WindowsFeature -Name Containers

if($feature.Installed -eq 'True') {
Write-Host "Installed" -ForegroundColor DarkGreen
}else{
Write-Host "Please, Install Windows Feature and run the script again. (Install-WindowsFeature -Name Containers)" -ForegroundColor DarkRed
exit
}

Write-Host "Checking the latest version of containerd and Windows CNI" -ForegroundColor DarkCyan 
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tagcd = (Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/containerd/containerd/releases/latest" | ConvertFrom-Json)[0].tag_name
$tagcni = (Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/microsoft/windows-container-networking/releases/latest" | ConvertFrom-Json)[0].tag_name
$tagnerdctl = (Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/containerd/nerdctl/releases/latest" | ConvertFrom-Json)[0].tag_name
$subnet='10.0.0.0/16'
$gateway='10.0.0.1'
$tagcniversion = $tagcni -replace "v",""
$tagcdversion = $tagcd -replace "v",""
$tagnerdctlversion = $tagnerdctl -replace "v",""

Write-Host "Downloading ContainerD to $env:ProgramFiles\containerd" -ForegroundColor DarkCyan

curl.exe -LO https://raw.githubusercontent.com/kubernetes-sigs/sig-windows-tools/master/hostprocess/Install-Containerd.ps1

.\Install-Containerd.ps1 -ContainerDVersion $tagcdversion -netAdapterName Ethernet -skipHypervisorSupportCheck -CNIBinPath "c:/opt/cni/bin" -CNIConfigPath "c:/etc/cni/net.d"

Set-Location "$env:ProgramFiles\containerd"

Write-Host "Downloading nerdctl to $env:ProgramFiles\containerd" -ForegroundColor DarkCyan

Invoke-WebRequest "https://github.com/containerd/nerdctl/releases/download/$tagnerdctl/nerdctl-$tagnerdctlversion-windows-amd64.tar.gz" -UseBasicParsing -OutFile $env:ProgramFiles\containerd\nerdctl-$tagnerdctlversion-windows-amd64.tar.gz

Write-Host "Saving nerdctl on $env:ProgramFiles\containerd" -ForegroundColor DarkCyan

tar.exe -xf $env:ProgramFiles\containerd\nerdctl-$tagnerdctlversion-windows-amd64.tar.gz

Write-Host "Install HNS Powershell Module" -ForegroundColor DarkCyan

curl.exe -LO 'https://raw.githubusercontent.com/microsoft/SDN/master/Kubernetes/windows/hns.psm1'
Import-Module .\hns.psm1

Write-Host "Create New NAT Network" -ForegroundColor DarkCyan

New-HnsNetwork -Type NAT -AddressPrefix $subnet -Gateway $gateway -Name "nat"

Write-Host "Configure network on nerdctl" -ForegroundColor DarkCyan

@"
{
    "cniVersion": "$tagcniversion",
    "name": "nat",
    "type": "nat",
    "master": "Ethernet",
    "ipam": {
        "subnet": "$subnet",
        "routes": [
            {
                "gateway": "$gateway"
            }
        ]
    },
    "capabilities": {
        "portMappings": true,
        "dns": true
    }
}
"@ | Set-Content "$env:ProgramFiles\containerd\cni\conf\0-containerd-nat.conf" -Force
#Remove-Item "$env:ProgramFiles\containerd\cni\conf\nerdctl-nat.conflist" -Force


.\nerdctl.exe network ls