param (
    [Parameter(Mandatory=$true)]
    [string]$ReleaseVersion
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

. "$PSScriptRoot\shared.ps1"

function Assert-VersionExists {
    param (
        [string]$ReleaseVersion
    )

    $versionExists = Test-Path -Path "$INSTANCE_ROOT\$BUILDS_FOLDER\client\$ReleaseVersion"
    if (-not $versionExists) {
        Write-Error "Version $ReleaseVersion does not exist in $INSTANCE_ROOT\$BUILDS_FOLDER\client"
        exit 1
    }
}

function Assert-ModListCreatorExists {
    # If ModListCreator doesn't exist, download it from GitHub
    if (-not (Test-Path "$INSTANCE_ROOT\automation\ModListCreator-$MODLISTCREATOR_VERSION-fatjar.jar")) {
        Write-Host "Downloading ModListCreator..." -ForegroundColor Cyan
        $modListCreatorUrl = "https://github.com/ModdingX/ModListCreator/releases/download/$MODLISTCREATOR_VERSION/ModListCreator-5.0.0-fatjar.jar"
        curl.exe -sSL -o "$INSTANCE_ROOT\automation\ModListCreator-$MODLISTCREATOR_VERSION-fatjar.jar" $modListCreatorUrl
    }
}

function Get-ModpackLatestReleaseFile {
    param (
        [string]$ModpackId
    )

    # Call the CurseForge API and decode the JSON response.
    # Extract the data object, filter by release type, and sort by date.
    $response = curl.exe -sSL "https://www.curseforge.com/api/v1/mods/$ModpackId/files" | ConvertFrom-Json
    $latestVersion = $response.data | Where-Object { $_.releaseType -eq 1 } | Sort-Object -Property dateCreated -Descending | Select-Object -First 1
    if (-not $latestVersion) {
        Write-Warning "No release versions found for modpack $ModpackId"
        return $null
    }
    return $latestVersion
}

function Save-ModpackReleaseFile {
    param (
        [string]$ModpackId,
        [string]$FileId
    )

    # Ensure builds folder exists
    if (-not (Test-Path "$INSTANCE_ROOT\$BUILDS_FOLDER")) {
        New-Item -ItemType Directory -Path "$INSTANCE_ROOT\$BUILDS_FOLDER"
    }

    $url = "https://www.curseforge.com/api/v1/mods/$ModpackId/files/$FileId/download"
    curl.exe -sSL -o "$INSTANCE_ROOT\$BUILDS_FOLDER\previous.zip" $url
}

function Invoke-GenerateChangelog {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ReleaseVersion,
        [bool]$HasPreviousRelease
    )

    $modListCreator = Join-Path $INSTANCE_ROOT "automation\ModListCreator-$MODLISTCREATOR_VERSION-fatjar.jar"
    $modListOld = Join-Path $INSTANCE_ROOT "$BUILDS_FOLDER\previous.zip"
    $modListNew = Join-Path $INSTANCE_ROOT "manifest.json"
    $modListOutput = Join-Path $INSTANCE_ROOT "$BUILDS_FOLDER\changelog.md"

    $javaArgs = @(
        "-jar",
        $modListCreator
    )

    if ($HasPreviousRelease) {
        Write-Host "Generating changelog..." -ForegroundColor Cyan
        $javaArgs += @(
            "changelog",
            "--old",
            $modListOld,
            "--new",
            $modListNew,
            "--output",
            $modListOutput,
            "--no-header"
        )
    } else {
        Write-Host "Generating modlist..." -ForegroundColor Cyan
        $javaArgs += @(
            "modlist",
            "--output",
            $modListOutput,
            "--no-header",
            $modListNew
        )
    }

    & java @javaArgs
    Write-Host "Generated at $modListOutput" -ForegroundColor Green
}

#Assert-VersionExists -ReleaseVersion $ReleaseVersion
$latestRelease = Get-ModpackLatestReleaseFile -ModpackId $CURSEFORGE_PROJECT_ID
if ($latestRelease) {
    Write-Host "Current published release: $($latestRelease.fileName)"

    Save-ModpackReleaseFile -ModpackId $CURSEFORGE_PROJECT_ID -FileId $latestRelease.id
    Write-Host "Downloaded previous version to $INSTANCE_ROOT\$BUILDS_FOLDER\previous.zip"
}
$hasPreviousRelease = $null -ne $latestRelease

New-ManifestJson -ReleaseFolder "$INSTANCE_ROOT" -ReleaseVersion $ReleaseVersion

Assert-ModListCreatorExists
Invoke-GenerateChangelog  -ReleaseVersion $ReleaseVersion -HasPreviousRelease $hasPreviousRelease