param (
    [Parameter(Mandatory=$true)]
    [string]$ReleaseVersion,
    [switch]$Server,
    [switch]$Client
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

. "$PSScriptRoot\shared.ps1"

function New-ClientRelease {
    param (
        [string]$ReleaseVersion
    )

    Write-Host
    Write-Host "Creating client release files..." -ForegroundColor Cyan
    
    $releaseFolder = "$BUILDS_FOLDER\client\$ReleaseVersion"
    
    # Delete the release folder if it already exists, otherwise create it
    Remove-Item -Recurse -Force $releaseFolder -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $releaseFolder | Out-Null

    Write-Host "Preparing files for client release version $ReleaseVersion" -ForegroundColor Cyan

    New-ManifestJson -ReleaseFolder $releaseFolder -ReleaseVersion $ReleaseVersion

    # Write the main pack content to the release folder
    Write-Content -ReleaseFolder $releaseFolder

    # Run post-processing tasks on the release folder
    Copy-Templates -ReleaseFolder $releaseFolder
    Write-FileReplacements -ReleaseFolder $releaseFolder

    # Move the content to the overrides folder
    Move-ContentToOverrides -ReleaseFolder $releaseFolder

    Save-ModList -ReleaseFolder $releaseFolder
    New-ReleaseZip -ReleaseFolder $releaseFolder -ReleaseVersion $ReleaseVersion -DestFolder "$BUILDS_FOLDER\client"
}

function New-ServerRelease {
    param (
        [string]$ReleaseVersion
    )

    Write-Host
    Write-Host "Creating server release files..." -ForegroundColor Cyan
    
    $releaseFolder = "$BUILDS_FOLDER\server\$ReleaseVersion"
    
    # Delete the release folder if it already exists, otherwise create it
    Remove-Item -Recurse -Force $releaseFolder -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $releaseFolder | Out-Null

    Write-Host "Preparing files for server release version $ReleaseVersion" -ForegroundColor Cyan

    New-ManifestJson -ReleaseFolder $releaseFolder -ReleaseVersion $ReleaseVersion -Server

    # Write the main pack content to the release folder
    Write-Content -ReleaseFolder $releaseFolder

    # Write server-specific files
    Write-ServerFiles -ReleaseFolder $releaseFolder
    Save-ModFiles -ReleaseFolder $releaseFolder

    # Run post-processing tasks on the release folder
    Copy-Templates -ReleaseFolder $releaseFolder
    Write-FileReplacements -ReleaseFolder $releaseFolder

    Save-ModList -ReleaseFolder $releaseFolder
    New-ReleaseZip -ReleaseFolder $releaseFolder -ReleaseVersion $ReleaseVersion -DestFolder "$BUILDS_FOLDER\server" -Suffix "-server"
}

# Get anything in the templates folder and copy them to the release folder.
# The folders may already exist in the release folder, so we need to overwrite them.
function Copy-Templates {
    param (
        [string]$ReleaseFolder
    )

    $templatesFolder = "$INSTANCE_ROOT\templates"
    if (-not (Test-Path $templatesFolder)) {
        return
    }

    Get-ChildItem -Path $templatesFolder -File -Recurse | ForEach-Object {
        $destination = $_.FullName.Replace($templatesFolder, $ReleaseFolder)

        $destinationBase = Split-Path $destination
        if (-not (Test-Path $destinationBase)) {
            New-Item -ItemType Directory -Path $destinationBase | Out-Null
        }

        Copy-Item -Path $_.FullName -Destination $destination -Recurse -Force
        Write-Host "Copied $_ to $destination" -ForegroundColor Cyan
    }

    Write-Host "Copied templates to $ReleaseFolder" -ForegroundColor Cyan
}

function Write-Content {
    param (
        [string]$ReleaseFolder
    )

    foreach ($content in Get-ContentPaths) {
        $destination = "$ReleaseFolder\$content"

        if (-not (Test-Path $content)) {
            continue
        }

        # Check if destination base directory exists
        $destinationBase = Split-Path $destination
        if (-not (Test-Path $destinationBase)) {
            New-Item -ItemType Directory -Path $destinationBase | Out-Null
        }

        Copy-Item -Path $content -Destination $destination -Force
        Write-Host "Copied $content to $destination" -ForegroundColor Cyan
    }
}

function Move-ContentToOverrides {
    param (
        [string]$ReleaseFolder
    )

    New-Item -ItemType Directory -Path "$ReleaseFolder\$OVERRIDES_FOLDER" | Out-Null

    foreach ($override in $CONTENT_FOLDERS) {
        $source = "$ReleaseFolder\$override"
        $destination = "$ReleaseFolder\$OVERRIDES_FOLDER\$override"

        if (-not (Test-Path $source)) {
            continue
        }

        Move-Item -Path $source -Destination $destination -Force
        Write-Host "Moved $override to $destination" -ForegroundColor Cyan
    }
}

function Write-ServerFiles {
    param (
        [string]$ReleaseFolder
    )

    # Copy contents of $SERVER_FILES_FOLDER to $ReleaseFolder
    $serverFilesSource = "$INSTANCE_ROOT\$SERVER_FILES_FOLDER"
    $serverFilesDestination = "$ReleaseFolder"
    foreach ($item in Get-ChildItem -Path $serverFilesSource -Recurse) {
        $destination = $item.FullName.Replace($serverFilesSource, $serverFilesDestination)
        Copy-Item -Path $item.FullName -Destination $destination -Recurse
        Write-Host "Copied $item to $destination" -ForegroundColor Cyan
    }
}

function Save-ModFile {
    param (
        [Parameter(Mandatory=$true)]
        [psobject]$Mod
    )
    
    $modFile = "$ReleaseFolder\mods\$($Mod.fileNameOnDisk)"
    if (-not (Test-Path $modFile)) {
        Write-Host "Downloading $($Mod.fileNameOnDisk)..." -ForegroundColor Cyan
        Write-Host $Mod.installedFile.downloadUrl

        curl.exe -sSL -o "$modFile" "$($Mod.installedFile.downloadUrl)"
    }
}

function Save-ModFiles {
    param (
        [string]$ReleaseFolder
    )

    # Ensure the minecraftinstance.json file exists
    if (-not (Test-Path $MINECRAFT_INSTANCE_FILE)) {
        throw "minecraftinstance.json file not found."
    }

    New-Item -ItemType Directory -Path "$ReleaseFolder\mods" | Out-Null

    $minecraftInstanceJson = Get-Content $MINECRAFT_INSTANCE_FILE | ConvertFrom-Json

    foreach ($addon in $minecraftInstanceJson.installedAddons) {
        if ($CLIENT_ONLY_MODS -contains $addon.addonID) {
            continue
        }

        Save-ModFile -Mod $addon
    }
}

function Save-ModList {
    param (
        [string]$ReleaseFolder
    )

    # Build paths with Join-Path to correctly handle spaces.
    $modListCreator = Join-Path $INSTANCE_ROOT "automation\ModListCreator-$MODLISTCREATOR_VERSION-fatjar.jar"
    $modListInput = Join-Path $ReleaseFolder $MANIFEST_FILE
    $modListOutput = Join-Path $ReleaseFolder "MODLIST.md"

    # If ModListCreator doesn't exist, download the latest release from GitHub
    if (-not (Test-Path "$INSTANCE_ROOT\automation\ModListCreator-$MODLISTCREATOR_VERSION-fatjar.jar")) {
        Write-Host "Downloading ModListCreator..." -ForegroundColor Cyan
        $modListCreatorUrl = "https://github.com/ModdingX/ModListCreator/releases/download/$MODLISTCREATOR_VERSION/ModListCreator-5.0.0-fatjar.jar"
        curl.exe -sSL -o "$INSTANCE_ROOT\automation\ModListCreator-$MODLISTCREATOR_VERSION-fatjar.jar" $modListCreatorUrl
    }
    
    # Create an array of arguments for java so each is treated separately
    $javaArgs = @(
        "-jar"
        $modListCreator
        "modlist"
        "--detailed"
        "--output"
        $modListOutput
        $modListInput
    )

    Write-Host "Creating mod list..." -ForegroundColor Cyan
    & java @javaArgs
}

function New-ReleaseZip {
    param (
        [string]$ReleaseFolder,
        [string]$ReleaseVersion,
        [string]$DestFolder,
        [string]$Suffix = ""
    )
    
    $releaseZip = Get-CleanFileName -FileName "$MODPACK_NAME-${ReleaseVersion}${Suffix}.zip"
    $releasePath = "$DestFolder\$releaseZip"
    Write-Host "Creating ZIP file '$releasePath'..." -ForegroundColor Cyan
    Compress-Archive -Path "$ReleaseFolder/*" -DestinationPath $releasePath -Force
}

# Main script

# If ran with no parameters, create both client and server releases
if (-not $Server -and -not $Client) {
    $Server = $true
    $Client = $true
}

if ($Client) {
    New-ClientRelease -ReleaseVersion $ReleaseVersion
}
if ($Server) {
    New-ServerRelease -ReleaseVersion $ReleaseVersion
}
