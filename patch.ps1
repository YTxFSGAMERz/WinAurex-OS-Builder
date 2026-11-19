if ($architecture -eq 'amd64') {
    $folderPaths = Get-ChildItem -Path "$mainOSDrive\scratchdir\Windows\WinSxS" -Filter "amd64_microsoft-edge-webview_31bf3856ad364e35*" -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

    if ($folderPaths) {
        foreach ($folderPath in $folderPaths) {
            & 'takeown' '/f' $folderPath '/r' | Out-Null
            & icacls $folderPath "/grant" "$($adminGroup.Value):(F)" '/T' '/C' | Out-Null
            Remove-Item -Path $folderPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "Edge Webview folder not found."
    }
} elseif ($architecture -eq 'arm64') {
    $folderPaths = Get-ChildItem -Path "$mainOSDrive\scratchdir\Windows\WinSxS" -Filter "arm64_microsoft-edge-webview_31bf3856ad364e35*" -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

    if ($folderPaths) {
        foreach ($folderPath in $folderPaths) {
            & 'takeown' '/f' $folderPath '/r' | Out-Null
            & icacls $folderPath "/grant" "$($adminGroup.Value):(F)" '/T' '/C' | Out-Null
            Remove-Item -Path $folderPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "Edge Webview folder not found."
    }
}
