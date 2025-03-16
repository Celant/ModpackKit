[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$MINECRAFT_INSTANCE_FILE = "minecraftinstance.json"
$INSTANCE_ROOT = ("$PSScriptRoot\.." | Resolve-Path)

. "$PSScriptRoot\config.ps1"
. "$PSScriptRoot\shared.ps1"

# Returns md5sum of the instance file
function Get-InstanceHash {
    $instanceJson = Get-Content "$INSTANCE_ROOT\$MINECRAFT_INSTANCE_FILE"
    $instanceJson = $instanceJson -join "`n"
    $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $utf8 = New-Object -TypeName System.Text.UTF8Encoding
    $hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($instanceJson))) -replace '-', ''
    return $hash
}

function Get-Instance {
    # Ensure the minecraftinstance.json file exists
    if (-not (Test-Path $MINECRAFT_INSTANCE_FILE)) {
        throw "minecraftinstance.json file not found."
    }

    return Get-Content "$INSTANCE_ROOT\$MINECRAFT_INSTANCE_FILE" | ConvertFrom-Json
}

function Get-ModpackSafeName {
    # Replace all non-alphanumeric characters with hyphens
    $name = $MODPACK_NAME -replace "[^a-zA-Z0-9]", "-"

    # Remove any leading or trailing hyphens
    $name = $name -replace "^-|-$", ""

    # Replace multiple hyphens with a single hyphen
    $name = $name -replace "-+", "-"

    return $name
}

function Remove-LocalData {
    param (
        [Parameter(Mandatory = $true)]
        [object]$instance
    )

    # Remove lastPlayed and playedCount
    $instance.lastPlayed = "0001-01-01T00:00:00"
    $instance.playedCount = 0

    # Fix names
    if ($instance.manifest) {
        $instance.manifest.name = Get-ModpackSafeName
    }
    $instance.name = Get-ModpackSafeName

    # Remove install path
    $instance.installPath = "Test-Pack\"

    # # Remove modFolderPath from each mod
    # $instance.installedAddons | ForEach-Object {
    #     $_.modFolderPath = ""
    # }

    return $instance
}

function Get-FormattedInstance {
    param (
        [Parameter(Mandatory = $true)]
        [object]$instance
    )

    $instance.installedAddons = $instance.installedAddons | Sort-Object -Property name

    $instance | ConvertTo-Json -Depth 100 | Format-Json
}

function Write-Instance {
    param (
        [Parameter(Mandatory = $true)]
        [string]$instanceJson
    )
    $manifestFilePath = "$INSTANCE_ROOT\$MINECRAFT_INSTANCE_FILE"

    (($instanceJson) -join "`n") + "`n" | Set-Content -NoNewline -Encoding UTF8 -Path $manifestFilePath
}

function Get-InstanceHasChanges {
    param (
        [Parameter(Mandatory = $true)]
        [string]$originalHash,
        [Parameter(Mandatory = $true)]
        [string]$instanceHash
    )

    return $originalHash -ne $instanceHash
}

$originalHash = Get-InstanceHash
$instance = Get-Instance
$instance = Remove-LocalData -instance $instance
$instanceJson = Get-FormattedInstance -instance $instance
Write-Instance -instance $instanceJson
New-ManifestJson -ReleaseFolder $INSTANCE_ROOT -ReleaseVersion 0
$instanceHash = Get-InstanceHash

$hasChanges = Get-InstanceHasChanges -originalHash $originalHash -instanceHash $instanceHash
if ($hasChanges) {
    Write-Host "Reformatted minecraftinstance.json" -ForegroundColor Yellow
    Write-Host " "
    Write-Host "Commit again with the changes to the instance file." -ForegroundColor Yellow
    exit 1
} else {
    exit 0
}
