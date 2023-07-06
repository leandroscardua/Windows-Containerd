<#
    .SYNOPSIS
        Script to install and configure windows container with containerD, nerdctl and WCN for CNI 

    .DESCRIPTION
        Installs the prerequisites for creating Windows containers with containerd, nerdctl and windows-container-networking, using the latest available version

    .LINK
        https://raw.githubusercontent.com/leandroscardua/Windows-Containerd/master/install_containerd.ps1

    .EXAMPLE
        curl.exe -LO https://raw.githubusercontent.com/leandroscardua/Windows-Containerd/master/install_containerd.ps1
        .\install_containerd.ps1
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param(

  [ValidateNotNullOrEmpty()]
  [String]$tagcd = ((Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/containerd/containerd/releases/latest" | ConvertFrom-Json)[0].tag_name -replace "v",""),

  [ValidateNotNullOrEmpty()]
  [String]$tagcni = ((Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/microsoft/windows-container-networking/releases/latest" | ConvertFrom-Json)[0].tag_name -replace "v",""),

  [ValidateNotNullOrEmpty()]
  [String]$tagnerdctl = ((Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/containerd/nerdctl/releases/latest" | ConvertFrom-Json)[0].tag_name -replace "v",""),

  [ValidateNotNullOrEmpty()]
  [String]$subnet='10.0.0.0/24',

  [ValidateNotNullOrEmpty()]
  [String]$gateway='10.0.0.1'

)


Write-Host "Checking the latest version of containerd and Windows CNI" -ForegroundColor DarkCyan 
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "Checking for the Windows Feature is already installed" -ForegroundColor DarkCyan

$feature = Get-WindowsFeature -Name Containers

if($feature.Installed -eq 'True') {
Write-Host "Installed" -ForegroundColor DarkGreen
}else{
Write-Host "Please, Install Windows Feature and run the script again. (Install-WindowsFeature -Name Containers)" -ForegroundColor DarkRed
exit
}


function DownloadFile {

    param (
        [String]$source,
        [String]$outfile
    )

    Invoke-WebRequest $source -UseBasicParsing -OutFile $outfile

}

$destination="$Env:ProgramFiles\containerd"
Write-Host "Creating folder on $destination" -ForegroundColor DarkCyan
mkdir -force $destination | Out-Null
Set-Location $destination


Write-Host "Downloading ContainerD to $destination" -ForegroundColor DarkCyan
DownloadFile "https://github.com/containerd/containerd/releases/download/v$tagcd/containerd-$tagcd-windows-amd64.tar.gz" "$destination\containerd-$tagcd-windows-amd64.tar.gz"
Write-Host "Saving containerd on $destination" -ForegroundColor DarkCyan

tar.exe -xf .\containerd-$tagcd-windows-amd64.tar.gz

Copy-Item -Path "$destination\bin\*" -Destination $destination -Recurse -Force

Write-Host "Creating containerd config file" -ForegroundColor DarkCyan

.\containerd.exe config default | Out-File config.toml -Encoding ascii

Write-Host "Registering containerd as a service" -ForegroundColor DarkCyan

.\containerd.exe --register-service

Write-Host "Starting containerd service" -ForegroundColor DarkCyan

Start-Service containerd

Write-Host "Downloading Windows CNI to $destination\cni\bin" -ForegroundColor DarkCyan

mkdir -force $destination\cni\bin | Out-Null
Set-Location $destination\cni\bin
DownloadFile "https://github.com/microsoft/windows-container-networking/releases/download/v$tagcni/windows-container-networking-cni-amd64-v$tagcni.zip" "$destination\cni\bin\windows-container-networking-cni-amd64-v$tagcni.zip"

Write-Host "Saving Windows CNI on $destination" -ForegroundColor DarkCyan

tar.exe -xf $destination\cni\bin\windows-container-networking-cni-amd64-v$tagcni.zip

Write-Host "Downloading nerdctl to $destination" -ForegroundColor DarkCyan

Set-Location $destination
Invoke-WebRequest "https://github.com/containerd/nerdctl/releases/download/v$tagnerdctl/nerdctl-$tagnerdctl-windows-amd64.tar.gz" -UseBasicParsing -OutFile $destination\nerdctl-$tagnerdctl-windows-amd64.tar.gz

Write-Host "Saving nerdctl on $destination" -ForegroundColor DarkCya

tar.exe -xf $destination\nerdctl-$tagnerdctl-windows-amd64.tar.gz

Write-Host "Downloading HNS Powershell Module" -ForegroundColor DarkCyan

DownloadFile "https://raw.githubusercontent.com/microsoft/SDN/master/Kubernetes/windows/hns.psm1" $destination\hns.psm1
Import-Module .\hns.psm1

Write-Host "Creating New NAT Network" -ForegroundColor DarkCyan

New-HnsNetwork -Type NAT -AddressPrefix $subnet -Gateway $gateway -Name "nat"

Write-Host "Configuring network on nerdctl using NAT Network" -ForegroundColor DarkCyan

mkdir -Force "$env:ProgramFiles\containerd\cni\conf\"| Out-Null

@"
{
    "cniVersion": "$tagcni",
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


# Download nanoserver version ltsc2022 image

# .\nerdctl.exe pull mcr.microsoft.com/windows/nanoserver:ltsc2022

# Run a test container using the nanoserver version ltsc2022 image

# .\nerdctl.exe run -it --net nat mcr.microsoft.com/windows/nanoserver:ltsc2022

