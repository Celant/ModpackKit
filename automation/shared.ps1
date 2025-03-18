# Disable "Declared but never used" warning, as this is a shared library file and the variables are used in other scripts
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "", Justification = "Shared file")]
param()

$MANIFEST_FILE = "manifest.json"
$MINECRAFT_INSTANCE_FILE = "minecraftinstance.json"
$OVERRIDES_FOLDER = "overrides"
$BUILDS_FOLDER = "builds"
$SERVER_FILES_FOLDER = "server"
$CACHE_FOLDER = Join-Path $BUILDS_FOLDER ".cache"
$INSTANCE_ROOT = ("$PSScriptRoot\.." | Resolve-Path)

. "$PSScriptRoot\config.ps1"

function Get-MinecraftVersion {
    $minecraftInstanceJson = Get-Content $MINECRAFT_INSTANCE_FILE | ConvertFrom-Json
    return $minecraftInstanceJson.baseModLoader.minecraftVersion
}

function Get-ForgeVersion {
    $minecraftInstanceJson = Get-Content $MINECRAFT_INSTANCE_FILE | ConvertFrom-Json
    return $minecraftInstanceJson.baseModLoader.forgeVersion
}

function Get-CleanFileName {
    param (
        [string]$FileName
    )

    $FileName = $FileName -replace ('[^a-zA-Z0-9\.\-\s]', '')
    return $FileName -replace ('[\s]+', '.')
}

# Returns a list of all files and folders to include in the exported instance
function Get-ContentPaths {
    $content = @()

    foreach ($folder in $CONTENT_FOLDERS) {
        $folderPath = "$INSTANCE_ROOT\$folder"
        if (-not (Test-Path $folderPath)) {
            continue
        }

        $items = Get-ChildItem -Path $folderPath -Recurse
        foreach ($item in $items) {
            $relativePath = $item.FullName.Replace("$INSTANCE_ROOT\", "")
            $allowed = Test-ContentPath $relativePath
            if ($allowed) {
                $content += $relativePath
            }
        }
    }

    return $content
}

# Check if a path should be included in the exported instance
# This is based on the $CONTENT_STRATEGY and $CONTENT_PATTERNS array
function Test-ContentPath {
    param (
        [string]$Path
    )

    if ($CONTENT_STRATEGY -eq "include") {
        foreach ($pattern in $CONTENT_PATTERNS) {
            if ($Path -like "$pattern") {
                return $true
            }
        }
        return $false
    } elseif ($CONTENT_STRATEGY -eq "exclude") {
        foreach ($pattern in $CONTENT_PATTERNS) {
            if ($Path -like "$pattern") {
                return $false
            }
        }
        return $true
    }

    throw "Invalid content strategy: $CONTENT_STRATEGY"
}

function New-ManifestJson {
    param (
        [string]$ReleaseFolder,
        [string]$ReleaseVersion,
        [switch]$Server = $false
    )

    # Ensure the minecraftinstance.json file exists
    if (-not (Test-Path $MINECRAFT_INSTANCE_FILE)) {
        throw "minecraftinstance.json file not found."
    }

    $minecraftInstanceJson = Get-Content $MINECRAFT_INSTANCE_FILE | ConvertFrom-Json

    $mods = [System.Collections.ArrayList]@()
    foreach ($addon in $minecraftInstanceJson.installedAddons) {
        if ($Server -and ($CLIENT_ONLY_MODS -contains $addon.addonID)) {
            continue
        }

        if ($addon.isEnabled -eq $false) {
            continue
        }

        $mod = @{
            "projectID" = $addon.addonID
            "fileID" = $addon.installedFile.id
            "downloadUrl" = $addon.installedFile.downloadUrl
            "required" = $true
        }

        $mods.Add($mod) | Out-Null
    }
    $mods = $mods | Sort-Object {[int]($_.projectID)}

    $manifestJson = @{
        "minecraft" = @{
            "version" = $minecraftInstanceJson.baseModLoader.minecraftVersion
            "modLoaders" = @(
                @{
                    "id" = $minecraftInstanceJson.baseModLoader.name
                    "primary" = $true
                }
            )
        }
        "manifestType" = "minecraftModpack"
        "manifestVersion" = 1
        "name" = $MODPACK_NAME
        "version" = $ReleaseVersion
        "author" = ""
        "files" = $mods
        "overrides" = $OVERRIDES_FOLDER
    }

    $manifestOutFile = "$ReleaseFolder\$MANIFEST_FILE"
    $manifestJson | ConvertTo-Json -Depth 10 | Format-Json | Set-Content $manifestOutFile
    Write-Host "Created $MANIFEST_FILE file" manifest -ForegroundColor Cyan
}

# Return a mapping of tokens and their replacements for config files
function Get-FileReplacements {
    $minecraftVersion = Get-MinecraftVersion
    $forgeVersion = Get-ForgeVersion

    $replacements = @{
        "\[\[MINECRAFT_VERSION\]\]" = $minecraftVersion
        "\[\[FORGE_VERSION\]\]" = $forgeVersion
        "\[\[MODPACK_NAME\]\]" = $MODPACK_NAME
        "\[\[MODPACK_PROJECT_ID\]\]" = $MODPACK_MOD_ID
        "\[\[MODPACK_VERSION\]\]" = $ReleaseVersion
    }

    return $replacements
}

# Replace tokens in files with their corresponding values
function Write-FileReplacements {
    param (
        [string]$ReleaseFolder
    )

    $replacements = Get-FileReplacements

    foreach ($file in Get-ChildItem -Path $ReleaseFolder -Recurse -File) {
        if ($REPLACEMENTS_IGNORE -match $file.Extension) {
            continue
        }

        $content = Get-Content -LiteralPath $file.FullName
        $replacements.GetEnumerator() | ForEach-Object {
            if (Select-String -InputObject $content -Pattern $_.Key) {
                $content = $content -replace $_.Key, $_.Value
                Set-Content -Path $file.FullName -Value $content
                Write-Host "Replaced $($_.Key) with $($_.Value) in $file" -ForegroundColor Cyan
            }
        }
    }
}

# Formats JSON in a nicer format than the built-in ConvertTo-Json does.
function Format-Json([Parameter(Mandatory, ValueFromPipeline)][String] $json) {
    $indent = 0;
    ($json -Split "`n" | ForEach-Object {
        if ($_ -match '[\}\]]\s*,?\s*$') {
            # This line ends with ] or }, decrement the indentation level
            $indent--
        }
        $line = ('  ' * $indent) + $($_.TrimStart() -replace '":  (["{[])', '": $1' -replace ':  ', ': ')
        if ($_ -match '[\{\[]\s*$') {
            # This line ends with [ or {, increment the indentation level
            $indent++
        }
        $line
    }) -Join "`n"
}