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
    254284 # AmbientSounds 6
    257814 # CreativeCore
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

# CurseForge project ID of the modpack
$MODPACK_MOD_ID = 1220805
# The pair of CurseForge game version IDs that the modpack supports
$MODPACK_GAME_VERSIONS = @(7498, 9990)

# Version of the ModListCreator to use (internal)
$MODLISTCREATOR_VERSION = "5.0.0"
