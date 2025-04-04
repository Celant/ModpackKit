# Disable "Declared but never used" warning, as this is a config file and the variables are used in other scripts
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "", Justification = "Config file")]
param()

# Friendly name of the modpack
$MODPACK_NAME = "Create Continents"

# List of folders to include in the exported instance.
# These folders will be copied to the exported instance.
# By default, no folders are included unless specified here.
$CONTENT_FOLDERS = @(
    "config"
    "configureddefaults"
    "defaultconfigs"
    "kubejs"
)

# CurseForge project IDs to exclude from server exports.
# This prevents them being downloaded and included in the server pack.
$CLIENT_ONLY_MODS = @(
    254284  # AmbientSounds 6
    250398  # Controlling
    257814  # CreativeCore
    908741  # Embeddium
    448233  # Entity Culling
    363363  # Extreme Sound Muffler
    463155  # Falling Leaves
    367706  # FancyMenu
    882495  # Fix GPU memory leak
    854949  # Fusion
    686911  # ImmediatelyFast
    976858  # Inventory Tweaks
    561885  # Just Zoom
    561885  # Light Overlay
    60089   # Mouse Tweaks
    1140741 # NeoAuth
    581495  # Oculus
    521480  # Skin Layers 3D
    551736  # Sodium/Embeddium Dynamic Lights
    558905  # Sodium/Embeddium Extras
    1103431 # Sodium/Embeddium Options API
    1146393 # Sodium/Embeddium Options Mod Compat
    535489  # Sound Physics Remastered

    422288 # Misa's Realistic (resource pack)
)

# Set strategy:
# Use "include" to whitelist (only include files matching patterns)
# Use "exclude" to blacklist (include everything except files matching patterns)
$CONTENT_STRATEGY = "include"

# A list of glob patterns to check when adding $CONTENT_FOLDERS to the exported instance.
# These patterns will either include or exclude files based on the $CONTENT_STRATEGY.
# This is useful for removing client-specific settings that should not be forced onto players, or
# for including only specific files.
# Use whatever separator is appropriate for your system. Wildcards are also supported with *.
$CONTENT_PATTERNS = @(
    "configureddefaults\*"
    "defaultconfigs\*"
    "kubejs\*"
)

# A list of patterns to ignore when replacing text in files.
# This is useful for ignoring binary files that should not be modified.
$REPLACEMENTS_IGNORE = @(
    "\.jar(\.disabled|\.meta)?$"
    "\.zip$"
)

# An array of modrinth mods to include in the modpack.
# This is used to download the mods from modrinth and include them in the modpack.
# Will only work for mods that are on CurseForge's "Approved Non-CurseForge" list.
# https://docs.google.com/spreadsheets/d/176Wv-PZUo9hFxy6oC6N8tWdquBLPRtSuLbNK-r0_byM/edit
$MODRINTH_EXTERNAL_MODS = @(
    @{
        ProjectID  = "cc-tweaked"
        Version    = "1.115.1"
    }
)

# CurseForge project ID of the modpack
$CURSEFORGE_PROJECT_ID = 1220805
# The pair of CurseForge game version IDs that the modpack supports
$CURSEFORGE_GAME_VERSIONS = @(7498, 9990)

# Version of the ModListCreator to use (internal)
$MODLISTCREATOR_VERSION = "5.0.0"
