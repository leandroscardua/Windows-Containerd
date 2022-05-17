$ErrorActionPreference = 'Stop'

Write-Host "Checking the latest version of containerd"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tag = (Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/containerd/containerd/releases/latest" | ConvertFrom-Json)[0].tag_name

$destination="$Env:ProgramFiles\containerd\"
Write-Host "Creating folder on $destination"
mkdir -force $destination | Out-Null
cd $destination

$dlw = $tag -replace "v",""
Write-Host "Downloading containerd to $destination"
Invoke-WebRequest "https://github.com/containerd/containerd/releases/download/$tag/containerd-$dlw-windows-amd64.tar.gz" -UseBasicParsing -OutFile $destination\containerd-$dlw-windows-amd64.tar.gz

Write-Host "Saving containerd on $destination"

tar.exe -xf .\containerd-$dlw-windows-amd64.tar.gz

Copy-Item -Path "$destination\bin\*" -Destination $destination -Recurse -Force

Write-Host "creating containerd config file"

.\containerd.exe config default | Out-File config.toml -Encoding ascii

Write-Host "Registering containerd"

.\containerd.exe --register-service

Write-Host "starting containerd"

Start-Service containerd

Write-Host "Cleaning up containerd folder"

Remove-Item containerd-$dlw-windows-amd64.tar.gz

Remove-item -Path .\bin -Recurse
