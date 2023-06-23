#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

# download this script
# curl.exe -LO https://raw.githubusercontent.com/leandroscardua/Windows-Containerd/master/install_containerd.ps1
# .\install_containerd.ps1
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

$destination="$Env:ProgramFiles\containerd"
Write-Host "Creating folder on $destination" -ForegroundColor DarkCyan
mkdir -force $destination | Out-Null
Set-Location $destination

$dlw = $tagcd -replace "v",""
Write-Host "Downloading ContainerD to $destination" -ForegroundColor DarkCyan
Invoke-WebRequest "https://github.com/containerd/containerd/releases/download/$tagcd/containerd-$dlw-windows-amd64.tar.gz" -UseBasicParsing -OutFile $destination\containerd-$dlw-windows-amd64.tar.gz

Write-Host "Saving containerd on $destination" -ForegroundColor DarkCyan

tar.exe -xf .\containerd-$dlw-windows-amd64.tar.gz

Copy-Item -Path "$destination\bin\*" -Destination $destination -Recurse -Force

Write-Host "creating containerd config file" -ForegroundColor DarkCyan

.\containerd.exe config default | Out-File config.toml -Encoding ascii

Write-Host "Downloading Windows CNI to $destination\cni\bin" -ForegroundColor DarkCyan
mkdir -force $destination\cni\bin | Out-Null
Set-Location $destination\cni\bin 
Invoke-WebRequest "https://github.com/microsoft/windows-container-networking/releases/download/$tagcni/windows-container-networking-cni-amd64-$tagcni.zip" -UseBasicParsing -OutFile "$destination\cni\bin\windows-container-networking-cni-amd64-$tagcni.zip"
                   
Write-Host "Saving Windows CNI on $destination" -ForegroundColor DarkCyan

tar.exe -xf $destination\cni\bin\windows-container-networking-cni-amd64-$tagcni.zip

$dlwn = $tagnerdctl -replace "v",""
Write-Host "Downloading nerdctl to $destination" -ForegroundColor DarkCyan
Set-Location $destination
Invoke-WebRequest "https://github.com/containerd/nerdctl/releases/download/$tagnerdctl/nerdctl-$dlwn-windows-amd64.tar.gz" -UseBasicParsing -OutFile $destination\nerdctl-$dlwn-windows-amd64.tar.gz

Write-Host "Saving nerdctl on $destination" -ForegroundColor DarkCyan

tar.exe -xf $destination\nerdctl-$dlwn-windows-amd64.tar.gz

Write-Host "Registering containerd" -ForegroundColor DarkCyan

Set-Location $destination

.\containerd.exe --register-service

Write-Host "starting containerd" -ForegroundColor DarkCyan

Start-Service containerd

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


.\nerdctl.exe run --net nat mcr.microsoft.com/windows/nanoserver:ltsc2022
