$ErrorActionPreference = 'Stop'

Write-Host "Checking for the Windows Feature is already installed"

$feature = Get-WindowsFeature -Name Containers

if($feature.Installed -eq 'True')
{Write-Host "Installed" -ForegroundColor DarkGreen}
else
{Write-Host "Please, Install Windows Feature and run the script again. (Install-WindowsFeature -Name Containers)" -ForegroundColor DarkRed
 exit
}

Write-Host "Checking the latest version of containerd and Windows CNI" -ForegroundColor DarkCyan 
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tagcd = (Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/containerd/containerd/releases/latest" | ConvertFrom-Json)[0].tag_name
$tagcni = (Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/microsoft/windows-container-networking/releases/latest" | ConvertFrom-Json)[0].tag_name
$tagnerdctl = (Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/containerd/nerdctl/releases/latest" | ConvertFrom-Json)[0].tag_name

$destination="$Env:ProgramFiles\containerd"
Write-Host "Creating folder on $destination" -ForegroundColor DarkCyan
mkdir -force $destination | Out-Null
Set-Location $destination

$dlw = $tagcd -replace "v",""
Write-Host "Downloading ContainerD to $destination" -ForegroundColor DarkCyan
Invoke-WebRequest "https://github.com/containerd/containerd/releases/download/$tagcd/containerd-$dlw-windows-amd64.tar.gz" -UseBasicParsing -OutFile $destination\containerd-$dlw-windows-amd64.tar.gz

Write-Host "Saving containerd on $destination"

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
Invoke-WebRequest "https://github.com/containerd/nerdctl/releases/download/$tagnerdctl/nerdctl-$dlwn-windows-amd64.tar.gz" -UseBasicParsing -OutFile $destination\nerdctl-$dlwn-windows-amd64.tar.gz

Write-Host "Saving nerdctl on $destination" -ForegroundColor DarkCyan

tar.exe -xf $destination\nerdctl-$dlwn-windows-amd64.tar.gz

Write-Host "Registering containerd" -ForegroundColor DarkCyan

Set-Location $destination

.\containerd.exe --register-service

Write-Host "starting containerd" -ForegroundColor DarkCyan

Start-Service containerd
