# ModpackKit

ModpackKit is a starter kit for managing and publishing CurseForge modpacks, designed to enable easy collaboration among team members.

### What can it do?

It has scripts, automations, and pipelines to help with:
- Exporting the modpack as a .zip to be easily shared
- GitHub Actions pipeline to automatically publish to CurseForge
- Generating server files (and excluding client-only mods)
- Generating changelogs between CurseForge releases
- Automatic syncing of modpack jar files when pulling git changes with [InstanceSync](https://github.com/Vazkii/InstanceSync/)
- Token replacement within config files
- Basic config template rendering

> [!NOTE]
> Currently only Forge modpacks are supported.
> If there is demand for NeoForge or others, support can be added.

### Recomended Mods

We've shipped this kit with support/compatibility for a few mods that make building/maintaining modpacks
a lot easier. Whilst these aren't required, we do recommend them:
- [Configured Defaults](https://www.curseforge.com/minecraft/mc-mods/configured-defaults)
\- Allows you to set defaults for files that won't overwrite user options
- [Better Compatibility Checker](https://www.curseforge.com/minecraft/mc-mods/better-compatibility-checker)
\- Better compatibility checking when joining or querying servers, can show when a modpack is outdated

## Getting Started

For ease of use, all of the automation is written in PowerShell. This means that you will need to either be on a Windows machine, or have `pwsh` installed on Linux.

### Creating a new modpack

This repository is designed to be copied into a CurseForge modpack folder. It is a royal pain in the ass to create a CurseForge modpack from an existing folder, so make a new modpack in CurseForge first, and then copy the contents of this repo into the modpack.

You'll probably also want to quickly create the new project on CurseForge's website, giving it a description, name, etc. as you'll need a CurseForge project ID in the next step, and CurseForge can take a while to approve things so it's better to get this out of the way early.

### Automation configuration

Our automation scripts have a single shared config file that requires some info about your project to run properly. You can find the config in `automation/config.ps1`. It has three main config options that need to be changed, although there are many more that you can read through and adjust as necessary.

```pwsh
# Friendly name of the modpack
$MODPACK_NAME = "My Cool Modpack"
# CurseForge project ID of the modpack
$MODPACK_MOD_ID = 1220805
# The pair of CurseForge game version IDs that the modpack supports
$MODPACK_GAME_VERSIONS = @(7498, 9990)
```

If you don't have the CurseForge project ID yet, that's fine. It can be skipped for now, but note that you can't publish a release or generate a changelog without it, and CurseForge can take a while to approve new projects.

The `$MODPACK_GAME_VERSIONS` can be hard to find, but are available in the [CurseForge Game Versions API](https://support.curseforge.com/en/support/solutions/articles/9000197321-curseforge-api#Game-Versions-API) response. The above values correspond to "Forge" and "1.20.1" respectively.

### Setting Up Automation Git Hooks

We include a pair of Git hooks to make collaboration easier, these do two things:
1. Parse, format, and sort the `minecraftinstance.json` file and write out a `manifest.json` before each commit. This allows each git diff to be easily readable and clearly show what mods were changed.
2. Automatically manages your modpack .jar files locally based on the `minecraftinstance.json` after each merge. This means if you pull down changes, the hook will automatically download/delete the local mod jars to keep everything in sync.

To set up automation git hooks, follow these steps:

1. Open a terminal in the modpack directory
2. Run either `.\automation\setup-hooks.bat` or `./automation/setup-hooks.sh` depending on your OS

This will configure the git hooks for you, and then run an initial sync of the modpack jars.

### Adding CurseForge Secret for GitHub Actions

To add a CurseForge API key for GitHub Actions:

1. Open up the [CurseForge API Tokens](https://legacy.curseforge.com/account/api-tokens) page
2. Create a new token with a useful name (e.g. `[Modpack] GitHub Actions`)
3. Copy the token to your clipboard
4. Go to your repository on GitHub.
5. Navigate to `Settings` > `Secrets and variables` > `Actions`.
6. Click on `New repository secret`.
7. Add a new secret with the name `CURSEFORGE_API_KEY` and paste your CurseForge API key as the value.
8. Save the secret.

## Content Folders

Modpacks, generally, can be a lot more than just config files. You might have KubeJS scripts, custom assets, and more that you want to make sure end up in the final exported modpack.

To support these cases, our automation scripts have a config option that lets to specify which folders to include. This can be found in `automation/config.ps1`:
```pwsh
# List of folders to include in the exported instance.
# These folders will be copied to the exported instance.
# By default, no folders are included unless specified here.
$CONTENT_FOLDERS = @(
    "config"
    "configureddefaults"
    "defaultconfigs"
    "kubejs"
)
```

Any folders added to this list will be included in the output as overrides when exporting/publishing the modpack.

> [!WARNING]
> Anything added to the `$CONTENT_FOLDERS` is subject to the `$CONTENT_STRATEGY` and `$CONTENT_PATTERNS` filter.
> Make sure you read the [Configuration Files](#configuration-files) section to understand how these options work.
> Otherwise, your content folders may not actually be included!

## Configuration Files

Config file management in modpacks is a complex problem. You want to make sure your changes are included in the final version, but players might not want you to override their minimap or JEI client configs each time they update.

You can use a mix of our [Content Filtering](#content-filtering) system and a mod like [Configured Defaults](https://www.curseforge.com/minecraft/mc-mods/configured-defaults) to help with this.

### Content Filtering

We have a fairly flexible "content strategy and filtering" system. This allows modpack devs to pick+choose exactly what files get delivered to the end-users.

There are two strategies for managing configuration files:
- [Add All by Default](#add-all-by-default)
- [Exclude All by Default](#exclude-all-by-default)

#### Add All by Default

In this strategy, all configuration files are included by default. You can then selectively exclude files as needed. This is good for modpacks with huge amounts of config changes (e.g. All The Mods, FTB, etc).

To enable this strategy, three things need to be changed. Firstly, you need to put the automation scripts into 'exclude' mode, so that by default all config files are exported. This can be set in `automation/config.ps1`:
```pwsh
# Set strategy:
# Use "include" to whitelist (only include files matching patterns)
# Use "exclude" to blacklist (include everything except files matching patterns)
$CONTENT_STRATEGY = "exclude"
```

Secondly, you need to remove all of the current content patterns, as the content patterns now act as a blacklist. This is just below the strategy in the automation config:
```pwsh
# A list of glob patterns to check when adding $CONTENT_FOLDERS to the exported instance.
# These patterns will either include or exclude files based on the $CONTENT_STRATEGY.
# This is useful for removing client-specific settings that should not be forced onto players, or
# for including only specific files.
# Use whatever separator is appropriate for your system. Wildcards are also supported with *.
$CONTENT_PATTERNS = @(
    # Anything in here will now be excluded
)
```

Finally, you will need to update the `.gitignore` to no longer ignore all config files. This can be done by removing (or commenting out) `/config/` from the "Configs" section of the `.gitignore` file:
```gitignore
# Configs
# /config/
```

All config files will now be tracked by git, and importantly, included as overrides when exporting the modpack.

You may still want to exclude some files from either git or the export (or both!). This can be done by adding things to the `.gitignore` and/or the content patterns:

```gitignore
# Configs
/config/jei/jei-client.ini
/config/xaerominimap.txt
... etc
```

```pwsh
$CONTENT_PATTERNS = @(
    "config\jei\jei-client.ini"
    "config\xaerominimap.txt"
)
```

#### Exclude All by Default

In this strategy, all configuration files are excluded by default. You can then selectively include files as needed. This is the default behaviour of this kit, and is good for modpacks that only have a few small config tweaks.

You can explicitly add some files to either git or the modpack export (or both!). This can be done by modifying the `.gitignore` and/or the content patterns:

```gitignore
# Configs
/config/
!/config/ae2/common.json
!/config/alexsmobs.toml
... etc
```
Adding a `!` prefix negates a pattern. So the above example ignores the whole `/config` folder by default,
but then explicitly un-ignores the `/config/ae2/common.json` and `/config/alexsmobs.toml` files.

```pwsh
$CONTENT_PATTERNS = @(
    "configureddefaults\*"
    "defaultconfigs\*"
    "kubejs\*"
)
```

### Configured Defaults

We recommend using a mod like [Configured Defaults](https://www.curseforge.com/minecraft/mc-mods/configured-defaults) in your modpacks, which allows you to specify default values for any file (config, options.txt, etc) that is only used if the file does not already exist!

This lets you add default configs for things like the JEI client options, minimaps, and even pre-configure key bindings in a way that won't reset after each update.

When using the [exclude all by default](#exclude-all-by-default) content strategy, we have pre-added the `configureddefaults\` folder to the content patterns.

### Token Replacements

Sometimes, you may want some parts of your config files to be dynamic or populated with your modpack name or other info. To solve this, our export scripts utilise a token replacements system.

This means that in any config file you can put a replacement token like `[[MODPACK_NAME]]`, and it will be automatically replaced with "My Cool Modpack" at the moment of export.

We use this system in a few places. For example, in `server/startserver.*`, to automatically set which Forge version to download, and to pre-set the MOTD etc.

#### Available Tokens
We have a few different tokens available. Each one must be enclosed in double square brackets.

| Token | Description | Example |
| ----- | ----------- | ------- |
| MINECRAFT_VERSION | Version of Minecraft this modpack is for, as set in CurseForge | 1.20.1 |
| FORGE_VERSION | Version of Minecraft Forge in this modpack, as set in CurseForge | 47.4.0 |
| MODPACK_NAME | Friendly name of your modpack | My Cool Modpack |
| MODPACK_PROJECT_ID | CurseForge project ID of your modpack | 1220805 |
| MODPACK_VERSION | Current modpack version specified at the time of export | 1.2.3 |

### Templates Folder

The `templates` folder can be used to populate files only at the point of exporting.
This can be handy if you have config files that need setting when exporting, but not while locally testing your pack.

Anything in `templates` is automatically mapped out into the root of your modpack when an export is created.
It will automatically override any files if they already exist.
Additionally, all templates are ran through the token replacements system once being copied over, which allows for
more complex configurations.

A good example of this is the `templates/config/bcc-common.toml` file. Token replacements allow us to specify the
modpack project ID and modpack version for
[Better Compatibility Checker](https://www.curseforge.com/minecraft/mc-mods/better-compatibility-checker).
This allows clients to easily see when their version of the modpack differs from the server.
Whilst it _does_ only work if you have the mod in your pack, we definitely recommend it!

## Exporting/Publishing

### Manual Export

A manual modpack export can be created with the `.\automation\modpack-export.ps1` script. It requires a single argument that specifies the version to export:
```bash
.\automation\modpack-export.ps1 -Version 1.0.0
```

This will export the modpack client and server files, which by default will end up in `.\builds\`.

If you just want a client or server build, you can run the script with `-Client` or `-Server` flags to specify which type of pack export you want. If you specify neither, it will create both.

### Automatic Publishing

This repo contains a GitHub Actions workflow to automatically export and publish the modpack for you,
as long as everything has been properly configured.

To trigger this, you just need to make a new release with the desired version number, for example:
1. Navigate to the "Releases" section of your GitHub repository.
2. Click on "Draft a new release".
3. Set the "Tag version" to the desired version number (e.g., `v1.0.0`).
4. Leave the "Release title" blank, and it will automatically be set to the version number.
5. Leave the release notes blank, as this will be automatically updated by the workflow with a changelog.
6. Click on "Publish release".

This will trigger the GitHub Actions workflow to automatically export and publish the modpack.
You can check this from the "Actions" tab in GitHub.

> [!NOTE]
> Generally, the workflow will fail on the first upload of a pack. This is because it takes a long while
> for the file to be approved, which causes the server file upload to fail.
> 
> This can be fixed by either re-running the action once the upload was approved and then deleting the first upload,
> or the server files can be manually exported as described above and uploaded to CurseForge by hand.

## Updates

Sometimes we may change things in these scripts or add new improvements. Generally I'll try and keep the GitHub Releases on this repo up to date.

Additionally, we store a `VERSION.md` in the `automations/` folder, so you can easily tell what release of the automation scripts your modpack repo is currently using.

## Contributions

I'm always open to contributions, suggestions, and more! Please file a GitHub issue if you have any problems.
