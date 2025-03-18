param (
    [Parameter(Mandatory=$true)]
    [string]$ClientArchive,
    [string]$ServerArchive,
    [string]$ChangelogFile = "builds/changelog.md"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

. "$PSScriptRoot\shared.ps1"

function Assert-ArchiveExists {
    param (
        [string]$Archive
    )

    if (-not (Test-Path $Archive -PathType Leaf)) {
        Write-Error "Archive $Archive does not exist or is not a file"
        exit 1
    }
}

function Invoke-UploadArchive {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Archive,
        [Parameter(Mandatory=$true)]
        [string]$ModpackId,
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Changelog,
        [int]$ParentFileId
    )

    $uploadMetadata = @{
        "changelog" = $Changelog
        "changelogType" = "markdown"
        "releaseType" = "release"
    }

    if ($ParentFileId) {
        $uploadMetadata["parentFileID"] = $ParentFileId
    } else {
        $uploadMetadata["gameVersions"] = $MODPACK_GAME_VERSIONS
    }

    Write-Host "Uploading archive $Archive to CurseForge..."

    $url = "https://minecraft.curseforge.com/api/projects/$ModpackId/upload-file"
    Write-Host $Archive
    $responseRaw = curl.exe `
        -sSL `
        -X POST `
        -H "Accept: application/json" `
        -H "Content-Type: multipart/form-data" `
        -H "X-Api-Token: $($env:CURSEFORGE_API_KEY)" `
        -F "metadata=$(ConvertTo-Json -Compress $uploadMetadata)" `
        -F "file=@$Archive" `
        --progress-bar `
        "$url"
    
    try {
        $response = ConvertFrom-Json $responseRaw

        if (-not $response.id) {
            Write-Error "Failed to upload archive $Archive to CurseForge: $response"
            exit 1
        }
        Write-Host "Uploaded archive $Archive to CurseForge, with file ID $($response.id)"
        return $response.id
    } catch {
        Write-Error "Failed to parse response from CurseForge API"
        Write-Error $responseRaw
        exit 1
    }
}

function Invoke-RetryUploadArchive {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Archive,
        [Parameter(Mandatory=$true)]
        [string]$ModpackId,
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Changelog,
        [int]$ParentFileId
    )

    $attempts = 0
    $maxAttempts = 5
    $retryDelay = 30

    while ($true) {
        try {
            return Invoke-UploadArchive -Archive $Archive -ModpackId $ModpackId -Changelog $Changelog -ParentFileId $ParentFileId
        } catch {
            $attempts++
            if ($attempts -ge $maxAttempts) {
                throw "Failed to upload archive $Archive to CurseForge after $maxAttempts attempts"
            }

            Write-Error $_
            Write-Host "Failed to upload archive $Archive to CurseForge, retrying in $retryDelay seconds..."
            Start-Sleep -Seconds $retryDelay
        }
    }
}

Assert-ArchiveExists -Archive $ClientArchive
if ($ServerArchive) {
    Assert-ArchiveExists -Archive $ServerArchive
}

$changelog = ""
if (Test-Path $ChangelogFile) {
    $changelog = Get-Content $ChangelogFile -Raw
}

$fileId = Invoke-RetryUploadArchive -Archive $ClientArchive -ModpackId $MODPACK_MOD_ID -Changelog $changelog
Start-Sleep -Seconds 10

if ($ServerArchive) {
    Invoke-RetryUploadArchive -Archive $ServerArchive -ModpackId $MODPACK_MOD_ID -Changelog $changelog -ParentFileId $fileId
}
