# Run this file from the ProjectD2 folder
param (
    [string]$server = "Live" # Live or Beta
)

$launcher = "https://storage.googleapis.com/storage/v1/b/pd2-launcher-update/o"
$client = "https://storage.googleapis.com/storage/v1/b/pd2-client-files/o"
$newclient = "https://pd2-client-files.projectdiablo2.com"

if ($server -eq "Beta") {
    $client = "https://storage.googleapis.com/storage/v1/b/pd2-beta-client-files/o"
    $newclient = "https://pd2-beta-client-files.projectdiablo2.com"
}


# Check parent directory for Game.exe (assuming it exists from base D2 install)
if (!(Test-Path "$(Split-Path -Path $pwd -Parent)/Game.exe")) {
    Write-Host "Diablo install not detected. Aborting..." -ForegroundColor Red
    exit 1
}

function Receive-Google-Bucket {
    param (
        $Filehost
    )

    $filelist = @()
    $urllist = @{}
    $modlist = @{}
    $sizelist = @{}

    # Check server for file information
    $response = Invoke-WebRequest -Uri "$($Filehost)"

    if ($response.StatusCode -eq '200') {
        # Save published file list and their checksums
        foreach ($file in ConvertFrom-Json $response.Content | Select-Object -expand "items") {
            $filelist += $file.name
            $urllist[$file.name] = $file.mediaLink
            $modlist[$file.name] = $file.updated.substring(0, $file.updated.Length-5)
            $sizelist[$file.name] = $file.size
        }

        # Create the Live/Beta folder if it doesn't exist
        if (!(Test-Path "$($pwd)/$($server)/")) {
            New-Item -ItemType Directory -Force -Path "$($pwd)/$($server)" | Out-Null
        }

        $filecount = 1
        foreach ($file in $filelist) {
            try {
                $path = "$($pwd)/$($server)/$($file)"
                # Check for existing file. Skip downloading if its modified time and size matches server
                # Note: Modified time and size being used temporarily because GCS's checksums are a pain in PS
                if (Test-Path "$($path)") {
                    $size = (Get-Item $path).Length
                    $modtime = (Get-Date -UFormat "%Y-%m-%dT%T" ((Get-Item $path).LastWriteTime.ToUniversalTime()))
                    if (((Get-Date $modtime) -ge (Get-Date $modlist[$file])) -and ($size -eq $sizelist[$file])) {
                        Write-Host "[$('{0:d2}' -f $filecount)/$($filelist.Count)] $($file) already updated. Skiping..."
                        $filecount += 1
                        continue
                    }
                }
                # Make any subfolders that will be needed (e.g. Shaders)
                if (!(Test-Path "$($pwd)/$($server)/$(Split-Path $($file) -Parent)")) {
                    New-Item -ItemType Directory -Path "$($pwd)/$($server)/$(Split-Path $($file) -Parent)" -Force | Out-Null
                    New-Item -ItemType Directory -Path "$($pwd)/$(Split-Path $($file) -Parent)" -Force | Out-Null
                }
                # Download file and copy to main PD2 folder
                Write-Progress -Activity "[$('{0:d2}' -f $filecount)/$($filelist.Count)] Downloading $($file)..."
                Start-BitsTransfer "$($urllist[$file])" "$($path)"
                Copy-Item -Path "$($path)" -Destination "$($pwd)/$($file)" -Force
                Write-Host "[$('{0:d2}' -f $filecount)/$($filelist.Count)] Downloaded $($file)..."
                $filecount += 1
            } catch {
                Write-Host "Could not download $($file). Error:" -ForegroundColor Red
                Write-Host $error.Exception.Message -ForegroundColor Red
                $filecount += 1
                $error.Clear()
                return
            }
        }
    } else {
        Write-Host "Could not connect to the file host. $($response.StatusCode) $($response.StatusDescription)" -ForegroundColor Red
    }
}

function Receive-PD2-Bucket {
    $filelist = @{}

    # Check server for file information
    $response = Invoke-WebRequest -Uri "$($newclient)/metadata.json"

    if ($response.StatusCode -eq '200') {
        # Save published file list and their checksums
        foreach ($file in (ConvertFrom-Json $response.Content.Substring($response.Content.IndexOf('{')) | Select-Object -Expand "checksum")) {
            $details = $file -split "  "
            $filelist[$details[1]] = $details[0]
        }
        # Create the Live/Beta folder if it doesn't exist
        if (!(Test-Path "$($pwd)/$($server)/")) {
            New-Item -ItemType Directory -Force -Path "$($pwd)/$($server)" | Out-Null
        }

        $filecount = 1
        $filelist.GetEnumerator().ForEach({
            try {
                # Check for existing file. Skip downloading if its checksum matches server
                if (Test-Path "$($pwd)/$($server)/$($_.Key)") {
                    $current = Get-FileHash -Algorithm MD5 "$($pwd)/$($server)/$($_.Key)"
                    if ($current.Hash.ToLower() -eq $_.Value.ToLower()) {
                        Write-Host "[$('{0:d2}' -f $filecount)/$($filelist.Count)] $($_.Key) already updated. Skipping..."
                        $filecount += 1
                        return
                    }
                }
                # Make any subfolders that will be needed (e.g. Shaders)
                if (!(Test-Path "$($pwd)/$($server)/$(Split-Path $($file) -Parent)")) {
                    New-Item -ItemType Directory -Path "$($pwd)/$($server)/$(Split-Path $($file) -Parent)" -Force | Out-Null
                    New-Item -ItemType Directory -Path "$($pwd)/$(Split-Path $($file) -Parent)" -Force | Out-Null
                }
                # Download file and copy to main PD2 folder
                Write-Progress -Activity "[$('{0:d2}' -f $filecount)/$($filelist.Count)] Downloading $($_.Key)..."
                Start-BitsTransfer "$($newclient)/$($_.Key)" "$($pwd)/$($server)/$($_.Key)"
                Copy-Item -Path "$($pwd)/$($server)/$($_.Key)" -Destination "$($pwd)/$($_.Key)"
                Write-Host "[$('{0:d2}' -f $filecount)/$($filelist.Count)] Downloaded $($_.Key)"
                $filecount += 1
            } catch {
                Write-Host "Could not download $($_.Key). Error:" -ForegroundColor Red
                Write-Host $error.Exception.Message -ForegroundColor Red
                $filecount += 1
                $error.Clear()
                continue
            }
        })
    } else {
        Write-Host "Could not connect to the file host. $($response.StatusCode) $($response.StatusDescription)" -ForegroundColor Red
    }
}

Write-Host "    Downloading launcher files..."
Receive-Google-Bucket -Filehost $launcher
Write-Host "    Downloading main client files..."
Receive-PD2-Bucket
Write-Host "    Downloading optional client files..."
Receive-Google-Bucket -Filehost $client

Pause
