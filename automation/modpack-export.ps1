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
    Save-ExternalModList -ReleaseFolder $releaseFolder
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
    Write-Content -ReleaseFolder $releaseFolder -Server $true

    # Write server-specific files
    Write-ServerFiles -ReleaseFolder $releaseFolder
    Save-ModFiles -ReleaseFolder $releaseFolder

    # Run post-processing tasks on the release folder
    Copy-Templates -ReleaseFolder $releaseFolder
    Write-FileReplacements -ReleaseFolder $releaseFolder

    Save-ModList -ReleaseFolder $releaseFolder
    Save-ExternalModList -ReleaseFolder $releaseFolder -Server $true
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
        [string]$ReleaseFolder,
        [boolean]$Server = $false
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

    # Write Modrinth external mods
    Write-ModrinthExternalMods -ReleaseFolder $ReleaseFolder -Server $Server
}

function Write-ModrinthExternalMods {
    param (
        [string]$ReleaseFolder,
        [boolean]$Server = $false
    )

    $mods = Get-ModrinthExternalMods -Server $true
    if ($mods.Count -eq 0) {
        return
    }
    Write-Host "Found $($mods.Count) external mods" -ForegroundColor Cyan

    $modsFolder = Join-Path -Path $ReleaseFolder -ChildPath "mods"
    if (-not (Test-Path $modsFolder)) {
        New-Item -ItemType Directory -Path $modsFolder | Out-Null
    }

    $mods | ForEach-Object {
        $modFileName = $_.FileName
        $modFilePath = Join-Path -Path $modsFolder -ChildPath $modFileName

        Write-Host "Downloading Modrinth mod: $modFileName" -ForegroundColor Cyan
        Invoke-WebRequest -Uri $_.DownloadUrl -OutFile $modFilePath
    }
}

function Get-ModrinthExternalMods {
    param (
        [boolean]$Server = $false
    )

    $externalMods = @()

    $MODRINTH_EXTERNAL_MODS | ForEach-Object {
        if ($Server -and $_.ClientOnly) {
            return
        }

        $projectId = $_.ProjectID
        $version = $_.Version

        $modrinthUrl = "https://api.modrinth.com/v2/project/$projectId/version/$version"
        $modrinthData = Invoke-RestMethod -Uri $modrinthUrl -Method Get

        if ($modrinthData) {
            $externalMod = @{
                ProjectId = $projectId
                Version   = $version
                ProjectUrl = "https://modrinth.com/mod/$projectId"
            }

            if ($modrinthData.files.Count -eq 0) {
                Write-Host "No files found for mod $projectId version $version" -ForegroundColor Red
                return
            }

            # Get file marked as primary, or first file if none is marked as primary
            $primaryFile = $modrinthData.files | Where-Object { $_.primary -eq $true }
            if ($primaryFile) {
                $externalMod["FileName"] = $primaryFile.filename
                $externalMod["DownloadUrl"] = $primaryFile.url
            } else {
                $externalMod["FileName"] = $modrinthData.files[0].filename
                $externalMod["DownloadUrl"] = $modrinthData.files[0].url
            }

            # Fetch project author
            $modrinthUrl = "https://api.modrinth.com/v2/project/$projectId"
            $modrinthData = Invoke-RestMethod -Uri $modrinthUrl -Method Get
            if ($modrinthData) {
                if ($modrinthData.team) {
                    $modrinthUrl = "https://api.modrinth.com/v2/team/$($modrinthData.team)/members"
                    $modrinthData = Invoke-RestMethod -Uri $modrinthUrl -Method Get
                    if ($modrinthData) {
                        $owner = $modrinthData | Where-Object { $_.role -eq "owner" }
                        $externalMod["Author"] = @{
                            Name = $owner.user.username
                            Url = "https://modrinth.com/user/$($owner.user.username)"
                        }
                    }
                }
            }

            $externalMods = @($externalMods + $externalMod)
        }
    }

    return ,$externalMods
}

function Move-ContentToOverrides {
    param (
        [string]$ReleaseFolder
    )

    New-Item -ItemType Directory -Path "$ReleaseFolder\$OVERRIDES_FOLDER" | Out-Null

    foreach ($content in $CONTENT_FOLDERS) {
        $source = "$ReleaseFolder\$content"
        $destination = "$ReleaseFolder\$OVERRIDES_FOLDER\$content"

        if (-not (Test-Path $source)) {
            continue
        }

        Move-Item -Path $source -Destination $destination -Force
        Write-Host "Moved $content to $destination" -ForegroundColor Cyan
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

    $modCache = "$CACHE_FOLDER\$($Mod.addonID)"
    $modCachedFile = "$modCache\$($Mod.installedFile.id)"
    $modFile = "$ReleaseFolder\mods\$($Mod.fileNameOnDisk)"

    if (-not (Test-Path $modFile)) {
        if (Test-Path $modCachedFile) {
            Write-Host "Found cached file for $($Mod.fileNameOnDisk)" -ForegroundColor Cyan
            Copy-Item -Path $modCachedFile -Destination $modFile -Force
            return
        }

        Write-Host "Downloading $($Mod.fileNameOnDisk)..." -ForegroundColor Cyan
        Write-Host $Mod.installedFile.downloadUrl

        if (-not (Test-Path $modCache)) {
            New-Item -ItemType Directory -Path $modCache | Out-Null
        }
        curl.exe -sSL -o "$modCachedFile" "$($Mod.installedFile.downloadUrl)"
        Copy-Item -Path $modCachedFile -Destination $modFile -Force

        # Cleanup old cached files
        Get-ChildItem -Path $modCache | Where-Object { $_.Name -ne $Mod.installedFile.id } | Remove-Item -Force
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

    $modsFolder = "$ReleaseFolder\mods"
    if (-not (Test-Path $modsFolder)) {
        New-Item -ItemType Directory -Path $modsFolder | Out-Null
    }

    # Track a list of mod IDs to clean up the cache later
    $modIds = @()

    $minecraftInstanceJson = Get-Content $MINECRAFT_INSTANCE_FILE | ConvertFrom-Json
    foreach ($addon in $minecraftInstanceJson.installedAddons) {
        $modIds += $addon.addonID

        if ($CLIENT_ONLY_MODS -contains $addon.addonID) {
            continue
        }

        Save-ModFile -Mod $addon
    }

    # Cleanup old cached files
    Get-ChildItem -Path $CACHE_FOLDER | Where-Object { $_.Name -notin $modIds } | Remove-Item -Recurse -Force
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

function Save-ExternalModList {
    param (
        [string]$ReleaseFolder,
        [boolean]$Server = $false
    )

    $modListOutput = Join-Path $ReleaseFolder "MODLIST.md"

    $externalMods = Get-ModrinthExternalMods -Server $Server
    if ($externalMods.Count -eq 0) {
        return
    }

    # Append mod list and header to modlist file
    $externalModList = "### External Mods"
    $externalModList += "`r`n"

    $externalMods | ForEach-Object {
        $externalModList += "  * [$($_.FileName)]($($_.ProjectUrl)) (by [$($_.Author.Name)]($($_.Author.Url)))"
        $externalModList += "`r`n"
    }

    # Write the external mod list to the bottom of the mod list
    Add-Content -Path $modListOutput -Value $externalModList
    Write-Host "Appended external mod list to $modListOutput" -ForegroundColor Cyan
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
