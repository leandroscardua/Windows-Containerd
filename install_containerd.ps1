mkdir c:\containerd
cd c:\containerd
curl -OL https://github.com/containerd/containerd/releases/download/v1.4.0/containerd-1.4.0-windows-amd64.tar.gz
tar xvf .\containerd-1.4.0-windows-amd64.tar.gz

# extract and configure
Copy-Item -Path ".\bin\" -Destination "$Env:ProgramFiles\containerd" -Recurse -Force
cd $Env:ProgramFiles\containerd\
.\containerd.exe config default | Out-File config.toml -Encoding ascii

# review the configuration. depending on setup you may want to adjust:
# - the sandbox_image (kubernetes pause image)
# - cni bin_dir and conf_dir locations
Get-Content config.toml

.\containerd.exe --register-service

Start-Service containerd
