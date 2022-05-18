# installer from lippertmarkus https://lippertmarkus.com/2022/01/22/containerd-ctr-windows/
# https://github.com/lippertmarkus/containerd-installer/releases

$ErrorActionPreference = 'Stop'

Write-Host "Checking the latest version of ContainerD installer"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$latest = (Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/lippertmarkus/containerd-installer/releases" | ConvertFrom-Json)[0].tag_name
$tagcd = (Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/containerd/containerd/releases/latest" | ConvertFrom-Json)[0].tag_name
$tagcni = (Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/microsoft/windows-container-networking/releases/latest" | ConvertFrom-Json)[0].tag_name

$lvcd = $tagcd -replace "v",""
$lvcni = $tagcni -replace "v",""

Write-Host "Downloading latest ContainerD installer"
Invoke-WebRequest "https://github.com/lippertmarkus/containerd-installer/releases/download/$latest/containerd-installer.exe" -UseBasicParsing -OutFile containerd-installer.exe

Write-Host "Installing ContainerD and Windows CNI"

.\containerd-installer.exe --containerd-version $lvcd --cni-plugin-version $lvcni --debug
