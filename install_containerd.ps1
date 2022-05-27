$ErrorActionPreference = 'Stop'

Write-Host "Checking the latest version of containerd and Windows CNI"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tagcd = (Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/containerd/containerd/releases/latest" | ConvertFrom-Json)[0].tag_name
$tagcni = (Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/microsoft/windows-container-networking/releases/latest" | ConvertFrom-Json)[0].tag_name

$destination="$Env:ProgramFiles\containerd"
Write-Host "Creating folder on $destination"
mkdir -force $destination | Out-Null
Set-Location $destination

$dlw = $tagcd -replace "v",""
Write-Host "Downloading ContainerD to $destination"
Invoke-WebRequest "https://github.com/containerd/containerd/releases/download/$tagcd/containerd-$dlw-windows-amd64.tar.gz" -UseBasicParsing -OutFile $destination\containerd-$dlw-windows-amd64.tar.gz

Write-Host "Saving containerd on $destination"

tar.exe -xf .\containerd-$dlw-windows-amd64.tar.gz

Copy-Item -Path "$destination\bin\*" -Destination $destination -Recurse -Force

Write-Host "creating containerd config file"

.\containerd.exe config default | Out-File config.toml -Encoding ascii

Write-Host "Downloading Windows CNI to $destination\cni\bin"
mkdir -force $destination\cni\bin | Out-Null
Set-Location $destination\cni\bin 
Invoke-WebRequest "https://github.com/microsoft/windows-container-networking/releases/download/$tagcni/windows-container-networking-cni-amd64-$tagcni.zip" -UseBasicParsing -OutFile "$destination\cni\bin\windows-container-networking-cni-amd64-$tagcni.zip"
                   
Write-Host "Saving Windows CNI on $destination"

tar.exe -xf $destination\cni\bin\windows-container-networking-cni-amd64-$tagcni.zip

Write-Host "Registering containerd"

Set-Location $destination

.\containerd.exe --register-service

Write-Host "starting containerd"

Start-Service containerd
